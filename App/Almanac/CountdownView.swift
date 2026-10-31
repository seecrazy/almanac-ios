import SwiftUI

struct CountdownView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("重要日子")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundColor(palette.ink)
                    .padding(.horizontal, 20)

                milestoneCard(title: "高考", icon: "🎓",
                              subtitle: "2027年6月7日 · 星期一",
                              days: 219, color: palette.holidayRed)

                Text("里程碑编辑与提醒节奏将在 v1.0 接入")
                    .font(.system(size: 13))
                    .foregroundColor(palette.secondary)
                    .padding(.horizontal, 4)
                Spacer()
            }
            .padding(.top, 8)
        }
        .background(palette.background.ignoresSafeArea())
    }

    private func milestoneCard(title: String, icon: String, subtitle: String, days: Int, color: Color) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(icon) \(title)")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(palette.ink)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(palette.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(days)")
                    .font(.system(size: 44, weight: .semibold, design: .serif))
                    .foregroundColor(color)
                Text("天后")
                    .font(.system(size: 12))
                    .foregroundColor(palette.secondary)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))
        .padding(.horizontal, 20)
    }
}
