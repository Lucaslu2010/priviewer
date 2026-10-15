import SwiftUI

struct VideoListView: View {
    @StateObject private var vm = VideoListViewModel()
    @StateObject private var syncEngine = SyncEngine.shared
    @State private var selectedURL: URL?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("Loading videos…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.error {
                    ContentUnavailableView {
                        Label("Cannot Load Videos", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await vm.loadVideos() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if vm.videos.isEmpty {
                    ContentUnavailableView(
                        "No Videos",
                        systemImage: "film.slash",
                        description: Text("No video files found on the server.")
                    )
                } else {
                    List(vm.videos) { item in
                        Button {
                            if let url = vm.playURL(for: item) {
                                selectedURL = url
                            }
                        } label: {
                            VideoRowView(
                                item: item,
                                onSave: {
                                    guard let serverURL = AppSettings.shared.serverURL else { return }
                                    Task { await SyncEngine.shared.pinAndDownload(item.name, serverURL: serverURL) }
                                },
                                onDelete: {
                                    SyncEngine.shared.unpinAndDelete(item.name)
                                    Task { await vm.loadVideos() }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if syncEngine.isSyncActive {
                    SyncProgressBanner(progress: syncEngine.progress)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: syncEngine.isSyncActive)
            .navigationTitle("Priviewer")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .task {
                await vm.loadVideos()
            }
            .refreshable {
                await vm.loadVideos()
            }
            .fullScreenCover(item: $selectedURL) { url in
                PlayerView(url: url)
                    .ignoresSafeArea()
                    .overlay(alignment: .topLeading) {
                        Button {
                            selectedURL = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .symbolRenderingMode(.multicolor)
                                .padding(16)
                        }
                    }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

struct SyncProgressBanner: View {
    let progress: SyncProgress

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 1) {
                    if progress.total > 0 {
                        Text("Syncing \(progress.completed + 1) of \(progress.total)")
                            .font(.caption.weight(.semibold))
                    } else {
                        Text("Preparing sync…")
                            .font(.caption.weight(.semibold))
                    }
                    if !progress.currentFile.isEmpty {
                        Text(progress.currentFile)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if progress.bytesTotal > 0 {
                    Text("\(formatBytes(progress.bytesDownloaded)) / \(formatBytes(progress.bytesTotal))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Button {
                    SyncEngine.shared.cancelSync()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            if progress.total > 0 {
                ProgressView(value: progress.fraction)
                    .progressViewStyle(.linear)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .shadow(radius: 4)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576.0
        if mb < 1 { return "\(bytes / 1024) KB" }
        if mb < 1000 { return String(format: "%.1f MB", mb) }
        return String(format: "%.2f GB", mb / 1024)
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
