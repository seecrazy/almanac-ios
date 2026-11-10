import SwiftUI
import HolidayData
import UIKit
import UniformTypeIdentifiers

/// 权限被拒时的「打开系统设置」统一入口。
struct OpenSettingsLink: View {
    @Environment(\.palette) private var palette

    let title: String = "打开系统设置"

    var body: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            Label(title, systemImage: "gear.badge.questionmark")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(palette.accent)
        }
    }
}

struct SettingsView: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService
    @EnvironmentObject private var briefingService: DailyBriefingService
    @EnvironmentObject private var milestoneStore: MilestoneStore
    @EnvironmentObject private var alarmStore: WorkdayAlarmStore

    @AppStorage("showLunar") private var showLunar = true
    @AppStorage("showSolarTerms") private var showSolarTerms = true
    @AppStorage("showLunarFestivals") private var showLunarFestivals = true
    @AppStorage("showHuangLi") private var showHuangLi = false
    @AppStorage("month.week.start.day") private var weekStartDayRaw = WeekStartDay.monday.rawValue

    @State private var reportIsPresented = false
    @State private var backupShareURL: URL?
    @State private var importIsPresented = false
    @State private var importPreview: BackupService.ImportPreview?
    @State private var importErrorMessage: String?

    @EnvironmentObject private var holidayData: HolidayDataCoordinator
    private var holidayStore: HolidayStore { holidayData.store }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("设置")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundColor(palette.ink)

                VStack(spacing: 0) {
                    toggleRow("农历日期", binding: $showLunar)
                    Divider().background(palette.separator)
                    toggleRow("二十四节气", binding: $showSolarTerms)
                    Divider().background(palette.separator)
                    toggleRow("农历节日", binding: $showLunarFestivals)
                    Divider().background(palette.separator)
                    toggleRow("黄历（宜忌/冲煞）", binding: $showHuangLi)
                    Divider().background(palette.separator)
                    briefingRow
                }
                .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))

                VStack(alignment: .leading, spacing: 12) {
                    Text("节假日数据")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(palette.ink)

                    if holidayStore.statuses.isEmpty {
                        Text("节假日数据未加载")
                            .font(.system(size: 13))
                            .foregroundColor(palette.secondary)
                    } else {
                        ForEach(holidayStore.statuses, id: \.year) { status in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(status.year) · \(status.source.title)")
                                    .font(.system(size: 13))
                                    .foregroundColor(palette.ink)
                                if let sourceName = status.sourceName {
                                    Text(sourceName)
                                        .font(.system(size: 12))
                                        .foregroundColor(palette.secondary)
                                }
                                if let issuedAt = status.issuedAt {
                                    Text("更新时间：\(issuedAt)")
                                        .font(.system(size: 12))
                                        .foregroundColor(palette.secondary)
                                }
                            }
                        }
                    }

                    if !holidayStore.loadErrors.isEmpty {
                        Text("部分年度数据加载失败，已按未覆盖处理。")
                            .font(.system(size: 12))
                            .foregroundColor(palette.holidayRed)
                    }

                    HStack(spacing: 8) {
                        Button {
                            Task { await holidayData.checkForUpdates(force: true) }
                        } label: {
                            Label("检查更新", systemImage: "arrow.triangle.2.circlepath")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(palette.accent)
                        }
                        .disabled(holidayData.updateState == .checking)
                        if holidayData.updateState == .checking {
                            ProgressView()
                        }
                    }

                    Text(remoteUpdateFooter)
                        .font(.system(size: 12))
                        .foregroundColor(updateStateColor)

                    Text("数据来源：内置官方数据 + 联网更新（holiday-cn 数据集，转录国务院办公厅通知）；离线始终可用内置数据。")
                        .font(.system(size: 12))
                        .foregroundColor(palette.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))

                VStack(alignment: .leading, spacing: 12) {
                    Text("月视图")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(palette.ink)
                    Text("周起始日")
                        .font(.system(size: 13))
                        .foregroundColor(palette.secondary)
                    Picker("周起始日", selection: $weekStartDayRaw) {
                        ForEach(WeekStartDay.allCases) { day in
                            Text(day.title).tag(day.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("周起始日")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))


                VStack(alignment: .leading, spacing: 12) {
                    Text("系统日历")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(palette.ink)
                    Text(accessText)
                        .font(.system(size: 13))
                        .foregroundColor(palette.secondary)
                    if eventService.accessState == .notDetermined {
                        Button {
                            Task { await eventService.requestAccessIfNeeded() }
                        } label: {
                            Text("允许访问")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(palette.accent))
                        }
                    } else if eventService.accessState == .denied {
                        Text("请到系统设置 > 隐私与安全性 > 日历中开启权限。")
                            .font(.system(size: 12))
                            .foregroundColor(palette.secondary)
                        OpenSettingsLink()
                    }
                    if let error = eventService.lastErrorMessage {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(palette.holidayRed)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))

                VStack(spacing: 0) {
                    actionRow("年度回顾", icon: "chart.bar.doc.horizontal") {
                        reportIsPresented = true
                    }
                    Divider().background(palette.separator)
                    actionRow("导出备份", icon: "square.and.arrow.up") {
                        exportBackup()
                    }
                    Divider().background(palette.separator)
                    actionRow("导入备份", icon: "square.and.arrow.down") {
                        importIsPresented = true
                    }
                }
                .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))

                if let importErrorMessage {
                    Text(importErrorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(palette.holidayRed)
                }

                Text("备份含里程碑 / 纪念日 / 闹钟（JSON）；日记为加密数据，暂不包含。")
                    .font(.system(size: 12))
                    .foregroundColor(palette.secondary)

                Text("黄历默认关闭；开关控制日详情中的黄历面板。当前版本设置不参与同步。")
                    .font(.system(size: 13))
                    .foregroundColor(palette.secondary)
            }
            .padding(20)
        }
        .background(palette.background.ignoresSafeArea())
        .sheet(isPresented: $reportIsPresented) {
            YearReportView()
        }
        .sheet(item: $backupShareURL) { url in
            ActivityShareSheet(items: [url])
                .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $importIsPresented,
            allowedContentTypes: [.json]
        ) { result in
            handleImportFile(result)
        }
        .confirmationDialog(
            "导入备份？",
            isPresented: Binding(
                get: { importPreview != nil },
                set: { if !$0 { importPreview = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("导入") { applyImport() }
            Button("取消", role: .cancel) { importPreview = nil }
        } message: {
            if let preview = importPreview {
                Text(importSummary(preview))
            }
        }
    }

    private func actionRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.appText(15))
                    .foregroundColor(palette.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(palette.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: 备份

    private func exportBackup() {
        do {
            let data = try BackupService.export(
                milestones: milestoneStore.milestones,
                anniversaries: milestoneStore.anniversaries,
                alarmTemplate: alarmStore.template,
                alarms: alarmStore.alarms
            )
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(BackupService.fileName())
            try data.write(to: url, options: .atomic)
            backupShareURL = url
        } catch {
            importErrorMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func handleImportFile(_ result: Result<URL, Error>) {
        importErrorMessage = nil
        guard case .success(let url) = result else { return }

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let document = try BackupService.decode(data)
            let preview = BackupService.preview(
                document,
                existingMilestones: milestoneStore.milestones,
                existingAnniversaries: milestoneStore.anniversaries,
                existingAlarms: alarmStore.alarms
            )
            let totalCount = preview.newMilestones.count + preview.newAnniversaries.count + preview.newAlarms.count
            guard totalCount > 0 || preview.template != nil else {
                importErrorMessage = "备份中没有新内容（可能此前已导入过）。"
                return
            }
            importPreview = BackupService.ImportPreview(
                newMilestones: preview.newMilestones,
                newAnniversaries: preview.newAnniversaries,
                newAlarms: preview.newAlarms,
                template: preview.template
            )
            pendingApply = preview
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    @State private var pendingApply: BackupService.ImportPreview?

    private func importSummary(_ preview: BackupService.ImportPreview) -> String {
        var parts: [String] = []
        if !preview.newMilestones.isEmpty { parts.append("里程碑 \(preview.newMilestones.count) 条") }
        if !preview.newAnniversaries.isEmpty { parts.append("生日/纪念日 \(preview.newAnniversaries.count) 条") }
        if !preview.newAlarms.isEmpty { parts.append("闹钟 \(preview.newAlarms.count) 个") }
        if preview.template != nil { parts.append("工作日规则") }
        return "将新增：" + parts.joined(separator: "、") + "（已存在的跳过，不覆盖）"
    }

    private func applyImport() {
        guard let preview = pendingApply else { return }
        pendingApply = nil
        importPreview = nil

        Task {
            for milestone in preview.newMilestones {
                await milestoneStore.save(milestone)
            }
            for anniversary in preview.newAnniversaries {
                await milestoneStore.save(anniversary)
            }
            if !preview.newAlarms.isEmpty || preview.template != nil {
                for alarm in preview.newAlarms {
                    alarmStore.alarms.append(alarm)
                }
                if let template = preview.template {
                    alarmStore.template = template
                }
                await alarmStore.sync()
            }
        }
    }

    private func toggleRow(_ title: String, binding: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.appText(15))
                .foregroundColor(palette.ink)
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var briefingRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("每日简报")
                    .font(.system(size: 15))
                    .foregroundColor(palette.ink)
                Text("每天一条：农历 · 节气节日 · 宜忌（提前 14 天预排）")
                    .font(.system(size: 11))
                    .foregroundColor(palette.secondary)
            }
            Spacer()
            if briefingService.isEnabled {
                DatePicker(
                    "简报时间",
                    selection: $briefingService.time,
                    displayedComponents: [.hourAndMinute]
                )
                .labelsHidden()
                .frame(width: 74)
            }
            Toggle("", isOn: $briefingService.isEnabled)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var remoteUpdateFooter: String {
        switch holidayData.updateState {
        case .idle:
            return "启动时自动检查更新（24 小时一次）"
        case .checking:
            return "正在检查节假日数据更新…"
        case .updated(let years):
            return "已更新 \(years.map(String.init).joined(separator: "、")) 年的数据"
        case .upToDate:
            return "节假日数据已是最新"
        case .failed(let message):
            return message
        }
    }

    private var updateStateColor: Color {
        if case .failed = holidayData.updateState { return palette.holidayRed }
        if case .updated = holidayData.updateState { return palette.solarGreen }
        return palette.secondary
    }

    private var accessText: String {
        switch eventService.accessState {
        case .granted: return "已接入 EventKit，日程来自系统日历。"
        case .denied: return "未授权读取系统日历。"
        case .notDetermined: return "尚未请求日历权限。"
        }
    }

}
