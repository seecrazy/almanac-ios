import SwiftUI
import LunarKit
import HolidayData

struct DayDetail: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService
    @EnvironmentObject private var milestoneStore: MilestoneStore
    @State private var composerContext: EventComposerContext?
    @State private var selectedEvent: CalendarEvent?
    @AppStorage("showHuangLi") private var showHuangLi = false
    @AppStorage("showSolarTerms") private var showSolarTerms = true

    let date: Date
    let holidayStore: HolidayStore

    private var calendar = Calendar(identifier: .gregorian)

    init(date: Date, holidayStore: HolidayStore) {
        self.date = date
        self.holidayStore = holidayStore
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            grabber
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    holidayBanner
                    if showHuangLi {
                        AlmanacPanel(date: date)
                    }
                    holidayCoverageFootnote
                    milestoneBanners
                    anniversaryBanners
                    nextHolidayFootnote
                    eventList
                }
                .padding(.horizontal, 24)
            }
        }
        .background(palette.background.ignoresSafeArea())
        .sheet(item: $composerContext) { context in
            AddEventView(initialDate: context.date)
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event) {}
        }
    }

    private var grabber: some View {
        HStack {
            Spacer()
            Capsule()
                .fill(palette.separator)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
            Spacer()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 56, weight: .semibold, design: .serif))
                .foregroundColor(palette.ink)
            Text(dateLine)
                .font(.system(size: 15))
                .foregroundColor(palette.ink)
            Text(lunarLine)
                .font(.system(size: 14))
                .foregroundColor(palette.secondary)
            if showSolarTerms, let solarTerm = SolarTermCalendar.term(on: date) {
                Text("节气 · \(solarTerm.name.rawValue)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(palette.solarGreen)
            }
        }
    }

    private var dateLine: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter.string(from: date)
    }

    private var lunarLine: String {
        let lunar = LunarCalendar.lunar(from: date)
        let leapPrefix = lunar.isLeapMonth ? "闰" : ""
        let gz = GanZhi.dayGanZhi(for: date)
        return "\(GanZhi.yearGanZhi(forGregorianYear: lunar.year).ganZhi)年 \(leapPrefix)\(LunarCalendar.monthNames[lunar.month])\(LunarCalendar.dayNames[lunar.day]) · \(gz)日"
    }

    @ViewBuilder
    private var holidayBanner: some View {
        let source = holidayStore.source(for: date)
        switch holidayStore.effect(for: date) {
        case .restDay(let name):
            VStack(alignment: .leading, spacing: 6) {
                banner(text: "\(name) · 法定休", color: palette.holidayRed)
                sourceFootnote(for: source)
            }
        case .workday(let name):
            VStack(alignment: .leading, spacing: 6) {
                banner(text: "\(name)调休 · 补班日", color: palette.makeupGray)
                sourceFootnote(for: source)
            }
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private var holidayCoverageFootnote: some View {
        switch holidayStore.coverage(for: date) {
        case .yearNotLoaded:
            Text("该年份节假日数据未加载")
                .font(.system(size: 12))
                .foregroundColor(palette.secondary)
        case .unknown:
            Text("节假日数据未覆盖")
                .font(.system(size: 12))
                .foregroundColor(palette.secondary)
        case .covered, .noSpecialDay:
            EmptyView()
        }
    }

    @ViewBuilder
    private func sourceFootnote(for source: HolidaySource?) -> some View {
        switch source {
        case .sample:
            Text("示例数据，仅供参考")
                .font(.system(size: 12))
                .foregroundColor(palette.secondary)
        case .estimated:
            Text("预测数据，未经官方确认")
                .font(.system(size: 12))
                .foregroundColor(palette.secondary)
        case .official, nil:
            EmptyView()
        }
    }

    private func banner(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(color))
    }

    @ViewBuilder
    private var milestoneBanners: some View {
        let dayMilestones = milestoneStore.milestones(on: date)
        if !dayMilestones.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("里程碑")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(palette.ink)

                VStack(spacing: 8) {
                    ForEach(dayMilestones) { milestone in
                        MilestoneBanner(
                            milestone: milestone,
                            countdown: milestoneStore.countdown(for: milestone, at: Date())
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var anniversaryBanners: some View {
        let occurrences = milestoneStore.anniversaries(on: date)
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

    @ViewBuilder
    private var nextHolidayFootnote: some View {
        if holidayStore.coverage(for: date) == .noSpecialDay,
           let next = holidayStore.nextHoliday(after: date) {
            let days = Calendar(identifier: .gregorian)
                .dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: next.date)).day ?? 0
            Text("距离\(next.name)还有 \(days) 天")
                .font(.system(size: 13))
                .foregroundColor(palette.secondary)
        }
    }

    @ViewBuilder
    private var eventList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("今日日程")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(palette.ink)
                Spacer()
                Button {
                    composerContext = EventComposerContext(date: date)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(palette.accent)
                }
                .accessibilityLabel("新建日程")
            }
            let dayEvents = eventService.events(on: date)
            if dayEvents.isEmpty {
                Text("这一天暂无日程")
                    .font(.system(size: 13))
                    .foregroundColor(palette.secondary)
                    .padding(.vertical, 24)
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
    }
}

struct EventComposerContext: Identifiable {
    let id = UUID()
    let date: Date
}

struct EventRow: View {
    @Environment(\.palette) private var palette

    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.calendarColor?.swiftUIColor ?? palette.accent)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(palette.ink)
                Text(timeText)
                    .font(.system(size: 12))
                    .foregroundColor(palette.secondary)
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 12))
                        .foregroundColor(palette.secondary)
                }
                Text(event.calendarTitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(palette.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))
    }

    private var timeText: String {
        if event.isAllDay { return "全天" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        let sameDay = Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate)
        if sameDay {
            return "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))"
        }
        formatter.dateFormat = "M月d日 HH:mm"
        return "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))"
    }
}

struct MilestoneBanner: View {
    @Environment(\.palette) private var palette

    let milestone: Milestone
    let countdown: MilestoneCountdown

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(countdown.isPast ? palette.makeupGray : palette.holidayRed)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(milestone.category.icon) \(milestone.title)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(palette.ink)
                Text("\(milestone.category.title) · \(countdown.isPast ? "已开始" : countdown.primaryText + countdown.unitText)")
                    .font(.system(size: 12))
                    .foregroundColor(palette.secondary)
            }

            Spacer()

            Text(countdown.primaryText)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundColor(countdown.isPast ? palette.makeupGray : palette.holidayRed)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))
    }
}
