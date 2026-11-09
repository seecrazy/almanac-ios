import CoreSpotlight
import SwiftUI

struct RootView: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            CalendarScreen()
                .tabItem { Label("日历", systemImage: "calendar") }
                .tag(AppRouter.Tab.calendar)
            CountdownView()
                .tabItem { Label("倒计时", systemImage: "hourglass") }
                .tag(AppRouter.Tab.countdown)
            AlarmView()
                .tabItem { Label("闹钟", systemImage: "alarm") }
                .tag(AppRouter.Tab.alarm)
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag(AppRouter.Tab.settings)
        }
        .background(palette.background.ignoresSafeArea())
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
                return
            }
            router.handleSearchableItemActivity(identifier: identifier)
        }
        .onReceive(QuickIntentMailbox.shared.$pendingPhrase) { phrase in
            guard let phrase, !phrase.isEmpty else { return }
            QuickIntentMailbox.shared.pendingPhrase = nil
            router.selectedTab = .calendar
            router.pendingQuickPhrase = phrase
        }
    }
}
