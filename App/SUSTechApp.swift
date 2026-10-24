import SwiftUI

@main
struct SUSTechApp: App {
    @State private var store = CampusStore()
    @State private var showLogin = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(.campusGreen)
                .onAppear {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--smoke-demo") { store.setMode(.demo) }
                    if ProcessInfo.processInfo.arguments.contains("--smoke-login") { showLogin = true }
                    #endif
                }
                .sheet(isPresented: $showLogin) { NativeLoginView().environment(store) }
        }
    }
}
