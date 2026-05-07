import SwiftUI

@main
struct MousePhoneiOSApp: App {
    @StateObject private var model = PhoneControllerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}
