import SwiftUI
import Shared

@main
struct TodoApp: App {
    var body: some Scene {
        MenuBarExtra("Todo", systemImage: "checklist") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}