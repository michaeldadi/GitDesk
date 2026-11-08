import SwiftUI

@main
struct GitDeskApp: App {
    var body: some Scene {
        WindowGroup("GitDesk") {
            ContentView()
                .frame(minWidth: 980, minHeight: 620)
                .tint(Color(red: 0.08, green: 0.58, blue: 0.49))
        }
        .defaultSize(width: 1280, height: 800)
    }
}
