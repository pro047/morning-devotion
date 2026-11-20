import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            // Test host: do not load the screen (keeps tests off the network).
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                Text("")
            } else {
                ContentView()
            }
        }
    }
}
