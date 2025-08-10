import Cocoa
import SwiftUI
import os.log

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {

    // MARK: UI
    private var statusItem: NSStatusItem!
    private var popover   = NSPopover()
    private var anchorWin: NSWindow?

    // Кто был активным до показа пузыря
    private var previousApp: NSRunningApplication?

    // MARK: Clipboard
    private let pb = NSPasteboard.general
    private var lastCnt  = NSPasteboard.general.changeCount
    private var lastTime = Date()
    private var dblGap: TimeInterval {
        SettingsStore.shared.config.doubleCopyGapSeconds
    }

    private var timer: Timer?

    // MARK: App lifecycle
    func applicationDidFinishLaunching(_: Notification) {
        buildStatusItem()

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

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
            let translated = try await TranslationService.shared.translate(src)
            await MainActor.run { showPopover(text: translated) }
        }
    }

    // MARK: Pop-over presentation
    private func showPopover(text: String) {
        os_log("[ClipTranslator] will-show popover")

        // 1) Якорное окно 1×1 px под курсором
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

        // 2) Запоминаем текущее фронт-приложение и активируем себя
        previousApp = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)

        // 3) Выводим якорь
        anchorWin?.orderFront(nil)

        // 4) SwiftUI-контроллер + точный размер
        let host = NSHostingController(rootView: TranslationBubble(text: text))
        host.view.layoutSubtreeIfNeeded()
        popover.contentViewController = host
        popover.contentSize = host.view.fittingSize

        // 5) Показываем pop-over
        popover.show(
            relativeTo: anchorWin!.contentView!.bounds,
            of:         anchorWin!.contentView!,
            preferredEdge: .maxY
        )

        os_log("[ClipTranslator] did-show popover")
    }

    // MARK: NSPopoverDelegate
    func popoverWillClose(_ notification: Notification) {
        os_log("[ClipTranslator] popover will close")
        anchorWin?.orderOut(nil)     // прячем якорь сразу
        restoreFocus()               // моментально возвращаем фокус
    }

    func popoverDidClose(_ notification: Notification) {
        os_log("[ClipTranslator] popover did close")
        // здесь уже всё сделано (оставляем для возможной отладки)
    }

    // Быстрое восстановление фокуса
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
}

