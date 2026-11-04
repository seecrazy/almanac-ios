import SwiftUI
import EventKitMapping

struct EventRecurrenceEditor: View {
    @Environment(\.palette) private var palette

    @Binding var draft: EventRecurrenceDraft
    let startDate: Date
    let isProtected: Bool

    private let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    private let weekdayValues = Array(1...7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isProtected || draft.mode == .preserveExisting {
                Text("当前重复规则较复杂，宜历暂不支持修改。")
                    .font(.footnote)
                    .foregroundColor(palette.secondary)
            } else {
                Picker("重复", selection: $draft.mode) {
                    ForEach(EventRecurrenceMode.formModes(isProtected: false)) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                if draft.mode != .none {
                    if draft.mode == .daily {
                        Stepper("间隔：每 \(draft.interval) 天", value: $draft.interval, in: 1...999)
                    }

                    if draft.mode == .weekly || draft.mode == .biweekly {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("周几")
                                .font(.footnote)
                                .foregroundColor(palette.secondary)
                            HStack(spacing: 6) {
                                ForEach(weekdayValues, id: \.self) { weekday in
                                    Button {
                                        toggleWeekday(weekday)
                                    } label: {
                                        Text(weekdayNames[weekday - 1])
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(draft.weekdays.contains(weekday) ? .white : palette.ink)
                                            .frame(maxWidth: .infinity, minHeight: 28)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(draft.weekdays.contains(weekday) ? palette.accent : palette.card)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(weekdayNames[weekday - 1])
                                }
                            }
                        }
                    }

                    if draft.mode == .monthly {
                        Picker("月规则", selection: $draft.monthlyRule) {
                            Text("按日期").tag(EventMonthlyRecurrenceRule.dayOfMonth(
                                Calendar.current.component(.day, from: startDate)
                            ))
                            Text("第 N 个周几").tag(EventMonthlyRecurrenceRule.nthWeekday(
                                week: 1,
                                weekday: Calendar.current.component(.weekday, from: startDate)
                            ))
                        }
                        .pickerStyle(.segmented)

                        monthlyRuleEditor
                    }

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
                    } else if draft.endMode == .afterCount {
                        Stepper("重复 \(draft.occurrenceCount) 次", value: $draft.occurrenceCount, in: 1...999)
                    }

                    Text(previewText)
                        .font(.footnote)
                        .foregroundColor(palette.secondary)
                }
            }
        }
        .onChange(of: startDate) { newValue in
            let newDayStart = Calendar.current.startOfDay(for: newValue)
            if draft.endDate < newDayStart {
                draft.endDate = newDayStart
            }
        }
        .onChange(of: draft.mode) { newValue in
            if newValue == .weekly || newValue == .biweekly {
                if draft.weekdays.isEmpty {
                    draft.weekdays = [Calendar.current.component(.weekday, from: startDate)]
                }
            }
            if newValue == .monthly,
                case .dayOfMonth = draft.monthlyRule {
                draft.monthlyRule = .dayOfMonth(Calendar.current.component(.day, from: startDate))
            }
        }
    }

    @ViewBuilder
    private var monthlyRuleEditor: some View {
        switch draft.monthlyRule {
        case .dayOfMonth(let day):
            Stepper("每月 \(day) 日", value: Binding(
                get: { day },
                set: { draft.monthlyRule = .dayOfMonth($0) }
            ), in: 1...31)
        case .nthWeekday(let week, let weekday):
            Stepper("第 \(week) 周", value: Binding(
                get: { week },
                set: { draft.monthlyRule = .nthWeekday(week: $0, weekday: weekday) }
            ), in: 1...5)
            Picker("周几", selection: Binding(
                get: { weekday },
                set: { draft.monthlyRule = .nthWeekday(week: week, weekday: $0) }
            )) {
                ForEach(Array(weekdayNames.enumerated()), id: \.offset) { index, name in
                    Text(name).tag(index + 1)
                }
            }
        }
    }

    private func toggleWeekday(_ weekday: Int) {
        if draft.weekdays.contains(weekday) {
            draft.weekdays.remove(weekday)
        } else {
            draft.weekdays.insert(weekday)
        }
    }

    private var previewText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        let occurrences = draft.previewOccurrences(startDate: startDate)
        let dates = occurrences.map { formatter.string(from: $0) }.joined(separator: "、")
        let endText: String
        switch draft.endMode {
        case .never: endText = "一直重复"
        case .onDate:
            let endFormatter = DateFormatter()
            endFormatter.locale = Locale(identifier: "zh_CN")
            endFormatter.dateFormat = "yyyy年M月d日"
            endText = "重复至 \(endFormatter.string(from: draft.endDate))"
        case .afterCount: endText = "重复 \(draft.occurrenceCount) 次"
        }
        return "下次：\(dates)。\(endText)。"
    }
}
