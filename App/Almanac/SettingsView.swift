import SwiftUI

struct SettingsView: View {
    @Environment(\.palette) private var palette

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
}
