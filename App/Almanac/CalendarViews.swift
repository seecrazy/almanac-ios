import SwiftUI
import CalendarAnalysis
import LunarKit
import HolidayData

enum CalendarViewMode: String, CaseIterable, Identifiable {
    case month
    case year
    case agenda

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: return "月"
        case .year: return "年"
        case .agenda: return "议程"
        }
    }
}

enum AgendaRange: Int, CaseIterable, Identifiable {
    case thirty = 30
    case sixty = 60
    case ninety = 90

    var id: Int { rawValue }

    var title: String {
        "\(rawValue) 天"
    }
}

struct CalendarScreen: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService

    @AppStorage("calendar.view.mode") private var modeRaw = CalendarViewMode.month.rawValue
    @AppStorage("month.week.start.day") private var weekStartDayRaw = WeekStartDay.monday.rawValue

    @State private var selectedDate = Date()
    @State private var visibleMonth = MonthView.firstOfMonth(Date())
    @State private var agendaRange: AgendaRange = .thirty
    @State private var isDateJumpPresented = false
    @State private var dateJumpDraft = Date()

    @EnvironmentObject private var holidayData: HolidayDataCoordinator

    private var holidayStore: HolidayStore { holidayData.store }

    private var mode: CalendarViewMode {
        CalendarViewMode(rawValue: modeRaw) ?? .month
    }

    private var weekStartDay: WeekStartDay {
        WeekStartDay(rawValue: weekStartDayRaw) ?? .monday
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = weekStartDay.firstWeekday
        return calendar
    }

    private var visibleYear: Date {
        let components = calendar.dateComponents([.year], from: visibleMonth)
        return calendar.date(from: components) ?? visibleMonth
    }

    private var loadKey: String {
        switch mode {
        case .month:
            return "month-\(visibleMonth.timeIntervalSince1970)"
        case .agenda:
            return "agenda-\(selectedDate.timeIntervalSince1970)-\(agendaRange.rawValue)"
        case .year:
            return "year-\(visibleYear.timeIntervalSince1970)"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            modePicker
            navigationBar
            accessBanner
            content
        }
        .background(palette.background.ignoresSafeArea())
        .task(id: loadKey) {
            await loadVisibleEvents()
        }
        .onChange(of: selectedDate) { newValue in
            let newMonth = MonthView.firstOfMonth(newValue)
            if !calendar.isDate(newMonth, inSameDayAs: MonthView.firstOfMonth(visibleMonth)) {
                visibleMonth = newMonth
            }
        }
        .sheet(isPresented: $isDateJumpPresented) {
            dateJumpSheet
        }
    }

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(CalendarViewMode.allCases) { item in
                let isSelected = mode == item
                Button {
                    modeRaw = item.rawValue
                } label: {
                    Text(item.title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .white : palette.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(isSelected ? palette.accent : Color.clear))
                }
            }
        }
        .padding(4)
        .background(Capsule().fill(palette.card))
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("日历视图")
    }

    private var navigationBar: some View {
        HStack(spacing: 8) {
            Button {
                isDateJumpPresented = true
                dateJumpDraft = anchorDate
            } label: {
                Text(anchorTitle)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 14).fill(palette.card))
            }
            .accessibilityLabel("打开日期跳转，当前\(anchorTitle)")

            Button {
                let now = Date()
                selectedDate = now
                visibleMonth = MonthView.firstOfMonth(now)
            } label: {
                Text("今天")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(palette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(palette.card))
            }
            .accessibilityLabel("回到今天")
            .frame(maxWidth: 86)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var anchorTitle: String {
        (mode == .year ? AppFormatters.yearTitle : AppFormatters.anchorTitle)
            .string(from: anchorDate)
    }

    private var anchorDate: Date {
        mode == .month || mode == .year ? visibleMonth : selectedDate
    }

    private var dateJumpSheet: some View {
        DateJumpSheet(
            initialDate: anchorDate,
            onCancel: { isDateJumpPresented = false },
            onConfirm: { date in
                selectedDate = date
                visibleMonth = MonthView.firstOfMonth(date)
                isDateJumpPresented = false
            }
        )
        .background(palette.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var accessBanner: some View {
        if eventService.accessState == .denied {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("无法读取系统日历；农历与节假日仍可查看。")
                    .font(.system(size: 12))
                Spacer()
                Button("重试") {
                    Task { await eventService.requestAccessIfNeeded() }
                }
                .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(palette.holidayRed)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(palette.card.opacity(0.9))
            HStack {
                OpenSettingsLink()
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .month:
            MonthView(visibleMonth: $visibleMonth, selectedDate: $selectedDate)
        case .agenda:
            CalendarAgendaView(
                startDate: $selectedDate,
                range: $agendaRange
            )
        case .year:
            CalendarYearView(
                visibleMonth: $visibleMonth,
                holidayStore: holidayStore,
                onSelectMonth: { month in
                    visibleMonth = month
                    selectedDate = month
                    modeRaw = CalendarViewMode.month.rawValue
                }
            )
        }
    }

    private func loadVisibleEvents() async {
        await eventService.requestAccessIfNeeded()

        switch mode {
        case .month:
            if let interval = calendar.dateInterval(of: .month, for: visibleMonth) {
                await eventService.loadEvents(from: interval.start, to: interval.end)
            }
        case .agenda:
            let start = calendar.startOfDay(for: selectedDate)
            let end = calendar.date(byAdding: .day, value: agendaRange.rawValue, to: start) ?? start
            await eventService.loadEvents(from: start, to: end)
        case .year:
            // 整年一次区间拉取，避免逐月串行请求与逐次全量重排。
            if let interval = calendar.dateInterval(of: .year, for: visibleYear) {
                await eventService.loadEvents(from: interval.start, to: interval.end)
            }
        }
    }
}

struct DateJumpSheet: View {
    @Environment(\.palette) private var palette

    let initialDate: Date
    let onCancel: () -> Void
    let onConfirm: (Date) -> Void

    @State private var year: Int
    @State private var month: Int
    @State private var day: Int

    private let years = Array(1900...2100)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    private var monthDate: Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }

    private var dayCount: Int {
        guard let date = monthDate else { return 30 }
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    private var days: [Int] {
        Array(1...dayCount)
    }

    init(
        initialDate: Date,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (Date) -> Void
    ) {
        self.initialDate = initialDate
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        let calendar = Calendar(identifier: .gregorian)
        _year = State(initialValue: calendar.component(.year, from: initialDate))
        _month = State(initialValue: calendar.component(.month, from: initialDate))
        _day = State(initialValue: calendar.component(.day, from: initialDate))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Button("取消", action: onCancel)
                    .foregroundColor(palette.secondary)

                Spacer()

                Text("跳转日期")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(palette.ink)

                Spacer()

                Button("确定") { confirm() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(palette.accent)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("目标日期")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(palette.secondary)

                Text("\(year)年\(month)月\(min(day, dayCount))日")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundColor(palette.ink)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22).fill(palette.card))

            HStack(spacing: 8) {
                jumpWheel(title: "年", selection: $year, items: years) { "\($0)" }
                jumpWheel(title: "月", selection: $month, items: Array(1...12)) { "\($0)月" }
                jumpWheel(title: "日", selection: $day, items: days) { "\($0)日" }
            }
            .onChange(of: month) { _ in clampDay() }
            .onChange(of: year) { _ in clampDay() }

            HStack(spacing: 10) {
                quickButton("昨天") { setDate(Date().addingTimeInterval(-86_400)) }
                quickButton("今天", isAccent: true) { setDate(Date()) }
                quickButton("明天") { setDate(Date().addingTimeInterval(86_400)) }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private func jumpWheel(
        title: String,
        selection: Binding<Int>,
        items: [Int],
        text: @escaping (Int) -> String
    ) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(palette.secondary)

            Picker(title, selection: selection) {
                ForEach(items, id: \.self) { item in
                    Text(text(item)).tag(item)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 18).fill(palette.card))
    }

    private func quickButton(
        _ title: String,
        isAccent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isAccent ? .white : palette.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Capsule().fill(isAccent ? palette.accent : palette.card))
        }
    }

    private func clampDay() {
        if day > dayCount { day = dayCount }
    }

    private func setDate(_ date: Date) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        year = components.year ?? year
        month = components.month ?? month
        day = components.day ?? day
    }

    private func confirm() {
        guard let date = calendar.date(
            from: DateComponents(year: year, month: month, day: min(day, dayCount))
        ) else { return }
        onConfirm(date)
    }
}

