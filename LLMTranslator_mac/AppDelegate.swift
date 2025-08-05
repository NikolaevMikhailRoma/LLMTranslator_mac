import Cocoa
import SwiftUI
import os.log

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {

    // MARK: UI
    private var statusItem: NSStatusItem!
    private var popover   = NSPopover()
    private var anchorWin: NSWindow?

    // Кто был активен до нас
    private var previousApp: NSRunningApplication?

    // MARK: Clipboard
    private let pb = NSPasteboard.general
    private var lastCnt  = NSPasteboard.general.changeCount
    private var lastTime = Date()
    private let dblGap: TimeInterval = 0.30

    private var timer: Timer?

    func applicationDidFinishLaunching(_: Notification) {
        buildStatusItem()

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self                                   // ← делегат

        timer = .scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.pollClipboard()
        }
        RunLoop.main.add(timer!, forMode: .common)
        os_log("[ClipTranslator] timer running")
    }

    func applicationWillTerminate(_: Notification) { timer?.invalidate() }

    // MARK: Polling logic
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
            let ru = try await Translator.shared.translate(src, from: "en", to: "ru")
            await MainActor.run { showPopover(text: ru) }
        }
    }

    // MARK: Pop-over
    private func showPopover(text: String) {
        os_log("[ClipTranslator] will-show popover")

        // 1) Якорь 1×1 px под курсором
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

        // 3) Показываем якорь
        anchorWin?.orderFront(nil)

        // 4) Готовим SwiftUI-контроллер и подгоняем размер
        let host = NSHostingController(rootView: TranslationBubble(text: text))
        host.view.layoutSubtreeIfNeeded()
        popover.contentViewController = host
        popover.contentSize = host.view.fittingSize

        // 5) Выводим pop-over
        popover.show(
            relativeTo: anchorWin!.contentView!.bounds,
            of:         anchorWin!.contentView!,
            preferredEdge: .maxY
        )

        os_log("[ClipTranslator] did-show popover")
    }

    // MARK: NSPopoverDelegate
    func popoverDidClose(_ notification: Notification) {
        os_log("[ClipTranslator] popover closed")

        // Убираем якорь
        anchorWin?.orderOut(nil)

        // Возвращаем фокус прежнему приложению
        if let app = previousApp, !app.isTerminated {
            app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        }
        previousApp = nil
    }

    // MARK: Status-bar
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

