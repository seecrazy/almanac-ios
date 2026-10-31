import SwiftUI
import LunarKit
import HolidayData

struct DayDetail: View {
    @Environment(\.palette) private var palette

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
                    nextHolidayFootnote
                    eventPlaceholder
                }
                .padding(.horizontal, 24)
            }
        }
        .background(palette.background.ignoresSafeArea())
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
        switch holidayStore.effect(for: date) {
        case .restDay(let name):
            banner(text: "\(name) · 法定休", color: palette.holidayRed)
        case .workday(let name):
            banner(text: "\(name)调休 · 补班日", color: palette.makeupGray)
        case nil:
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
    private var nextHolidayFootnote: some View {
        if holidayStore.effect(for: date) == nil,
           let next = holidayStore.nextHoliday(after: date) {
            let days = Calendar(identifier: .gregorian)
                .dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: next.date)).day ?? 0
            Text("距离\(next.name)还有 \(days) 天")
                .font(.system(size: 13))
                .foregroundColor(palette.secondary)
        }
    }

    private var eventPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日日程")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(palette.ink)
            Text("日程视图将接入系统日历（ADR-001）")
                .font(.system(size: 13))
                .foregroundColor(palette.secondary)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))
        }
    }
}
