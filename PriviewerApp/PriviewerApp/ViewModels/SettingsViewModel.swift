import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    private let settings = AppSettings.shared
    private let cache = CacheManager.shared

    @Published var cacheUsedBytes: Int64 = 0

    var serverURLString: String {
        get { settings.serverURLString }
        set { settings.serverURLString = newValue }
    }

    var syncEnabled: Bool {
        get { settings.syncEnabled }
        set { settings.syncEnabled = newValue }
    }

    var serverURL: URL? { settings.serverURL }

    func refreshCacheSize() {
        cacheUsedBytes = cache.cacheSize()
    }

    func clearCache() {
        try? cache.clearAll()
        refreshCacheSize()
    }

    func triggerManualSync() async {
        await SyncEngine.shared.triggerManualSync()
        refreshCacheSize()
    }

    static func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        if gb >= 0.1 { return String(format: "%.2f GB", gb) }
        let mb = Double(bytes) / 1_048_576.0
        return String(format: "%.1f MB", mb)
    }
}