struct AlmanacPanel: View {
    @Environment(\.palette) private var palette

    let date: Date
    @State private var isExpanded = false

    var body: some View {
        let rules = AlmanacRuleSet.bundledShared
        let day = AlmanacCalendar.day(for: date, rules: rules)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("黄历", systemImage: "book.closed")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(palette.ink)
                Spacer()
                Text(rules == nil ? "规则不可用" : "本地规则")
                    .font(.system(size: 10))
                    .foregroundColor(palette.secondary)
            }

            if day.lunar == nil {
                Text("超出农历支持范围")
                    .font(.system(size: 13))
                    .foregroundColor(palette.secondary)
            } else {
                Text("\(day.yearGanZhi)年 · \(day.monthGanZhi)月 · \(day.dayGanZhi)日")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(palette.ink)
                Text(panelMetaText(day))
                    .font(.system(size: 13))
                    .foregroundColor(palette.secondary)

                activityRows(day, rules: rules, isExpanded: isExpanded)

                if hasMoreActivities(day) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Text(isExpanded ? "收起完整宜忌" : "展开完整宜忌")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(palette.accent)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))
    }

    private func panelMetaText(_ day: AlmanacDay) -> String {
        var parts = [day.zodiac, day.duty]
        if let clash = day.clash {
            var clashText = "冲\(clash.conflictBranch)"
            if let direction = clash.direction {
                clashText += " 煞\(direction)"
            }
            parts.append(clashText)
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func activityRows(_ day: AlmanacDay, rules: AlmanacRuleSet?, isExpanded: Bool) -> some View {
        if rules == nil {
            Text("黄历规则不可用，已隐藏宜忌")
                .font(.system(size: 13))
                .foregroundColor(palette.secondary)
        } else if day.suitable.isEmpty && day.avoid.isEmpty {
            Text("今日无常见宜忌")
                .font(.system(size: 13))
                .foregroundColor(palette.secondary)
        } else {
            let suitableActivities = isExpanded ? day.suitable : Array(day.suitable.prefix(3))
            let avoidActivities = isExpanded ? day.avoid : Array(day.avoid.prefix(3))

            if !suitableActivities.isEmpty {
                Text("宜：\(suitableActivities.map(\.title).joined(separator: "、"))")
                    .font(.system(size: 13))
                    .foregroundColor(palette.ink)
            }
            if !avoidActivities.isEmpty {
                Text("忌：\(avoidActivities.map(\.title).joined(separator: "、"))")
                    .font(.system(size: 13))
                    .foregroundColor(palette.secondary)
            }
        }
    }

    private func hasMoreActivities(_ day: AlmanacDay) -> Bool {
        day.suitable.count > 3 || day.avoid.count > 3
    }
}

private struct CalendarAgendaView: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService

    @Binding var startDate: Date
    @Binding var range: AgendaRange

    @State private var visibleLimit = 200
    // 分组结果缓存：渲染期零过滤，仅在数据 / 范围 / 上限变化时重算。
    @State private var sections: [(day: Date, events: [CalendarEvent])] = []
    @State private var totalEventCount = 0

    private let calendar = Calendar.current

    private var days: [Date] {
        let start = calendar.startOfDay(for: startDate)
        return (0..<range.rawValue).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if eventService.accessState == .denied {
                    Text("无法读取系统日历。")
                        .font(.system(size: 13))
                        .foregroundColor(palette.holidayRed)
                }
                agendaList
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onChange(of: range) { _ in
            visibleLimit = 200
        }
        .onAppear(perform: rebuildSections)
        .onChange(of: eventService.events) { _ in rebuildSections() }
        .onChange(of: startDate) { _ in rebuildSections() }
        .onChange(of: range) { _ in rebuildSections() }
        .onChange(of: visibleLimit) { _ in rebuildSections() }
        .simultaneousGesture(
            DragGesture(minimumDistance: 56).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                let direction = value.translation.width < 0 ? 1 : -1
                startDate = calendar.date(
                    byAdding: .day,
                    value: direction * range.rawValue,
                    to: startDate
                ) ?? startDate
            }
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("未来 \(range.rawValue) 天")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundColor(palette.ink)
                Spacer()
                Text("\(totalEventCount) 个日程")
                    .font(.system(size: 13))
                    .foregroundColor(palette.secondary)
            }
            Picker("范围", selection: $range) {
                ForEach(AgendaRange.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var agendaList: some View {
        if sections.isEmpty && totalEventCount == 0 && eventService.events.isEmpty {
            Text("暂无日程")
                .font(.system(size: 13))
                .foregroundColor(palette.secondary)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))
        } else {
            VStack(spacing: 14) {
                ForEach(sections, id: \.day.timeIntervalSince1970) { section in
                    agendaSection(for: section.day, events: section.events)
                }
            }

            if visibleLimit < min(500, totalEventCount) {
                Button {
                    visibleLimit = min(500, visibleLimit + 200)
                } label: {
                    Text("加载更多")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(palette.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(palette.card))
                }
            } else if totalEventCount > 500 {
                Text("最多显示前 500 条日程")
                    .font(.system(size: 12))
                    .foregroundColor(palette.secondary)
            }
        }
    }

    @ViewBuilder
    private func agendaSection(for day: Date, events: [CalendarEvent]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayTitle(day))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(calendar.isDateInToday(day) ? palette.accent : palette.ink)
                Spacer()
                Text(LunarCalendar.displayText(for: LunarCalendar.lunar(from: day)))
                    .font(.system(size: 12))
                    .foregroundColor(palette.secondary)
            }

            if events.isEmpty {
                Text("无日程")
                    .font(.system(size: 12))
                    .foregroundColor(palette.secondary)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(palette.card.opacity(0.7)))
            } else {
                VStack(spacing: 7) {
                    ForEach(events) { event in
                        EventRow(event: event)
                    }
                }
            }
        }
    }

    private func rebuildSections() {
        var remaining = visibleLimit
        var rebuilt: [(day: Date, events: [CalendarEvent])] = []
        rebuilt.reserveCapacity(days.count)
        var total = 0

        for day in days {
            let allEvents = eventService.events(on: day)
            total += allEvents.count
            let events = Array(allEvents.prefix(remaining))
            remaining -= events.count
            rebuilt.append((day, events))
        }

        sections = rebuilt
        totalEventCount = total
    }

    private func dayTitle(_ day: Date) -> String {
        AppFormatters.monthDayWeekday.string(from: day)
    }
}

