import Cocoa
import Combine

/// A service that monitors the clipboard for double-copy gestures.
final class ClipboardService {
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var lastCopyTime: Date
    private let doubleCopyGap: TimeInterval
    private var timer: Timer?

    /// A publisher that emits an event when a double-copy is detected.
    let doubleCopyPublisher = PassthroughSubject<Void, Never>()

    /// Initializes the service with a given configuration.
    /// - Parameter config: The application's configuration.
    init(config: AppConfig) {
        self.doubleCopyGap = config.doubleCopyGapSeconds
        self.lastChangeCount = pasteboard.changeCount
        self.lastCopyTime = Date()
    }

    /// Starts monitoring the clipboard.
    func startMonitoring() {
        guard timer == nil else { return }
        timer = .scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.pollClipboard()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    /// Stops monitoring the clipboard.
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func pollClipboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }

        let now = Date()
        if now.timeIntervalSince(lastCopyTime) <= doubleCopyGap {
            doubleCopyPublisher.send()
        }

        lastCopyTime = now
        lastChangeCount = pasteboard.changeCount
    }

    deinit {
        stopMonitoring()
    }
}