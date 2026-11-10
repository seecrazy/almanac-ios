import SwiftUI
import LunarKit
import HolidayData
import NaturalInput

enum WeekStartDay: String, CaseIterable, Identifiable {
    case monday
    case sunday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monday: return "周一"
        case .sunday: return "周日"
        }
    }

    var firstWeekday: Int {
        switch self {
        case .monday: return 2
        case .sunday: return 1
        }
    }
}

struct MonthView: View {
    @Environment(\.palette) private var palette
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var eventService: EventStoreService
    @EnvironmentObject private var router: AppRouter

    @Binding var visibleMonth: Date
    @Binding var selectedDate: Date
    @State private var selectedDay: Date?
    @State private var quickComposerContext: QuickComposerContext?
    @State private var quickInput = ""
    @State private var calendarFilterIsPresented = false
    @State private var searchIsPresented = false
    @State private var selectedEvent: CalendarEvent?
    @AppStorage("month.week.start.day") private var weekStartDayRaw = WeekStartDay.monday.rawValue
    @AppStorage("month.view.weekMode") private var isWeekMode = false
    @AppStorage("showSolarTerms") private var showSolarTerms = true
    @AppStorage("showLunarFestivals") private var showLunarFestivals = true

    /// 月格装饰缓存：事件色点 + 节气 + 节日。节气含天文计算，禁止在渲染期重算。
    @State private var decorations = MonthDecorations()

    private var holidayStore: HolidayStore { .bundledShared }
    private let inputParser = NaturalInputParser()

    init(visibleMonth: Binding<Date>, selectedDate: Binding<Date>) {
        _visibleMonth = visibleMonth
        _selectedDate = selectedDate
    }

    private var weekStartDay: WeekStartDay {
        WeekStartDay(rawValue: weekStartDayRaw) ?? .monday
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = weekStartDay.firstWeekday
        return calendar
    }

    static func firstOfMonth(_ date: Date) -> Date {
        let c = Calendar(identifier: .gregorian)
        let comps = c.dateComponents([.year, .month], from: date)
        return c.date(from: comps) ?? date
    }

