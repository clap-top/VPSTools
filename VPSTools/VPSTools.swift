import SwiftUI

@main
struct VPSTools: App {
    @StateObject private var appLifecycleManager = AppLifecycleManager()
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appLifecycleManager)
                .environmentObject(localizationManager)
        }
    }
}
