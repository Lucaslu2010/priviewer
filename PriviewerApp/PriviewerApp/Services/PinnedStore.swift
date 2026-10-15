import Foundation

final class PinnedStore: ObservableObject {
    static let shared = PinnedStore()

    @Published private(set) var pinned: Set<String>

    private init() {
        let arr = UserDefaults.standard.stringArray(forKey: "pinnedVideos") ?? []
        pinned = Set(arr)
    }

    func pin(_ name: String) {
        pinned.insert(name)
        persist()
    }

    func unpin(_ name: String) {
        pinned.remove(name)
        persist()
    }

    func isPinned(_ name: String) -> Bool { pinned.contains(name) }

    private func persist() {
        UserDefaults.standard.set(Array(pinned), forKey: "pinnedVideos")
    }
}