    var body: some View {
        Group {
            if sizeClass == .regular {
                // iPad：左栏月格 + 右栏常驻日详情。
                HStack(spacing: 0) {
                    monthColumn
                    Divider().background(palette.separator)
                    DayDetail(date: selectedDate, holidayStore: holidayStore)
                }
            } else {
                monthColumn
            }
        }
        .background(palette.background.ignoresSafeArea())
        .sheet(item: $selectedDay) { day in
            DayDetail(date: day, holidayStore: holidayStore)
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event) {}
        }
        .sheet(item: $quickComposerContext) { context in
            AddEventView(
                initialDate: context.date,
                draft: context.draft,
                warnings: context.warnings
            )
        }
        .sheet(isPresented: $calendarFilterIsPresented) {
            CalendarFilterSheet()
        }
        .sheet(isPresented: $searchIsPresented) {
            EventSearchSheet()
        }
        .gesture(
            DragGesture(minimumDistance: 56)
                .onEnded { value in
                    let horizontal = abs(value.translation.width)
                    let vertical = abs(value.translation.height)
                    if horizontal >= 56, horizontal >= vertical * 1.5 {
                        if isWeekMode {
                            shiftWeek(value.translation.width < 0 ? 1 : -1)
                        } else {
                            shiftMonth(value.translation.width < 0 ? 1 : -1)
                        }
                    } else if vertical >= 56, vertical > horizontal * 1.5 {
                        // 上滑收起为周视图，下拉展开为月视图。
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isWeekMode = value.translation.height < 0
                        }
                    }
                }
        )
        .onChange(of: selectedDate) { newValue in
            let newMonth = Self.firstOfMonth(newValue)
            let currentMonth = Self.firstOfMonth(visibleMonth)
            if !calendar.isDate(newMonth, inSameDayAs: currentMonth) {
                visibleMonth = newMonth
            }
        }
        .onReceive(router.$pendingDiaryDate) { date in
            guard let date else { return }
            selectedDate = date
            if sizeClass != .regular {
                selectedDay = date
            }
            router.pendingDiaryDate = nil
        }
        .onReceive(router.$pendingQuickPhrase) { phrase in
            guard let phrase, !phrase.isEmpty else { return }
            quickInput = phrase
            router.pendingQuickPhrase = nil
            parseQuickInput()
        }
        .onAppear(perform: rebuildDecorations)
        .onChange(of: visibleMonth) { _ in rebuildDecorations() }
        .onChange(of: eventService.events) { _ in rebuildDecorations() }
        .onChange(of: showSolarTerms) { _ in rebuildDecorations() }
        .onChange(of: showLunarFestivals) { _ in rebuildDecorations() }
    }

    private func rebuildDecorations() {
        decorations = MonthDecorations(
            eventColors: eventService.eventCalendarColors(for: visibleMonth),
            solarTerms: solarTermNames(for: visibleMonth),
            festivals: festivalNames(for: visibleMonth)
        )
    }

    private var monthColumn: some View {
        VStack(spacing: 0) {
            header
            quickInputBar
            weekdayHeader
            grid
            if isWeekMode {
                weekDayList
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: 头部

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundColor(palette.ink)
                Text(subtitleText)
                    .font(.system(size: 13))
                    .foregroundColor(palette.secondary)
            }
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isWeekMode.toggle()
                }
            } label: {
                Image(systemName: isWeekMode ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(palette.accent)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(isWeekMode ? "切换到月视图" : "切换到周视图")
            Button {
                searchIsPresented = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(palette.accent)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("搜索日程")
            Button {
                calendarFilterIsPresented = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(palette.accent)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("日历筛选")
            Button {
                quickComposerContext = QuickComposerContext(
                    date: Date(),
                    draft: nil,
                    warnings: []
                )
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(palette.accent)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("新建今日日程")
        }
        .onAppear {
            Task { await eventService.requestAccessIfNeeded() }
            eventService.loadCalendars()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: 快速输入

    private var quickInputBar: some View {
        HStack(spacing: 10) {
            TextField(
                "明天下午3点到5点 开会 @会议室 #重要",
                text: $quickInput
            )
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .submitLabel(.go)
            .onSubmit { parseQuickInput() }
            .accessibilityLabel("自然语言创建日程")

            Button {
                parseQuickInput()
            } label: {
                Text("解析")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(canParseQuickInput ? palette.accent : palette.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(palette.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(palette.separator)
                            )
                    )
            }
            .disabled(!canParseQuickInput)
            .accessibilityLabel("解析自然语言日程")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(palette.separator)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    private var canParseQuickInput: Bool {
        !quickInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func parseQuickInput() {
        guard canParseQuickInput else { return }
        let result = inputParser.parse(quickInput, reference: Date())
        quickComposerContext = QuickComposerContext(
            date: Date(),
            draft: result.draft,
            warnings: result.warnings
        )
        quickInput = ""
    }

    private var titleText: String {
        let y = calendar.component(.year, from: visibleMonth)
        let m = calendar.component(.month, from: visibleMonth)
        return "\(y)年\(m)月"
    }

    private var subtitleText: String {
        let year = calendar.component(.year, from: visibleMonth)
        let gz = GanZhi.yearGanZhi(forGregorianYear: year)
        return "\(year) · \(gz.ganZhi)年 · \(gz.zodiac)年"
    }

    private func shiftMonth(_ delta: Int) {
        visibleMonth = calendar.date(byAdding: .month, value: delta, to: visibleMonth) ?? visibleMonth
    }

    private func loadMonthEvents() async {
        guard let interval = calendar.dateInterval(of: .month, for: visibleMonth) else { return }
        await eventService.loadEvents(from: interval.start, to: interval.end)
    }

    // MARK: 星期表头（周一起始）

    private var weekdayHeader: some View {
        let names = weekStartDay == .sunday
            ? ["日", "一", "二", "三", "四", "五", "六"]
            : ["一", "二", "三", "四", "五", "六", "日"]
        return HStack(spacing: 0) {
            ForEach(names, id: \.self) { name in
                Text(name)
                    .font(.system(size: 12, weight: name == "日" || name == "六" ? .semibold : .regular))
                    .foregroundColor(name == "日" || name == "六" ? palette.holidayRed : palette.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    // MARK: 日网格

    private var grid: some View {
        let cells = isWeekMode ? weekCells(for: selectedDate) : monthCells(for: visibleMonth)
        let eventColors = decorations.eventColors
        let solarTermNames = decorations.solarTerms
        let festivalNames = decorations.festivals
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                if let day = cell {
                    DayCell(day: day,
                            isToday: calendar.isDate(day, inSameDayAs: Date()),
                            lunarText: LunarCalendar.displayText(for: LunarCalendar.lunar(from: day)),
                            festivalText: showLunarFestivals
                                ? festivalNames[solarTermDayKey(for: day)]
                                : nil,
                            solarTermText: solarTermNames[solarTermDayKey(for: day)],
                            effect: holidayStore.effect(for: day),
                            holidaySource: holidayStore.source(for: day),
                            isWeekend: [1, 7].contains(calendar.component(.weekday, from: day)),
                            eventColors: eventColors[calendar.startOfDay(for: day)] ?? [])
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedDate = day
                            if sizeClass != .regular {
                                selectedDay = day
                            }
                        }
                } else {
                    Color.clear.frame(height: 76)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private func solarTermNames(for month: Date) -> [DateComponents: String] {
        guard showSolarTerms else { return [:] }

        var shanghaiCalendar = Calendar(identifier: .gregorian)
        shanghaiCalendar.timeZone = LunarCalendar.timeZone
        let year = shanghaiCalendar.component(.year, from: month)
        guard let terms = SolarTermCalendar.terms(inGregorianYear: year) else { return [:] }
        return Dictionary(
            uniqueKeysWithValues: terms.map {
                (dayKey($0.date, calendar: shanghaiCalendar), $0.name.rawValue)
            }
        )
    }

    private func festivalNames(for month: Date) -> [DateComponents: String] {
        guard showLunarFestivals else { return [:] }

        var shanghaiCalendar = Calendar(identifier: .gregorian)
        shanghaiCalendar.timeZone = LunarCalendar.timeZone
        let lunarYear = LunarCalendar.lunar(from: month).year
        let years = [lunarYear - 1, lunarYear, lunarYear + 1]
        let festivals = years.compactMap { LunarFestivalCalendar.festivals(inLunarYear: $0) }
        return Dictionary(
            uniqueKeysWithValues: festivals.flatMap { $0 }.map {
                (dayKey($0.date, calendar: shanghaiCalendar), $0.name.rawValue)
            }
        )
    }

    private func solarTermDayKey(for date: Date) -> DateComponents {
        var shanghaiCalendar = Calendar(identifier: .gregorian)
        shanghaiCalendar.timeZone = LunarCalendar.timeZone
        return dayKey(date, calendar: shanghaiCalendar)
    }

    private func dayKey(_ date: Date, calendar: Calendar) -> DateComponents {
        calendar.dateComponents([.year, .month, .day], from: date)
    }

    private func monthCells(for month: Date) -> [Date?] {
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

    /// 周模式：选中日所在周的一行（周起始日设置生效，可跨月）。
    private func weekCells(for date: Date) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return monthCells(for: visibleMonth)
        }
        let first = interval.start
        let firstWeekday = calendar.component(.weekday, from: first)
        let leading = (firstWeekday + 7 - calendar.firstWeekday) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        var day = first
        while day < interval.end {
            cells.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    // MARK: 周模式日程列表

    @ViewBuilder
    private var weekDayList: some View {
        let dayEvents = eventService.events(on: selectedDate)
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("日程")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(palette.ink)
                    Spacer()
                    Text(AppFormatters.monthDayWeekday.string(from: selectedDate))
                        .font(.system(size: 12))
                        .foregroundColor(palette.secondary)
                }
                .padding(.top, 8)

                if dayEvents.isEmpty {
                    Text("这一天暂无日程")
                        .font(.system(size: 13))
                        .foregroundColor(palette.secondary)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))
                } else {
                    VStack(spacing: 8) {
                        ForEach(dayEvents) { event in
                            EventRow(event: event)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedEvent = event
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    /// 周模式下横滑：选中日 ±7 天（保持时刻），月 / 周区间由 onChange 跟随。
    private func shiftWeek(_ delta: Int) {
        selectedDate = calendar.date(byAdding: .day, value: delta * 7, to: selectedDate) ?? selectedDate
        let newMonth = Self.firstOfMonth(selectedDate)
        if !calendar.isDate(newMonth, inSameDayAs: Self.firstOfMonth(visibleMonth)) {
            visibleMonth = newMonth
        }
    }
}

/// 月格装饰（事件色点 / 节气 / 节日）的一次性计算结果。
struct MonthDecorations {
    var eventColors: [Date: [CalendarColorComponents]] = [:]
    var solarTerms: [DateComponents: String] = [:]
    var festivals: [DateComponents: String] = [:]
}

/// 单日格子：公历数字 + 农历小字 + 休/班角标
struct DayCell: View {
    @Environment(\.palette) private var palette

    let day: Date
    let isToday: Bool
    let lunarText: String
    var festivalText: String? = nil
    var solarTermText: String? = nil
    let effect: DayEffect?
    let holidaySource: HolidaySource?
    var isWeekend: Bool = false
    var hasEvents: Bool = false
    var eventColors: [CalendarColorComponents] = []

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 3) {
                ZStack {
                    if isToday {
                        Circle()
                            .fill(palette.accent)
                            .frame(width: 30, height: 30)
                    }
                    Text("\(Calendar(identifier: .gregorian).component(.day, from: day))")
                        .font(.system(size: 17, weight: isToday ? .semibold : .regular))
                        .foregroundColor(numberColor)
                }
                Text(festivalText ?? solarTermText ?? lunarText)
                    .font(.system(size: 10))
                    .foregroundColor(subtitleColor)
                    .lineLimit(1)
                if !eventColors.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(eventColors, id: \.self) { color in
                            Circle()
                                .fill(color.swiftUIColor)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            badge
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 12).fill(cellBackground))
    }

    private var numberColor: Color {
        if isToday { return .white }
        if case .workday = effect { return palette.makeupGray }
        if isWeekend || isRestDay { return palette.holidayRed }
        return palette.ink
    }

    private var isRestDay: Bool {
        if case .restDay = effect { return true }
        return false
    }

    private var cellBackground: Color {
        if case .restDay = effect { return palette.holidayRed.opacity(0.08) }
        if case .workday = effect { return palette.makeupGray.opacity(0.10) }
        if isWeekend { return palette.holidayRed.opacity(0.05) }
        return .clear
    }

    private var lunarColor: Color {
        if case .restDay = effect { return palette.holidayRed }
        if case .workday = effect { return palette.makeupGray }
        if isWeekend { return palette.holidayRed.opacity(0.8) }
        return palette.secondary
    }

    private var subtitleColor: Color {
        if festivalText != nil { return palette.holidayRed }
        if solarTermText != nil { return palette.solarGreen }
        return lunarColor
    }

    @ViewBuilder
    private var badge: some View {
        let source = holidaySource ?? .official
        switch effect {
        case .restDay:
            if source == .estimated {
                badgeText("休估", color: palette.makeupGray.opacity(0.85))
            } else {
                badgeText("休", color: palette.holidayRed)
            }
        case .workday:
            if source == .estimated {
                badgeText("班估", color: palette.makeupGray.opacity(0.85))
            } else {
                badgeText("班", color: palette.makeupGray)
            }
        case nil:
            EmptyView()
        }
    }

    private func badgeText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(color))
            .offset(x: -4, y: 4)
    }
}

extension Date: Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}