private struct CalendarYearView: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService
    @AppStorage("month.week.start.day") private var weekStartDayRaw = WeekStartDay.monday.rawValue

    @Binding var visibleMonth: Date
    let holidayStore: HolidayStore
    let onSelectMonth: (Date) -> Void

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = WeekStartDay(rawValue: weekStartDayRaw)?.firstWeekday ?? 2
        return calendar
    }

    private var year: Int {
        calendar.component(.year, from: visibleMonth)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(year)年")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundColor(palette.ink)
                .padding(.top, 8)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(1...12, id: \.self) { month in
                        if let firstOfMonth = calendar.date(
                            from: DateComponents(year: year, month: month, day: 1)
                        ) {
                            MiniMonthView(
                                month: firstOfMonth,
                                calendar: calendar,
                                holidayStore: holidayStore,
                                eventColors: eventService.eventCalendarColors(for: firstOfMonth),
                                onTap: { onSelectMonth(firstOfMonth) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 56).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                visibleMonth = calendar.date(
                    byAdding: .year,
                    value: value.translation.width < 0 ? 1 : -1,
                    to: visibleMonth
                ) ?? visibleMonth
            }
        )
    }

}

private struct MiniMonthView: View {
    @Environment(\.palette) private var palette

    let month: Date
    let calendar: Calendar
    let holidayStore: HolidayStore
    let eventColors: [Date: [CalendarColorComponents]]
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(monthTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(palette.ink)

            let names = calendar.firstWeekday == 1
                ? ["日", "一", "二", "三", "四", "五", "六"]
                : ["一", "二", "三", "四", "五", "六", "日"]
            HStack(spacing: 0) {
                ForEach(names, id: \.self) { name in
                    Text(name)
                        .font(.system(size: 8))
                        .foregroundColor(palette.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            let cells = monthCells
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 3) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    if let day = cell {
                        miniDay(day)
                    } else {
                        Color.clear.frame(height: 18)
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(palette.card))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var monthTitle: String {
        AppFormatters.monthOnly.string(from: month)
    }

    private var monthCells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let first = interval.start
        let dayCount = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: first)
        let leading = (firstWeekday + 7 - calendar.firstWeekday) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: first))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    @ViewBuilder
    private func miniDay(_ day: Date) -> some View {
        let isToday = calendar.isDateInToday(day)
        let effect = holidayStore.effect(for: day)
        VStack(spacing: 1) {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 9, weight: isToday ? .semibold : .regular))
                .foregroundColor(dayColor(day, isToday: isToday, effect: effect))
            Circle()
                .fill(dotColor(day))
                .frame(width: 3, height: 3)
        }
        .frame(height: 18)
    }

    private func dayColor(_ day: Date, isToday: Bool, effect: DayEffect?) -> Color {
        if isToday { return palette.accent }
        if case .workday = effect { return palette.makeupGray }
        if case .restDay = effect { return palette.holidayRed }
        return palette.ink
    }

    private func dotColor(_ day: Date) -> Color {
        let startOfDay = calendar.startOfDay(for: day)
        if let color = eventColors[startOfDay]?.first {
            return color.swiftUIColor
        }
        return .clear
    }
}

