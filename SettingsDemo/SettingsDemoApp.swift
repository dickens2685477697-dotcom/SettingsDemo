import SwiftUI

@main
struct SettingsDemoApp: App {
    @StateObject private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(app)
                .environment(\.locale, Locale(identifier: app.language.rawValue))
                .onOpenURL(perform: app.handleIncomingURL)
        }
    }
}
