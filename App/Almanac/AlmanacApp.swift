import SwiftUI

@main
struct AlmanacApp: App {
    @StateObject private var eventService = EventStoreService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .almanacPalette()
                .environmentObject(eventService)
        }
    }
}
