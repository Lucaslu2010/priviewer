import Foundation
import UIKit
import Network

struct SyncProgress {
    var total: Int = 0
    var completed: Int = 0
    var currentFile: String = ""
    var bytesDownloaded: Int64 = 0
    var bytesTotal: Int64 = 0

    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}

final class SyncEngine: NSObject, ObservableObject {
    static let shared = SyncEngine()

    private let network = NetworkService.shared
    private let cache = CacheManager.shared
    private let pinned = PinnedStore.shared

    private let syncQueue = DispatchQueue(label: "com.priviewer.syncengine")
    private var isSyncing = false
    private var cancelRequested = false
    private var networkPath: NWPath?
    private var backgroundSession: URLSession!
    private var activeTasks: [Int: String] = [:]

    // Progress published on main thread
    @Published private(set) var progress: SyncProgress = SyncProgress()
    @Published private(set) var isSyncActive: Bool = false

    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.priviewer.sync")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        setupMonitors()
    }

    private func setupMonitors() {
        DispatchQueue.main.async {
            UIDevice.current.isBatteryMonitoringEnabled = true
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateChanged),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            self?.syncQueue.async {
                self?.networkPath = path
                self?.evaluateSyncConditions()
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.priviewer.netmonitor"))
    }

    @objc private func batteryStateChanged() {
        syncQueue.async { self.evaluateSyncConditions() }
    }

    private func evaluateSyncConditions() {
        guard AppSettings.shared.syncEnabled else { return }
        guard !isSyncing else { return }
        DispatchQueue.main.async { [weak self] in
            let state = UIDevice.current.batteryState
            self?.syncQueue.async {
                guard let self else { return }
                let isCharging = state == .charging || state == .full
                let isWifi = self.networkPath?.usesInterfaceType(.wifi) ?? false
                guard isCharging && isWifi else { return }
                Task { await self.performSync() }
            }
        }
    }

    func triggerManualSync() async {
        await performSync()
    }

    func cancelSync() {
        syncQueue.async { self.cancelRequested = true }
        backgroundSession.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
        Task { @MainActor in
            self.isSyncActive = false
            dlog("[Sync] cancelled by user")
        }
    }

    func performSync() async {
        let alreadySyncing: Bool = await withCheckedContinuation { cont in
            syncQueue.async {
                if self.isSyncing { cont.resume(returning: true); return }
                self.isSyncing = true
                self.cancelRequested = false
                cont.resume(returning: false)
            }
        }
        guard !alreadySyncing else { return }
        defer { syncQueue.async { self.isSyncing = false } }

        await MainActor.run {
            self.isSyncActive = true
            self.progress = SyncProgress()
        }
        defer { Task { @MainActor in self.isSyncActive = false } }

        guard let serverURL = AppSettings.shared.serverURL else {
            dlog("[Sync] no server URL configured")
            return
        }

        do {
            dlog("[Sync] fetching manifest…")
            let manifest = try await network.fetchManifest(serverURL: serverURL)
            let pinnedNames = await MainActor.run { pinned.pinned }
            let toKeep = computeKeepSet(from: manifest.videos, pinned: pinnedNames)
            dlog("[Sync] keeping \(toKeep.count) files (budget)")

            // Evict files not in keep set and not pinned
            for name in cache.cachedFileNames() {
                guard !toKeep.contains(name) && !pinnedNames.contains(name) else { continue }
                try? cache.deleteFile(name)
                dlog("[Sync] evicted \(name)")
            }

            // Reconcile in-flight
            let inFlight = await withCheckedContinuation { cont in
                backgroundSession.getAllTasks { tasks in
                    cont.resume(returning: Set(tasks.compactMap { $0.taskDescription }))
                }
            }

            let toDownload = toKeep.filter { !cache.isCached($0) && !inFlight.contains($0) }
            dlog("[Sync] need to download \(toDownload.count) files")

            await MainActor.run {
                self.progress.total = toDownload.count
                self.progress.completed = 0
            }

            // Download sequentially so we can show per-file progress and support cancel
            for name in toDownload {
                let cancelled: Bool = await withCheckedContinuation { cont in
                    syncQueue.async { cont.resume(returning: self.cancelRequested) }
                }
                if cancelled { break }

                await MainActor.run { self.progress.currentFile = name }
                dlog("[Sync] downloading \(name)…")

                do {
                    let url = network.videoStreamURL(serverURL: serverURL, name: name)
                    let (tmpURL, _) = try await URLSession.shared.download(from: url) { [weak self] received, expected, _ in
                        guard let self else { return }
                        Task { @MainActor in
                            self.progress.bytesDownloaded = received
                            self.progress.bytesTotal = expected
                        }
                    }
                    try cache.moveDownloadedFile(from: tmpURL, name: name)
                    dlog("[Sync] ✓ \(name)")
                    await MainActor.run { self.progress.completed += 1 }
                } catch {
                    dlog("[Sync] ✗ \(name): \(error.localizedDescription)")
                }
            }

            dlog("[Sync] done. \(progress.completed)/\(progress.total) downloaded.")
        } catch {
            dlog("[Sync] failed: \(error.localizedDescription)")
        }
    }

    // Pinned videos always kept; budget filled from newest first
    private func computeKeepSet(from videos: [ManifestVideo], pinned: Set<String>) -> Set<String> {
        var budget: Int64 = 0
        var toKeep = Set<String>()

        // Always keep pinned (they don't count toward budget)
        for name in pinned { toKeep.insert(name) }

        for video in videos {
            guard !pinned.contains(video.name) else { continue }
            guard budget + video.size <= CacheManager.budgetBytes else { continue }
            toKeep.insert(video.name)
            budget += video.size
        }
        return toKeep
    }

    // Pin a video: download now if not cached
    func pinAndDownload(_ name: String, serverURL: URL) async {
        PinnedStore.shared.pin(name)
        guard !cache.isCached(name) else { return }
        dlog("[Pin] downloading \(name)…")
        let url = network.videoStreamURL(serverURL: serverURL, name: name)
        do {
            let (tmpURL, _) = try await URLSession.shared.download(from: url)
            try cache.moveDownloadedFile(from: tmpURL, name: name)
            dlog("[Pin] ✓ \(name) saved")
        } catch {
            dlog("[Pin] ✗ \(name): \(error.localizedDescription)")
        }
    }

    func unpinAndDelete(_ name: String) {
        PinnedStore.shared.unpin(name)
        try? cache.deleteFile(name)
        dlog("[Pin] unpinned + deleted \(name)")
    }
}

