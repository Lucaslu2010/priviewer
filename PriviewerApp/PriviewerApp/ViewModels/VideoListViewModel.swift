import Foundation

@MainActor
final class VideoListViewModel: ObservableObject {
    @Published var videos: [VideoItem] = []
    @Published var isLoading = false
    @Published var error: String?

    private let settings = AppSettings.shared
    private let network = NetworkService.shared
    private let cache = CacheManager.shared

    func loadVideos() async {
        guard let serverURL = settings.serverURL else {
            error = "No server URL configured. Tap the gear icon to set one."
            return
        }
        isLoading = true
        error = nil
        do {
            var items = try await network.fetchVideoList(serverURL: serverURL)
            cache.stampCacheStatus(onto: &items)
            videos = items.sorted { $0.mtime > $1.mtime }
        } catch {
            self.error = "Could not reach server: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func playURL(for item: VideoItem) -> URL? {
        if item.isCached {
            return cache.cachedFileURL(for: item.name)
        }
        guard let serverURL = settings.serverURL else { return nil }
        return network.videoStreamURL(serverURL: serverURL, name: item.name)
    }
}
