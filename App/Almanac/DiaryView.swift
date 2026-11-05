import SwiftUI
import DiaryKit
import CryptoKit
import Security

@MainActor
final class DiaryViewModel: ObservableObject {
    @Published var selectedDate = Date()
    @Published var mood: DiaryMood?
    @Published var bodyText = ""
    @Published var skeleton: [DiarySkeletonItem] = []
    @Published var recentEntries: [DiaryEntry] = []
    @Published var isEditing = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchKeyword = ""
    @Published var searchResults: [DiaryEntry] = []
    @Published private(set) var currentEntry: DiaryEntry?
    @Published private(set) var hasCalendarAccess = false

    private var eventService: EventStoreService?
    private let store: DiaryStore?

    init(store: DiaryStore? = nil) {
        if let store {
            self.store = store
            return
        }

        do {
            self.store = try DiaryStore(
                databaseURL: Self.databaseURL(),
                key: try Self.loadOrCreateKey()
            )
        } catch {
            self.store = nil
            errorMessage = "无法解锁日记：\(error.localizedDescription)"
        }
    }

    var canEdit: Bool { store != nil }

    func attach(eventService: EventStoreService) {
        self.eventService = eventService
        hasCalendarAccess = eventService.accessState == .granted
    }

    func prepare(date: Date, eventService: EventStoreService) {
        attach(eventService: eventService)
        select(date)
    }

    func select(_ date: Date) {
        selectedDate = date
        load()
    }

    func load() {
        guard let store else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            recentEntries = try store.allEntries(calendar: .current).prefix(DiaryLimit.recentDays).map { $0 }
            let normalizedDate = Calendar.current.startOfDay(for: selectedDate)
            currentEntry = recentEntries.first { Calendar.current.isDate($0.date, inSameDayAs: normalizedDate) }
                ?? (try? store.entry(on: normalizedDate, calendar: .current)) ?? nil
            mood = currentEntry?.mood
            bodyText = currentEntry?.body ?? ""
            skeleton = currentEntry?.skeleton ?? []
            isEditing = currentEntry == nil
        } catch {
            errorMessage = "读取日记失败：\(error.localizedDescription)"
        }
    }

    func generateSkeleton() {
        guard let eventService else { return }
        let events = eventService.events(on: selectedDate)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")

        skeleton = events.map { event in
            let timeText: String
            if event.isAllDay {
                timeText = "全天"
            } else {
                formatter.dateFormat = "HH:mm"
                timeText = "\(formatter.string(from: event.startDate))–\(formatter.string(from: event.endDate))"
            }
            return DiarySkeletonItem(
                title: event.title,
                timeText: timeText,
                calendarTitle: event.calendarTitle,
                isAllDay: event.isAllDay
            )
        }

        if bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if skeleton.isEmpty {
                bodyText = "今天没有安排日程。"
            } else {
                bodyText = "今日日程：\n" + skeleton.map { "· \($0.timeText) \($0.title)" }.joined(separator: "\n") + "\n"
            }
        }
    }

    func save() {
        guard let store else { return }
        errorMessage = nil
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > DiaryEntry.maximumBodyLength {
            errorMessage = "正文最多 \(DiaryEntry.maximumBodyLength) 字。"
            return
        }
        if trimmed.isEmpty && mood == nil {
            errorMessage = "请选择心情或填写正文。"
            return
        }

        var entry = currentEntry ?? DiaryEntry(date: selectedDate)
        entry.mood = mood
        entry.body = bodyText
        entry.skeleton = skeleton
        entry.updatedAt = Date()

        do {
            try store.save(entry, calendar: .current)
            isEditing = false
            load()
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    func delete() {
        guard let store else { return }
        errorMessage = nil
        do {
            try store.delete(on: selectedDate, calendar: .current)
            currentEntry = nil
            mood = nil
            bodyText = ""
            skeleton = []
            isEditing = true
            load()
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
    }

    func search() {
        guard let store else { return }
        let keyword = searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            searchResults = []
            return
        }

        do {
            let cutoff = Calendar.current.date(byAdding: .day, value: -DiaryLimit.searchDays, to: Date()) ?? Date()
            searchResults = Array(
                try store.allEntries(calendar: .current)
                    .filter { $0.date >= cutoff }
                    .filter { entry in
                        entry.body.localizedStandardContains(keyword)
                            || entry.skeleton.contains { $0.title.localizedStandardContains(keyword) }
                    }
                    .prefix(DiaryLimit.searchResults)
            )
        } catch {
            errorMessage = "搜索失败：\(error.localizedDescription)"
        }
    }

    private static func databaseURL() -> URL {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return directory.appendingPathComponent("DiaryStore.sqlite")
    }

    private static func loadOrCreateKey() throws -> SymmetricKey {
        let service = "com.yili.almanac.diary"
        let account = "diary.v1"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return SymmetricKey(data: data)
        }
        guard status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }

        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
        }
        return key
    }
}

