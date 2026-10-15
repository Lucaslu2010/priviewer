import Foundation

final class NetworkService {
    static let shared = NetworkService()
    private let decoder = JSONDecoder()
    private init() {}

    func fetchVideoList(serverURL: URL) async throws -> [VideoItem] {
        let url = serverURL.appendingPathComponent("videos")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode([VideoItem].self, from: data)
    }

    func fetchManifest(serverURL: URL) async throws -> SyncManifest {
        let url = serverURL.appendingPathComponent("sync/manifest")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode(SyncManifest.self, from: data)
    }

    func videoStreamURL(serverURL: URL, name: String) -> URL {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return serverURL.appendingPathComponent("videos/\(encoded)")
    }
}
