import SwiftUI
import UIKit
import UserNotifications
import HolidayData

@main
struct AlmanacApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var eventService = EventStoreService()
    @StateObject private var milestoneStore = MilestoneStore()
    @StateObject private var alarmStore: WorkdayAlarmStore
    @StateObject private var briefingService = DailyBriefingService()
    @StateObject private var router = AppRouter()
    @StateObject private var holidayData = HolidayDataCoordinator()

    init() {
        UNUserNotificationCenter.current().delegate = AlarmNotificationCenterDelegate.shared
        _alarmStore = StateObject(
            wrappedValue: WorkdayAlarmStore(holidayStore: HolidayDataCoordinator.loadMerged(
                cacheDirectory: HolidayDataCoordinator.defaultCacheDirectory()
            ))
        )
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
                .environmentObject(holidayData)
                .task {
                    await milestoneStore.refreshPlatformState()
                    await briefingService.reschedule()
                    await holidayData.checkForUpdates()
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        Task {
                            await milestoneStore.refreshPlatformState()
                            await alarmStore.reschedule()
                            await briefingService.reschedule()
                            await holidayData.checkForUpdates()
                            eventService.syncScheduleWidget()
                            WatchBriefingWriter.sync(
                                eventService: eventService,
                                milestoneStore: milestoneStore,
                                alarmStore: alarmStore
                            )
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    // 跨天 / 手动改时间 / 时区变化：通知窗口需要整体前移。
                    Task {
                        await milestoneStore.refreshPlatformState()
                        await alarmStore.reschedule()
                        await briefingService.reschedule()
                        await holidayData.checkForUpdates()
                        WatchBriefingWriter.sync(
                            eventService: eventService,
                            milestoneStore: milestoneStore,
                            alarmStore: alarmStore
                        )
                    }
                }
                .onReceive(holidayData.$store) { newStore in
                    // 远程节假日数据生效：闹钟计划与手表快照随之刷新。
                    alarmStore.applyHolidayStore(newStore)
                    WatchBriefingWriter.sync(
                        eventService: eventService,
                        milestoneStore: milestoneStore,
                        alarmStore: alarmStore
                    )
                }
        }
    }
}
