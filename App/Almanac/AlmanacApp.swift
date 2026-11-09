import SwiftUI
import UIKit
import UserNotifications
import HolidayData

@main
struct AlmanacApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var eventService = EventStoreService()
    @StateObject private var milestoneStore = MilestoneStore()
    @StateObject private var alarmStore = WorkdayAlarmStore(holidayStore: .bundledShared)
    @StateObject private var briefingService = DailyBriefingService()
    @StateObject private var router = AppRouter()

    init() {
        UNUserNotificationCenter.current().delegate = AlarmNotificationCenterDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .almanacPalette()
                .environmentObject(eventService)
                .environmentObject(milestoneStore)
                .environmentObject(alarmStore)
                .environmentObject(briefingService)
                .environmentObject(router)
                .task {
                    await milestoneStore.refreshPlatformState()
                    await briefingService.reschedule()
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        Task {
                            await milestoneStore.refreshPlatformState()
                            await alarmStore.reschedule()
                            await briefingService.reschedule()
                            eventService.syncScheduleWidget()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    // 跨天 / 手动改时间 / 时区变化：通知窗口需要整体前移。
                    Task {
                        await milestoneStore.refreshPlatformState()
                        await alarmStore.reschedule()
                        await briefingService.reschedule()
                    }
                }
        }
    }
}
