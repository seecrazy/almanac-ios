import EventKit
import Foundation
import SwiftUI

enum EventRecurrenceMode: String, CaseIterable, Identifiable {
    case none
    case daily
    case weekly
    case biweekly
    case monthly
    case yearly
    case preserveExisting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "不重复"
        case .daily: return "每天"
        case .weekly: return "每周"
        case .biweekly: return "每两周"
        case .monthly: return "每月"
        case .yearly: return "每年"
        case .preserveExisting: return "保留现有规则"
        }
    }

    static func formModes(isProtected: Bool) -> [EventRecurrenceMode] {
        isProtected ? [.preserveExisting] : [.none, .daily, .weekly, .biweekly, .monthly, .yearly]
    }
}

enum EventRecurrenceEndMode: String, CaseIterable, Identifiable {
    case never
    case onDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: return "一直重复"
        case .onDate: return "到日期重复"
        }
    }
}

struct EventRecurrenceDraft: Hashable {
    var mode: EventRecurrenceMode
    var endMode: EventRecurrenceEndMode
    var endDate: Date

    init(mode: EventRecurrenceMode, endMode: EventRecurrenceEndMode = .never, endDate: Date) {
        self.mode = mode
        self.endMode = endMode
        self.endDate = endDate
    }

    init(startDate: Date) {
        let fallbackDate = Calendar.current.date(byAdding: .month, value: 3, to: startDate) ?? startDate
        self.init(mode: .none, endMode: .never, endDate: fallbackDate)
    }

    init?(rules: [EKRecurrenceRule]?, startDate: Date) {
        guard let rules, rules.count == 1, let rule = rules.first else {
            self = EventRecurrenceDraft(startDate: startDate)
            return
        }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.weekday, .day, .month], from: startDate)
        var mode: EventRecurrenceMode

        switch rule.frequency {
        case .daily where rule.interval == 1:
            mode = .daily
        case .weekly where rule.interval == 1:
            mode = .weekly
        case .weekly where rule.interval == 2:
            mode = .biweekly
        case .monthly where rule.interval == 1:
            mode = .monthly
        case .yearly where rule.interval == 1:
            mode = .yearly
        default:
            self = EventRecurrenceDraft.preserved()
            return
        }

        let weekdayRules = rule.daysOfTheWeek ?? []
        let dayRules = (rule.daysOfTheMonth ?? []).compactMap { $0.intValue }
        let monthRules = (rule.monthsOfTheYear ?? []).compactMap { $0.intValue }

        switch mode {
        case .weekly, .biweekly:
            let matchesStartWeekday = weekdayRules.count == 1
                && weekdayRules[0].weekNumber == 0
                && weekdayRules[0].dayOfTheWeek.rawValue == startComponents.weekday
            if !matchesStartWeekday {
                self = EventRecurrenceDraft.preserved()
                return
            }
        case .monthly:
            let matchesStartDay = weekdayRules.isEmpty
                && (dayRules.isEmpty || dayRules == [startComponents.day])
            if !matchesStartDay {
                self = EventRecurrenceDraft.preserved()
                return
            }
        case .yearly:
            let matchesStartDate = weekdayRules.isEmpty
                && (monthRules.isEmpty || monthRules == [startComponents.month])
                && (dayRules.isEmpty || dayRules == [startComponents.day])
            if !matchesStartDate {
                self = EventRecurrenceDraft.preserved()
                return
            }
        default:
            break
        }

        let recurrenceEnd = rule.recurrenceEnd
        if recurrenceEnd == nil {
            self = EventRecurrenceDraft(mode: mode, endMode: .never, endDate: startDate)
            return
        }

        if recurrenceEnd?.occurrenceCount == nil, let endDate = recurrenceEnd?.endDate {
            self = EventRecurrenceDraft(
                mode: mode,
                endMode: .onDate,
                endDate: calendar.startOfDay(for: endDate)
            )
            return
        }

        self = EventRecurrenceDraft.preserved()
    }

    static func preserved() -> EventRecurrenceDraft {
        EventRecurrenceDraft(mode: .preserveExisting, endMode: .never, endDate: Date())
    }

    func makeRule(startDate: Date) -> EKRecurrenceRule? {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.weekday, .day, .month], from: startDate)
        let frequency: EKRecurrenceFrequency
        let interval: Int
        var weekdays: [EKRecurrenceDayOfWeek]?
        var daysOfTheMonth: [NSNumber]?
        var monthsOfTheYear: [NSNumber]?

        switch mode {
        case .none, .preserveExisting:
            return nil
        case .daily:
            frequency = .daily
            interval = 1
        case .weekly:
            frequency = .weekly
            interval = 1
            if let weekday = startComponents.weekday, let recurrenceWeekday = EKWeekday(rawValue: weekday) {
                weekdays = [EKRecurrenceDayOfWeek(recurrenceWeekday)]
            }
        case .biweekly:
            frequency = .weekly
            interval = 2
            if let weekday = startComponents.weekday, let recurrenceWeekday = EKWeekday(rawValue: weekday) {
                weekdays = [EKRecurrenceDayOfWeek(recurrenceWeekday)]
            }
        case .monthly:
            frequency = .monthly
            interval = 1
            daysOfTheMonth = [NSNumber(value: startComponents.day ?? 1)]
        case .yearly:
            frequency = .yearly
            interval = 1
            monthsOfTheYear = [NSNumber(value: startComponents.month ?? 1)]
            daysOfTheMonth = [NSNumber(value: startComponents.day ?? 1)]
        }

        let end: EKRecurrenceEnd?
        if endMode == .onDate {
            let selectedDayStart = calendar.startOfDay(for: endDate)
            let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: selectedDayStart)
                ?? selectedDayStart
            end = EKRecurrenceEnd(end: endOfDay)
        } else {
            end = nil
        }

        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            daysOfTheWeek: weekdays,
            daysOfTheMonth: daysOfTheMonth,
            monthsOfTheYear: monthsOfTheYear,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: end
        )
    }

    static func summary(for rules: [EKRecurrenceRule]?, startDate: Date) -> String? {
        guard let rules, !rules.isEmpty else { return nil }
        guard let draft = EventRecurrenceDraft(rules: rules, startDate: startDate),
              draft.mode != .preserveExisting else {
            return "自定义重复（宜历 v1 不修改）"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"

        switch draft.endMode {
        case .never:
            return draft.mode.title
        case .onDate:
            return "\(draft.mode.title) · 至 \(formatter.string(from: draft.endDate))"
        }
    }
}

