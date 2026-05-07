import SwiftUI

@main
struct MousePhoneMacApp: App {
    @StateObject private var model = MacReceiverModel()

    var body: some Scene {
        MenuBarExtra("MousePhone", systemImage: "iphone.gen2") {
            MousePhoneMenu(model: model)
        }

        WindowGroup("MousePhone", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 460, minHeight: 420)
        }
    }
}

private struct MousePhoneMenu: View {
    @ObservedObject var model: MacReceiverModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open MousePhone") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Text(model.statusText)

        Button("Test Cursor Move") {
            model.testCursorMove()
        }

        Button("Request Accessibility Access") {
            model.requestAccessibilityAccess()
        }

        Button(model.isRunning ? "Stop Receiver" : "Start Receiver") {
            model.toggleReceiver()
        }
    }
}
