import SwiftUI

struct SettingsView: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService

    @AppStorage("showLunar") private var showLunar = true
    @AppStorage("showSolarTerms") private var showSolarTerms = true
    @AppStorage("showHuangLi") private var showHuangLi = false

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

                Text("黄历默认关闭，v1.1 提供完整面板。当前版本设置不参与同步。")
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
