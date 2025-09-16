import Cocoa
import SwiftUI
import os.log

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {

    // MARK: UI
    private var statusItem: NSStatusItem!
    private var popover   = NSPopover()
    private var anchorWin: NSWindow?
    private var keyMonitor: Any?
    private var currentPopoverText: String = ""

    // Who was active before the bubble was shown
    private var previousApp: NSRunningApplication?

    // MARK: Clipboard
    private let pb = NSPasteboard.general
    private var lastCnt  = NSPasteboard.general.changeCount
    private var lastTime = Date()
    private var dblGap: TimeInterval {
        SettingsStore.shared.config.doubleCopyGapSeconds
    }

    private var timer: Timer?
    private var translationService: TranslationService!
    private var languageDetector: LanguageDetector!

    // MARK: App lifecycle
    func applicationDidFinishLaunching(_: Notification) {
        buildStatusItem()

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        let config = SettingsStore.shared.config
        let provider = LMStudioProvider()
        languageDetector = LanguageDetector(config: config)
        translationService = TranslationService(provider: provider, languageDetector: languageDetector)

        timer = .scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.pollClipboard()
        }
        RunLoop.main.add(timer!, forMode: .common)
        os_log("[ClipTranslator] timer running")
    }

    func applicationWillTerminate(_: Notification) { timer?.invalidate() }

    // MARK: Clipboard polling
    private func pollClipboard() {
        let cnt = pb.changeCount
        guard cnt != lastCnt else { return }
        let now = Date()
        if now.timeIntervalSince(lastTime) <= dblGap { handleDoubleCopy() }
        lastTime = now; lastCnt = cnt
    }

    private func handleDoubleCopy() {
        guard let src = pb.string(forType: .string), !src.isEmpty else { return }
        Task {
            let tuple = try await translationService.translate(src)
            let prefix = "\(tuple.source) -> \(tuple.target)\n"
            await MainActor.run { showPopover(text: prefix + tuple.result) }
        }
    }

    // MARK: Pop-over presentation
    private func showPopover(text: String) {
        os_log("[ClipTranslator] will-show popover")
        currentPopoverText = text

        // 1) 1x1 px anchor window under the cursor
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

        // 2) Remember the current front application and activate self
        previousApp = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)

        // 3) Show the anchor
        anchorWin?.orderFront(nil)

        // 4) SwiftUI controller + exact size
        let host = NSHostingController(rootView: TranslationBubble(text: text))
        host.view.layoutSubtreeIfNeeded()
        popover.contentViewController = host
        popover.contentSize = host.view.fittingSize

        // 5) Show the pop-over
        popover.show(
            relativeTo: anchorWin!.contentView!.bounds,
            of:         anchorWin!.contentView!,
            preferredEdge: .maxY
        )

        os_log("[ClipTranslator] did-show popover")

        // Install Cmd+C monitor to copy whole result without mouse selection
        installCopyKeyMonitor()
    }

    // MARK: NSPopoverDelegate
    func popoverWillClose(_ notification: Notification) {
        os_log("[ClipTranslator] popover will close")
        anchorWin?.orderOut(nil)     // Hide the anchor immediately
        restoreFocus()               // Restore focus immediately

        // Remove key monitor to avoid leaking and global interception
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    func popoverDidClose(_ notification: Notification) {
        os_log("[ClipTranslator] popover did close")
        // Everything is already done here (left for possible debugging)
    }

    // Fast focus restoration
    private func restoreFocus() {
        if let app = previousApp, !app.isTerminated {
            app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        }
        previousApp = nil
    }

    // MARK: Status-bar menu
    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "character.cursor.ibeam",
                                accessibilityDescription: "Translator")
            let menu = NSMenu()
            menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
            statusItem.menu = menu
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: Keyboard handling (Cmd+C)
    /// Installs a local keyDown monitor that handles Command+C.
    /// If there is an active text selection inside the popover (NSTextView with non-empty range),
    /// lets the system handle copy of the selection. Otherwise copies the entire translated text.
    private func installCopyKeyMonitor() {
        // Remove previous monitor if any
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor) }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            // Check for Command + C
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "c" {
                // 1) First try standard copy action (works when there is a selection)
                if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) {
                    return nil // handled by responder chain
                }
                // 2) No selection or no responder: copy entire text from the popover
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(self.currentPopoverText, forType: .string)
                return nil // swallow so it doesn't beep
            }
            return event
        }
    }
}
