import SwiftUI
import LunarKit
import HolidayData

enum CalendarViewMode: String, CaseIterable, Identifiable {
    case month
    case week
    case day
    case agenda
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: return "月"
        case .week: return "周"
        case .day: return "日"
        case .agenda: return "议程"
        case .year: return "年"
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

    private let holidayStore = HolidayStore.bundled()

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
        case .week:
            return "week-\(selectedDate.timeIntervalSince1970)-\(weekStartDayRaw)"
        case .day:
            return "day-\(selectedDate.timeIntervalSince1970)"
        case .agenda:
            return "agenda-\(selectedDate.timeIntervalSince1970)-\(agendaRange.rawValue)"
        case .year:
            return "year-\(visibleYear.timeIntervalSince1970)"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            modePicker
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
    }

    private var modePicker: some View {
        Picker("视图", selection: $modeRaw) {
            ForEach(CalendarViewMode.allCases) { mode in
                Text(mode.title).tag(mode.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .accessibilityLabel("日历视图")
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
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .month:
            MonthView(visibleMonth: $visibleMonth, selectedDate: $selectedDate)
        case .week:
            CalendarWeekView(
                selectedDate: $selectedDate,
                holidayStore: holidayStore,
                onSelectDay: { day in
                    selectedDate = day
                    modeRaw = CalendarViewMode.day.rawValue
                }
            )
        case .day:
            CalendarDayView(
                selectedDate: $selectedDate,
                holidayStore: holidayStore
            )
        case .agenda:
            CalendarAgendaView(
                startDate: selectedDate,
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
        case .week:
            if let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) {
                await eventService.loadEvents(from: interval.start, to: interval.end)
            }
        case .day:
            let start = calendar.startOfDay(for: selectedDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            await eventService.loadEvents(from: start, to: end)
        case .agenda:
            let start = calendar.startOfDay(for: selectedDate)
            let end = calendar.date(byAdding: .day, value: agendaRange.rawValue, to: start) ?? start
            await eventService.loadEvents(from: start, to: end)
        case .year:
            await loadYearByMonth()
        }
    }

    private func loadYearByMonth() async {
        let year = calendar.component(.year, from: visibleYear)
        for month in 1...12 {
            guard let firstOfMonth = calendar.date(
                from: DateComponents(year: year, month: month, day: 1)
            ), let interval = calendar.dateInterval(of: .month, for: firstOfMonth) else {
                continue
            }
            await eventService.loadEvents(
                from: interval.start,
                to: interval.end,
                appending: month > 1
            )
        }
    }
}

private struct CalendarWeekView: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService
    @AppStorage("month.week.start.day") private var weekStartDayRaw = WeekStartDay.monday.rawValue
    @AppStorage("showSolarTerms") private var showSolarTerms = true
    @AppStorage("showLunarFestivals") private var showLunarFestivals = true

    @Binding var selectedDate: Date
    let holidayStore: HolidayStore
    let onSelectDay: (Date) -> Void

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = WeekStartDay(rawValue: weekStartDayRaw)?.firstWeekday ?? 2
        return calendar
    }

    private var weekInterval: DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: selectedDate)
            ?? DateInterval(start: selectedDate, duration: 7 * 24 * 60 * 60)
    }

    private var weekDays: [Date] {
        (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekInterval.start)
        }
    }

    var body: some View {
        let solarTermNameMap = solarTermNameMap
        let festivalNameMap = festivalNameMap
        VStack(spacing: 0) {
            header
            weekdayHeader
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(weekDays, id: \.timeIntervalSince1970) { day in
                        WeekDayColumn(
                            day: day,
                            isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(day),
                            events: Array(eventService.events(on: day).prefix(3)),
                            totalEventCount: eventService.events(on: day).count,
                            festivalText: showLunarFestivals
                                ? festivalNameMap[solarTermDayKey(for: day)]
                                : nil,
                            solarTermText: solarTermNameMap[solarTermDayKey(for: day)],
                            effect: holidayStore.effect(for: day),
                            onTap: { onSelectDay(day) }
                        )
                    }
                }
                .padding(.horizontal, 12)
            }
            Spacer(minLength: 0)
        }
        .gesture(
            DragGesture(minimumDistance: 56)
                .onEnded { value in
                    let horizontal = abs(value.translation.width)
                    let vertical = abs(value.translation.height)
                    guard horizontal >= 56, horizontal >= vertical * 1.5 else { return }
                    shiftWeek(value.translation.width < 0 ? 1 : -1)
                }
        )
    }

    private var solarTermNameMap: [DateComponents: String] {
        guard showSolarTerms else { return [:] }

        var shanghaiCalendar = Calendar(identifier: .gregorian)
        shanghaiCalendar.timeZone = LunarCalendar.timeZone
        let years = Set(weekDays.map {
            shanghaiCalendar.component(.year, from: $0)
        })
        let terms = years.compactMap { SolarTermCalendar.terms(inGregorianYear: $0) }
        return Dictionary(
            uniqueKeysWithValues: terms.flatMap { $0 }.map {
                (dayKey($0.date, calendar: shanghaiCalendar), $0.name.rawValue)
            }
        )
    }

    private var festivalNameMap: [DateComponents: String] {
        guard showLunarFestivals else { return [:] }

        var shanghaiCalendar = Calendar(identifier: .gregorian)
        shanghaiCalendar.timeZone = LunarCalendar.timeZone
        let lunarYears = Set(weekDays.map {
            LunarCalendar.lunar(from: $0).year
        })
        let festivals = lunarYears.compactMap {
            LunarFestivalCalendar.festivals(inLunarYear: $0)
        }
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

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(titleText)
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundColor(palette.ink)
                Text(subtitleText)
                    .font(.system(size: 12))
                    .foregroundColor(palette.secondary)
            }
            Spacer()
            Button { shiftWeek(-1) } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(palette.secondary)
                    .frame(width: 36, height: 36)
            }
            Button { shiftWeek(1) } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(palette.secondary)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var weekdayHeader: some View {
        let names = weekStartDayRaw == WeekStartDay.sunday.rawValue
            ? ["日", "一", "二", "三", "四", "五", "六"]
            : ["一", "二", "三", "四", "五", "六", "日"]
        return HStack(spacing: 0) {
            ForEach(names, id: \.self) { name in
                Text(name)
                    .font(.system(size: 11))
                    .foregroundColor(palette.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private var titleText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        let start = formatter.string(from: weekInterval.start)
        formatter.dateFormat = "d日"
        let end = formatter.string(from: weekInterval.end.addingTimeInterval(-1))
        return "\(start) – \(end)"
    }

    private var subtitleText: String {
        let count = weekDays.reduce(0) { count, day in
            count + eventService.events(on: day).count
        }
        return "本周 \(count) 个日程"
    }

    private func shiftWeek(_ delta: Int) {
        selectedDate = calendar.date(
            byAdding: .weekOfYear,
            value: delta,
            to: selectedDate
        ) ?? selectedDate
    }
}

private struct WeekDayColumn: View {
    @Environment(\.palette) private var palette
    let day: Date
    let isSelected: Bool
    let isToday: Bool
    let events: [CalendarEvent]
    let totalEventCount: Int
    var festivalText: String? = nil
    var solarTermText: String? = nil
    let effect: DayEffect?
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .center, spacing: 3) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(dayColor)
                Text(
                    festivalText
                        ?? solarTermText
                        ?? LunarCalendar.displayText(for: LunarCalendar.lunar(from: day))
                )
                    .font(.system(size: 10))
                    .foregroundColor(subtitleColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? palette.accent.opacity(0.16) : palette.card)
            )

            VStack(alignment: .leading, spacing: 5) {
                if events.isEmpty {
                    Text("无日程")
                        .font(.system(size: 10))
                        .foregroundColor(palette.secondary)
                } else {
                    ForEach(events) { event in
                        Text(event.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(palette.ink)
                            .lineLimit(2)
                    }
                    if totalEventCount > 3 {
                        Text("+\(totalEventCount - 3)")
                            .font(.system(size: 10))
                            .foregroundColor(palette.secondary)
                    }
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(width: 96, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var dayColor: Color {
        if isToday { return palette.accent }
        if case .workday = effect { return palette.makeupGray }
        if case .restDay = effect { return palette.holidayRed }
        return palette.ink
    }

    private var subtitleColor: Color {
        if festivalText != nil { return palette.holidayRed }
        if solarTermText != nil { return palette.solarGreen }
        return palette.secondary
    }
}

private struct CalendarDayView: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService
    @EnvironmentObject private var milestoneStore: MilestoneStore

    @Binding var selectedDate: Date
    let holidayStore: HolidayStore

    @State private var composerContext: EventComposerContext?
    @State private var selectedEvent: CalendarEvent?
    @AppStorage("showHuangLi") private var showHuangLi = false
    @AppStorage("showSolarTerms") private var showSolarTerms = true
    @AppStorage("showLunarFestivals") private var showLunarFestivals = true

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                holidayBanner
                milestoneBanners
                anniversaryBanners
                eventList
                if showHuangLi {
                    AlmanacPanel(date: selectedDate)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .sheet(item: $composerContext) { context in
            AddEventView(initialDate: context.date)
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event) {}
        }
        .gesture(
            DragGesture(minimumDistance: 56)
                .onEnded { value in
                    let horizontal = abs(value.translation.width)
                    let vertical = abs(value.translation.height)
                    guard horizontal >= 56, horizontal >= vertical * 1.5 else { return }
                    shiftDay(value.translation.width < 0 ? 1 : -1)
                }
        )
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(calendar.component(.day, from: selectedDate))")
                    .font(.system(size: 52, weight: .semibold, design: .serif))
                    .foregroundColor(palette.ink)
                Text(dateLine)
                    .font(.system(size: 14))
                    .foregroundColor(palette.ink)
                Text(lunarLine)
                    .font(.system(size: 13))
                    .foregroundColor(palette.secondary)
                if showLunarFestivals, let festival = LunarFestivalCalendar.festival(on: selectedDate) {
                    Text("农历节日 · \(festival.name.rawValue)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(palette.holidayRed)
                }
                if showSolarTerms, let solarTerm = SolarTermCalendar.term(on: selectedDate) {
                    Text("节气 · \(solarTerm.name.rawValue)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(palette.solarGreen)
                }
            }
            Spacer()
            HStack(spacing: 4) {
                Button { shiftDay(-1) } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(palette.secondary)
                        .frame(width: 34, height: 34)
                }
                Button { shiftDay(1) } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(palette.secondary)
                        .frame(width: 34, height: 34)
                }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var holidayBanner: some View {
        switch holidayStore.effect(for: selectedDate) {
        case .restDay(let name):
            Text("\(name) · 法定休")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(palette.holidayRed))
        case .workday(let name):
            Text("\(name)调休 · 补班日")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(palette.makeupGray))
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private var milestoneBanners: some View {
        let milestones = milestoneStore.milestones(on: selectedDate)
        if !milestones.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("里程碑")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(palette.ink)
                ForEach(milestones) { milestone in
                    MilestoneBanner(
                        milestone: milestone,
                        countdown: milestoneStore.countdown(for: milestone, at: Date())
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var anniversaryBanners: some View {
        let occurrences = milestoneStore.anniversaries(on: selectedDate)
        if !occurrences.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("生日 / 纪念日")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(palette.ink)
                ForEach(occurrences) { occurrence in
                    HStack {
                        Text("\(occurrence.anniversary.title)\(occurrence.countText.map { " · \($0)" } ?? "")")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(palette.ink)
                        Spacer()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))
                }
            }
        }
    }

    private var eventList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("日程")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(palette.ink)
                Spacer()
                Button {
                    composerContext = EventComposerContext(date: selectedDate)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20))
                        .foregroundColor(palette.accent)
                }
                .accessibilityLabel("新建日程")
            }

            let events = eventService.events(on: selectedDate)
            if events.isEmpty {
                Text(eventService.accessState == .denied ? "无法读取系统日历" : "这一天暂无日程")
                    .font(.system(size: 13))
                    .foregroundColor(palette.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))
            } else {
                ForEach(events) { event in
                    EventRow(event: event)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedEvent = event }
                }
            }
        }
    }

    private var dateLine: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter.string(from: selectedDate)
    }

    private var lunarLine: String {
        let lunar = LunarCalendar.lunar(from: selectedDate)
        let leap = lunar.isLeapMonth ? "闰" : ""
        let ganZhi = GanZhi.dayGanZhi(for: selectedDate)
        return "\(GanZhi.yearGanZhi(forGregorianYear: lunar.year).ganZhi)年 \(leap)\(LunarCalendar.monthNames[lunar.month])\(LunarCalendar.dayNames[lunar.day]) · \(ganZhi)日"
    }

    private func shiftDay(_ delta: Int) {
        selectedDate = calendar.date(byAdding: .day, value: delta, to: selectedDate) ?? selectedDate
    }
}

struct AlmanacPanel: View {
    @Environment(\.palette) private var palette

    let date: Date
    @State private var isExpanded = false

    var body: some View {
        let rules = AlmanacRuleSet.bundled()
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

    let startDate: Date
    @Binding var range: AgendaRange

    @State private var visibleLimit = 200

    private let calendar = Calendar.current

    private var days: [Date] {
        let start = calendar.startOfDay(for: startDate)
        return (0..<range.rawValue).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }

    private var totalEventCount: Int {
        days.reduce(0) { count, day in
            count + eventService.events(on: day).count
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
        let sections = agendaSections
        if sections.isEmpty {
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

    private var agendaSections: [(day: Date, events: [CalendarEvent])] {
        var remaining = visibleLimit
        return days.map { day in
            let allEvents = eventService.events(on: day)
            let events = Array(allEvents.prefix(remaining))
            remaining -= events.count
            return (day, events)
        }
    }

    private func dayTitle(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: day)
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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月"
        return formatter.string(from: month)
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
