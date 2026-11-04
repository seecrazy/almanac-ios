import SwiftUI

struct RootView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        TabView {
            CalendarScreen()
                .tabItem { Label("日历", systemImage: "calendar") }
            CountdownView()
                .tabItem { Label("倒计时", systemImage: "hourglass") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .background(palette.background.ignoresSafeArea())
    }
}
