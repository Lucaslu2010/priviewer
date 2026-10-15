import SwiftUI

@main
struct PriviewerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            VideoListView()
        }
    }
}
