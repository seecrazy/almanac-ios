import SwiftUI
import LunarKit
import HolidayData

struct MonthView: View {
    @Environment(\.palette) private var palette

    @State private var visibleMonth: Date = MonthView.firstOfMonth(Date())
    @State private var selectedDay: Date?

    private let holidayStore = HolidayStore.bundled()
    private var calendar = Calendar(identifier: .gregorian)

    static func firstOfMonth(_ date: Date) -> Date {
        let c = Calendar(identifier: .gregorian)
        let comps = c.dateComponents([.year, .month], from: date)
        return c.date(from: comps) ?? date
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            weekdayHeader
            grid
            Spacer(minLength: 0)
        }
        .background(palette.background.ignoresSafeArea())
        .sheet(item: $selectedDay) { day in
            DayDetail(date: day, holidayStore: holidayStore)
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
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(palette.secondary)
                    .frame(width: 36, height: 36)
            }
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(palette.secondary)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
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

    // MARK: 星期表头（周一起始）

    private var weekdayHeader: some View {
        let names = ["一", "二", "三", "四", "五", "六", "日"]
        return HStack(spacing: 0) {
            ForEach(names, id: \.self) { name in
                Text(name)
                    .font(.system(size: 12))
                    .foregroundColor(palette.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    // MARK: 日网格

    private var grid: some View {
        let cells = monthCells(for: visibleMonth)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                if let day = cell {
                    DayCell(day: day,
                            isToday: calendar.isDate(day, inSameDayAs: Date()),
                            lunarText: LunarCalendar.displayText(for: LunarCalendar.lunar(from: day)),
                            effect: holidayStore.effect(for: day))
                        .contentShape(Rectangle())
                        .onTapGesture { selectedDay = day }
                } else {
                    Color.clear.frame(height: 76)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private func monthCells(for month: Date) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let first = interval.start
        let dayCount = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: first)
        let leading = (firstWeekday + 5) % 7      // 周一起始
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: first))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }
}

/// 单日格子：公历数字 + 农历小字 + 休/班角标
struct DayCell: View {
    @Environment(\.palette) private var palette

    let day: Date
    let isToday: Bool
    let lunarText: String
    let effect: DayEffect?

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
                Text(lunarText)
                    .font(.system(size: 10))
                    .foregroundColor(lunarColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            badge
        }
    }

    private var numberColor: Color {
        if isToday { return .white }
        if case .workday = effect { return palette.makeupGray }
        return palette.ink
    }

    private var lunarColor: Color {
        if case .restDay = effect { return palette.holidayRed }
        if case .workday = effect { return palette.makeupGray }
        return palette.secondary
    }

    @ViewBuilder
    private var badge: some View {
        switch effect {
        case .restDay:
            badgeText("休", color: palette.holidayRed)
        case .workday:
            badgeText("班", color: palette.makeupGray)
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
