import SwiftUI
import HolidayData

struct SettingsView: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService

    @AppStorage("showLunar") private var showLunar = true
    @AppStorage("showSolarTerms") private var showSolarTerms = true
    @AppStorage("showHuangLi") private var showHuangLi = false
    @AppStorage("month.week.start.day") private var weekStartDayRaw = WeekStartDay.monday.rawValue

    private let holidayStore = HolidayStore.bundled()

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
                    toggleRow("黄历（宜忌/冲煞）", binding: $showHuangLi)
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

                    Text("当前内置数据仍为示例；官方通知发布后按数据管道更新。")
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

                Text("黄历默认关闭；开关控制日详情中的黄历面板。当前版本设置不参与同步。")
                    .font(.system(size: 13))
                    .foregroundColor(palette.secondary)
            }
            .padding(20)
        }
        .background(palette.background.ignoresSafeArea())
    }

    private func toggleRow(_ title: String, binding: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(palette.ink)
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var accessText: String {
        switch eventService.accessState {
        case .granted: return "已接入 EventKit，日程来自系统日历。"
        case .denied: return "未授权读取系统日历。"
        case .notDetermined: return "尚未请求日历权限。"
        }
    }
}
