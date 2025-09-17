import SwiftUI
import os.log

/// A service to manage the translation popover window.
final class PopoverService: NSObject, NSPopoverDelegate {
    // MARK: Properties
    private let popover = NSPopover()
    private var anchorWin: NSWindow?
    private let config: AppConfig

    // MARK: Dependencies
    private let focusService: FocusService
    private let keyboardService: KeyboardService

    // MARK: Lifecycle
    init(config: AppConfig, focusService: FocusService, keyboardService: KeyboardService) {
        self.config = config
        self.focusService = focusService
        self.keyboardService = keyboardService
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    /// Shows the popover with the provided text.
    /// - Parameter text: The text to display in the popover.
    func show(text: String) {
        os_log("[PopoverService] will-show popover")

        let wrappedText = wrapText(text, maxLength: config.maxLineLength)

        // 1. Create a 1x1 anchor window at the mouse position.
        let pt = NSEvent.mouseLocation
        let frame = NSRect(x: pt.x, y: pt.y, width: 1, height: 1)

        if anchorWin == nil {
            anchorWin = NSWindow(
                contentRect: frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            anchorWin?.level = .statusBar
            anchorWin?.isOpaque = false
            anchorWin?.backgroundColor = .clear
            anchorWin?.ignoresMouseEvents = true
            anchorWin?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            anchorWin?.setFrame(frame, display: false)
        }

        // 2. Save focus and activate the app to bring the popover to the front.
        focusService.saveCurrentFocus()
        NSApp.activate(ignoringOtherApps: true)

        // 3. Show the anchor window.
        anchorWin?.orderFront(nil)

        // 4. Set up the SwiftUI view and size the popover.
        let host = NSHostingController(rootView: TranslationBubble(text: wrappedText))
        host.view.layoutSubtreeIfNeeded()
        popover.contentViewController = host
        popover.contentSize = host.view.fittingSize

        // 5. Show the popover.
        popover.show(
            relativeTo: anchorWin!.contentView!.bounds,
            of: anchorWin!.contentView!,
            preferredEdge: .maxY
        )
        os_log("[PopoverService] did-show popover")

        // 6. Start monitoring for Cmd+C.
        keyboardService.startMonitoring(for: wrappedText)
    }

    // MARK: NSPopoverDelegate
    func popoverWillClose(_ notification: Notification) {
        os_log("[PopoverService] popover will close")
        anchorWin?.orderOut(nil)
        focusService.restorePreviousFocus()
        keyboardService.stopMonitoring()
    }

    // MARK: - Private Helpers
    private func wrapText(_ text: String, maxLength: Int?) -> String {
        guard let maxLength = maxLength, maxLength > 0 else {
            return text
        }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var resultLines: [String] = []

        for line in lines {
            if line.count <= maxLength {
                resultLines.append(String(line))
                continue
            }

            var currentLine = ""
            let words = line.split(separator: " ")

            for word in words {
                if currentLine.isEmpty {
                    currentLine = String(word)
                } else if currentLine.count + 1 + word.count <= maxLength {
                    currentLine += " " + String(word)
                } else {
                    resultLines.append(currentLine)
                    currentLine = String(word)
                }
            }
            resultLines.append(currentLine)
        }

        return resultLines.joined(separator: "\n")
    }
}