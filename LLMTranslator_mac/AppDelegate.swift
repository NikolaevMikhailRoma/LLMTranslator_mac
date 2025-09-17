import Cocoa
import SwiftUI
import os.log
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: UI
    private var statusItem: NSStatusItem!

    // MARK: Services
    private var translationService: TranslationService!
    private var languageDetector: LanguageDetector!
    private var clipboardService: ClipboardService!
    private var popoverService: PopoverService!
    private var focusService: FocusService!
    private var keyboardService: KeyboardService!
    private var cancellables = Set<AnyCancellable>()

    // MARK: App lifecycle
    func applicationDidFinishLaunching(_: Notification) {
        buildStatusItem()

        // 1. Load config
        let config = SettingsStore.shared.config

        // 2. Initialize services
        let provider = ProviderFactory.createProvider(for: config)
        languageDetector = LanguageDetector(config: config)
        translationService = TranslationService(provider: provider, languageDetector: languageDetector)
        clipboardService = ClipboardService(config: config)
        focusService = FocusService()
        keyboardService = KeyboardService()
        popoverService = PopoverService(config: config, focusService: focusService, keyboardService: keyboardService)

        // 3. Set up event handling
        clipboardService.doubleCopyPublisher
            .sink { [weak self] in
                self?.handleDoubleCopy()
            }
            .store(in: &cancellables)

        // 4. Start services
        clipboardService.startMonitoring()
        os_log("[AppDelegate] Services are running")
    }

    func applicationWillTerminate(_: Notification) {
        clipboardService.stopMonitoring()
    }

    // MARK: Event Handling
    private func handleDoubleCopy() {
        guard let src = NSPasteboard.general.string(forType: .string), !src.isEmpty else { return }
        Task {
            do {
                let tuple = try await translationService.translate(src)
                let prefix = "\(tuple.source) -> \(tuple.target)\n"
                await MainActor.run {
                    popoverService.show(text: prefix + tuple.result)
                }
            } catch {
                os_log("[AppDelegate] Translation failed: %@", type: .error, String(describing: error))
                // Optionally, show an error in the popover
                await MainActor.run {
                    popoverService.show(text: "Translation Error:\n\(String(describing: error))")
                }
            }
        }
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