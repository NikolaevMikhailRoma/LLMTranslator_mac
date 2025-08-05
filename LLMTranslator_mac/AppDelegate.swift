//
//  AppDelegate.swift
//  LLMTranslator_mac
//
//  Created by admin on 05.08.2025.
//

import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!        // ДОЛЖЕН быть property
    private let pasteboard = NSPasteboard.general
    private var lastChange = NSPasteboard.general.changeCount
    private var lastCopyTime = Date()
    private let doubleInterval: TimeInterval = 0.30
    private var pollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Иконка в меню-баре
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "character.cursor.ibeam",
                                   accessibilityDescription: "Translator")
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu

        // 2. Опрос клипборда
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    private func checkPasteboard() {
        let cnt = pasteboard.changeCount
        guard cnt != lastChange else { return }
        let now = Date()
        if now.timeIntervalSince(lastCopyTime) <= doubleInterval {
            handleDoubleCopy()
        }
        lastCopyTime = now
        lastChange = cnt
    }

    private func handleDoubleCopy() {
        let text = pasteboard.string(forType: .string) ?? ""
        print("⌘C x2 →", text)   // увидите это в Debug-консоли Xcode
        // TODO: отправить текст в LM Studio и показать всплывающее окно
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
