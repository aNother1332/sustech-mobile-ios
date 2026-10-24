import SwiftUI

@main
struct SUSTechApp: App {
    @State private var store = CampusStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(.campusGreen)
        }
    }
}

