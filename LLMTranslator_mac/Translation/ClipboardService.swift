import Cocoa
import Combine

class ClipboardService {
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount = -1
    private var cancellables = Set<AnyCancellable>()
    
    let clipboardPublisher = PassthroughSubject<String, Never>()

    init() {
        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkClipboard()
            }
            .store(in: &cancellables)
    }

    private func checkClipboard() {
        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = pasteboard.changeCount
            if let copiedString = pasteboard.string(forType: .string) {
                clipboardPublisher.send(copiedString)
            }
        }
    }
}
