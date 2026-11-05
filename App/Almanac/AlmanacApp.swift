import SwiftUI
import UserNotifications

@main
struct AlmanacApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var eventService = EventStoreService()
    @StateObject private var milestoneStore = MilestoneStore()

    init() {
        UNUserNotificationCenter.current().delegate = AlarmNotificationCenterDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .almanacPalette()
                .environmentObject(eventService)
                .environmentObject(milestoneStore)
                .task {
                    await milestoneStore.refreshPlatformState()
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        Task {
                            await milestoneStore.refreshPlatformState()
                        }
                    }
                }
        }
    }
}
