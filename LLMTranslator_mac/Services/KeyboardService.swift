import AppKit

/// A service to handle keyboard events, specifically for copying text from the popover.
final class KeyboardService {
    private var keyMonitor: Any?

    /// Starts monitoring for the Command+C key combination.
    ///
    /// If text is selected in the popover, it allows the standard copy action.
    /// Otherwise, it copies the entire provided text to the pasteboard.
    ///
    /// - Parameter popoverText: The full text to be copied if there is no selection.
    func startMonitoring(for popoverText: String) {
        // Ensure any previous monitor is removed before starting a new one.
        stopMonitoring()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Check for Command + C
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "c" {

                // 1. Try standard copy action first (for selected text).
                // If a responder (like NSTextView) handles it, it returns true.
                if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) {
                    return nil // Event handled, consume it.
                }

                // 2. If no selection/responder, copy the entire text.
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(popoverText, forType: .string)
                return nil // Event handled, consume it to prevent the system beep.
            }
            return event // Not our event, pass it on.
        }
    }

    /// Stops monitoring for keyboard events.
    func stopMonitoring() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    deinit {
        stopMonitoring()
    }
}