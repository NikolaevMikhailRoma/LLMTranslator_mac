import SwiftUI
import AppKit

@main
struct ClipTranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {                        // без окон; Settings-scene нужна Xcode
        Settings { EmptyView() }
    }
}
