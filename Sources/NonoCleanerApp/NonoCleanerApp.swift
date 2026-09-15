import SwiftUI

@main
struct NonoCleanerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1120, height: 720)

        Settings {
            Text("請在主視窗側邊欄開啟設定。")
                .padding(32)
        }
    }
}