struct EventRecurrenceEditor: View {
    @Environment(\.palette) private var palette

    @Binding var draft: EventRecurrenceDraft
    let startDate: Date
    let isProtected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("重复", selection: $draft.mode) {
                ForEach(EventRecurrenceMode.formModes(isProtected: isProtected)) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .disabled(isProtected)

            if draft.mode != .none && draft.mode != .preserveExisting {
                Picker("结束", selection: $draft.endMode) {
                    ForEach(EventRecurrenceEndMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                if draft.endMode == .onDate {
                    DatePicker(
                        "结束日期",
                        selection: $draft.endDate,
                        in: Calendar.current.startOfDay(for: startDate)...,
                        displayedComponents: [.date]
                    )
                }

                Text(recurrenceFootnote)
                    .font(.footnote)
                    .foregroundColor(palette.secondary)
            }
        }
        .onChange(of: startDate) { newValue in
            let newDayStart = Calendar.current.startOfDay(for: newValue)
            if draft.endDate < newDayStart {
                draft.endDate = newDayStart
            }
        }
    }

    private var recurrenceFootnote: String {
        let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let components = Calendar.current.dateComponents([.weekday, .day, .month], from: startDate)
        switch draft.mode {
        case .weekly, .biweekly:
            let weekday = weekdayNames[(components.weekday ?? 1) - 1]
            return "将按开始时间的星期\(weekday)重复。"
        case .monthly:
            return "将按开始时间的每月 \(components.day ?? 1) 日重复。"
        case .yearly:
            return "将按开始时间的每年 \(components.month ?? 1) 月 \(components.day ?? 1) 日重复。"
        default:
            return ""
        }
    }
}
