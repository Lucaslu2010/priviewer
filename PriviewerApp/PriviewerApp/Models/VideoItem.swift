import Foundation

struct VideoItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let size: Int64
    let mtime: Double
    let duration: Double?
    var isCached: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name, size, mtime, duration
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: VideoItem, rhs: VideoItem) -> Bool { lhs.id == rhs.id }
}

struct ManifestVideo: Codable {
    let name: String
    let size: Int64
    let mtime: Double
}

struct SyncManifest: Codable {
    let generated: Double
    let videos: [ManifestVideo]
}
