import AppKit

/// A service to manage application focus.
final class FocusService {
    private var previousApp: NSRunningApplication?

    /// Saves the currently frontmost application.
    func saveCurrentFocus() {
        previousApp = NSWorkspace.shared.frontmostApplication
    }

    /// Activates the previously saved application, restoring focus.
    func restorePreviousFocus() {
        if let app = previousApp, !app.isTerminated {
            app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        }
        previousApp = nil
    }
}