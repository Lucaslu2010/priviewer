import Foundation

final class CacheManager {
    static let shared = CacheManager()
    static let budgetBytes: Int64 = 3 * 1_073_741_824  // 3 GB

    private let cacheDir: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDir = docs.appendingPathComponent("VideoCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func cachedFileURL(for name: String) -> URL {
        cacheDir.appendingPathComponent(name)
    }

    func isCached(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: cachedFileURL(for: name).path)
    }

    func cachedFileNames() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: cacheDir.path)) ?? []
    }

    func cacheSize() -> Int64 {
        var total: Int64 = 0
        let names = cachedFileNames()
        for name in names {
            let url = cachedFileURL(for: name)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }

    func moveDownloadedFile(from tempURL: URL, name: String) throws {
        let dest = cachedFileURL(for: name)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tempURL, to: dest)
    }

    func deleteFile(_ name: String) throws {
        try FileManager.default.removeItem(at: cachedFileURL(for: name))
    }

    func clearAll() throws {
        for name in cachedFileNames() {
            try? deleteFile(name)
        }
    }

    func stampCacheStatus(onto items: inout [VideoItem]) {
        for i in items.indices {
            items[i].isCached = isCached(items[i].name)
        }
    }
}