extension SyncEngine: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let name = downloadTask.taskDescription else { return }
        do {
            try cache.moveDownloadedFile(from: location, name: name)
        } catch {
            dlog("[Sync] move failed for \(name): \(error)")
        }
        syncQueue.async { self.activeTasks.removeValue(forKey: downloadTask.taskIdentifier) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { dlog("[Sync] task error: \(error)") }
        syncQueue.async { self.activeTasks.removeValue(forKey: task.taskIdentifier) }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            AppDelegate.shared?.backgroundCompletionHandler?()
            AppDelegate.shared?.backgroundCompletionHandler = nil
        }
    }
}

// URLSession download with progress callback
private extension URLSession {
    func download(from url: URL, progress: @escaping (Int64, Int64, Double) -> Void) async throws -> (URL, URLResponse) {
        try await withCheckedThrowingContinuation { cont in
            let task = self.downloadTask(with: url) { tmpURL, response, error in
                if let error { cont.resume(throwing: error); return }
                guard let tmpURL, let response else {
                    cont.resume(throwing: URLError(.badServerResponse))
                    return
                }
                cont.resume(returning: (tmpURL, response))
            }
            task.resume()
            // Poll progress
            Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    let received = task.countOfBytesReceived
                    let expected = task.countOfBytesExpectedToReceive
                    let fraction = expected > 0 ? Double(received) / Double(expected) : 0
                    progress(received, expected, fraction)
                    if task.state == .completed { break }
                }
            }
        }
    }
}
