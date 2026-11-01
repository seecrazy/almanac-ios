import SwiftUI

@main
struct AlmanacApp: App {
    @StateObject private var eventService = EventStoreService()
    @StateObject private var milestoneStore = MilestoneStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .almanacPalette()
                .environmentObject(eventService)
                .environmentObject(milestoneStore)
        }
    }
}
