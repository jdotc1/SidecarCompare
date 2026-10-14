import AppKit
import SwiftUI

@main @MainActor
struct SidecarCompareApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        Window("SidecarCompare", id: "workspace") {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--native-acceptance") {
                NativeAcceptanceView()
            } else {
                WorkspaceView()
            }
            #else
            WorkspaceView()
            #endif
        }
        .defaultSize(width: 1180, height: 780)
        .windowResizability(.contentMinSize)
        .commands { SidecarCommands() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
