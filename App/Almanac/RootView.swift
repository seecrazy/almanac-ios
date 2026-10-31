import SwiftUI

struct RootView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        TabView {
            MonthView()
                .tabItem { Label("月历", systemImage: "calendar") }
            CountdownView()
                .tabItem { Label("倒计时", systemImage: "hourglass") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .background(palette.background.ignoresSafeArea())
    }
}