struct DiarySheetView: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService
    @StateObject private var model = DiaryViewModel()

    @State private var deleteConfirmation = false
    @State private var hasPrepared = false

    let initialDate: Date

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                dateCard
                entryCard
                recentSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 28)
        }
        .background(palette.background.ignoresSafeArea())
        .onAppear {
            guard !hasPrepared else { return }
            hasPrepared = true
            model.prepare(date: initialDate, eventService: eventService)
            Task { await loadSelectedDayEvents() }
        }
        .onChange(of: model.selectedDate) { _ in
            Task { await loadSelectedDayEvents() }
        }
        .alert("删除这篇日记？", isPresented: $deleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { model.delete() }
        } message: {
            Text("删除后无法恢复。")
        }
    }

    private func loadSelectedDayEvents() async {
        let start = Calendar.current.startOfDay(for: model.selectedDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        await eventService.loadEvents(from: start, to: end)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("日记")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(palette.ink)
                Text("AES-256-GCM 加密，保存在本机")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(palette.secondary)
            }
            Spacer()
        }
    }

    private var dateCard: some View {
        HStack(spacing: 12) {
            Text(model.selectedDate, format: .dateTime.year().month().day().weekday())
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundColor(palette.ink)
            Spacer()
            if Calendar.current.isDateInToday(model.selectedDate) {
                Text("今天")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(palette.accent))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(palette.card))
    }

    @ViewBuilder
    private var entryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text(model.currentEntry == nil ? "新日记" : "已保存日记")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(palette.ink)
                if let updated = model.currentEntry?.updatedAt {
                    Text("更新于 \(updated.formatted(.dateTime.month().day().hour().minute()))")
                        .font(.system(size: 11))
                        .foregroundColor(palette.secondary)
                }
                Spacer()
                if model.currentEntry != nil {
                    Button(model.isEditing ? "完成" : "编辑") {
                        model.isEditing.toggle()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(palette.accent)
                }
            }

            if model.isEditing {
                moodPicker
                editorBody
                skeletonEditor
                saveActions
            } else {
                readonlyEntry
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(palette.holidayRed)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(palette.card)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(palette.separator, lineWidth: 1))
        )
    }

    private var moodPicker: some View {
        HStack(spacing: 8) {
            ForEach(DiaryMood.allCases) { item in
                let selected = model.mood == item
                Button {
                    model.mood = selected ? nil : item
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbolName)
                            .font(.system(size: 15))
                        Text(item.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(selected ? .white : palette.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 14).fill(selected ? palette.accent : palette.background))
                }
            }
        }
    }

    private var editorBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("感受")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(palette.secondary)
                Spacer()
                Text("\(model.bodyText.count) / \(DiaryEntry.maximumBodyLength)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(palette.secondary)
            }
            TextEditor(text: $model.bodyText)
                .font(.system(size: 15))
                .frame(minHeight: 170)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16).fill(palette.background))
        }
    }

    private var skeletonEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("日程骨架")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(palette.secondary)
                Spacer()
                Button("从日程生成") {
                    model.generateSkeleton()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(palette.accent)
            }

            if model.skeleton.isEmpty {
                Text(model.hasCalendarAccess ? "当天没有日程；保存前可手动补充感受。" : "未授权读取系统日历，仍可写纯文字日记。")
                    .font(.system(size: 12))
                    .foregroundColor(palette.secondary)
            } else {
                VStack(spacing: 7) {
                    ForEach(model.skeleton) { item in
                        HStack(spacing: 8) {
                            Text(item.timeText)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(palette.accent)
                                .frame(width: 92, alignment: .leading)
                            Text(item.title)
                                .font(.system(size: 13))
                                .foregroundColor(palette.ink)
                                .lineLimit(1)
                            Spacer()
                            Text(item.calendarTitle)
                                .font(.system(size: 10))
                                .foregroundColor(palette.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(palette.background))
                    }
                }
            }
        }
    }

    private var saveActions: some View {
        HStack(spacing: 10) {
            Button {
                model.save()
            } label: {
                Text(model.currentEntry == nil ? "保存日记" : "保存修改")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 16).fill(palette.accent))
            }
            .disabled(!model.canEdit)

            if model.currentEntry != nil {
                Button(role: .destructive) {
                    deleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(palette.holidayRed)
                        .frame(width: 48, height: 47)
                        .background(RoundedRectangle(cornerRadius: 16).fill(palette.background))
                }
            }
        }
    }

    @ViewBuilder
    private var readonlyEntry: some View {
        HStack(spacing: 10) {
            if let mood = model.mood {
                Label(mood.title, systemImage: mood.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(palette.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(palette.accent.opacity(0.12)))
            }
            Spacer()
        }

        if model.bodyText.isEmpty {
            Text("这一天只保存了日程骨架，还没有写感受。")
                .font(.system(size: 14))
                .foregroundColor(palette.secondary)
        } else {
            Text(model.bodyText)
                .font(.system(size: 15))
                .foregroundColor(palette.ink)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        if !model.skeleton.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("日程骨架")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(palette.secondary)
                ForEach(model.skeleton.prefix(5)) { item in
                    Text("\(item.timeText) · \(item.title)")
                        .font(.system(size: 12))
                        .foregroundColor(palette.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(palette.background))
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近 30 天")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(palette.ink)

            if model.recentEntries.isEmpty {
                Text("还没有日记。选择心情、写下几句话，或先生成日程骨架。")
                    .font(.system(size: 12))
                    .foregroundColor(palette.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 18).fill(palette.card))
            } else {
                VStack(spacing: 9) {
                    ForEach(model.recentEntries) { entry in
                        Button {
                            model.select(entry.date)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.date, format: .dateTime.month().day().weekday())
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(palette.ink)
                                    Text(entry.body.isEmpty ? "只有日程骨架" : entry.body)
                                        .font(.system(size: 11))
                                        .foregroundColor(palette.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if let mood = entry.mood {
                                    Image(systemName: mood.symbolName)
                                        .foregroundColor(palette.accent)
                                }
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))
                        }
                    }
                }
            }
        }
    }

}
