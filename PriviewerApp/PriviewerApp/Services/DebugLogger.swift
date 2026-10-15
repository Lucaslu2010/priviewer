import Foundation
import Combine

final class DebugLogger: ObservableObject {
    static let shared = DebugLogger()

    @Published private(set) var entries: [Entry] = []
    private let queue = DispatchQueue(label: "com.priviewer.debuglogger")
    private let maxEntries = 500

    struct Entry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String

        var formatted: String {
            let t = DateFormatter.localizedString(from: timestamp, dateStyle: .none, timeStyle: .medium)
            return "[\(t)] \(message)"
        }
    }

    private init() {}

    func log(_ message: String) {
        let entry = Entry(timestamp: Date(), message: message)
        queue.async {
            DispatchQueue.main.async {
                self.entries.append(entry)
                if self.entries.count > self.maxEntries {
                    self.entries.removeFirst(self.entries.count - self.maxEntries)
                }
            }
        }
        // Also print to Xcode console when attached
        print(message)
    }

    func clear() {
        entries.removeAll()
    }
}

func dlog(_ message: String) {
    DebugLogger.shared.log(message)
}