struct EventConflictSection: View {
    @Environment(\.palette) private var palette

    let groups: [AnalysisConflictGroup]
    let draftEventID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(groups) { group in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(palette.holidayRed)
                    Text(conflictText(for: group))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(palette.holidayRed)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func conflictText(for group: AnalysisConflictGroup) -> String {
        let titles = group.events
            .filter { $0.id != draftEventID }
            .map { "「\($0.title)」" }
        return "与\(titles.joined())冲突 \(intervalText(group.interval))"
    }
}

struct FreeSlotSection: View {
    @Environment(\.palette) private var palette

    let date: Date
    let events: [AnalysisEvent]

    var body: some View {
        let slots = CalendarConflictAnalyzer.freeSlots(on: date, events: events)
        if !slots.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("空闲时段")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(palette.secondary)
                ForEach(slots) { slot in
                    Text("\(slotText(slot)) · \(durationText(slot.duration))")
                        .font(.system(size: 13))
                        .foregroundColor(palette.ink)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(palette.card))
        }
    }

    private func slotText(_ slot: AnalysisFreeSlot) -> String {
        "\(AppFormatters.hhmm.string(from: slot.startDate)) – \(AppFormatters.hhmm.string(from: slot.endDate))"
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes < 60 { return "\(minutes) 分钟" }

        let hours = Double(minutes) / 60
        let text = hours == hours.rounded()
            ? String(Int(hours))
            : String(format: "%.1f", hours)
        return "\(text) 小时"
    }
}

private func intervalText(_ interval: DateInterval) -> String {
    if Calendar.current.isDate(interval.start, inSameDayAs: interval.end) {
        return "\(AppFormatters.hhmm.string(from: interval.start))–\(AppFormatters.hhmm.string(from: interval.end))"
    }

    return "\(AppFormatters.hhmm.string(from: interval.start))–\(AppFormatters.monthDayTime.string(from: interval.end))"
}
