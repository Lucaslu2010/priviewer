import SwiftUI

struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()
    @StateObject private var syncEngine = SyncEngine.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showDebug = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://192.168.1.x:8765", text: Binding(
                        get: { vm.serverURLString },
                        set: { vm.serverURLString = $0 }
                    ))
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                } header: {
                    Text("Server")
                } footer: {
                    Text("Enter the URL shown when you start server.py on Windows. If using wstunnel, enter the tunnel URL.")
                }

                Section {
                    Toggle("Auto-Sync on Charge + WiFi", isOn: Binding(
                        get: { vm.syncEnabled },
                        set: { vm.syncEnabled = $0 }
                    ))
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Keeps the newest \(budgetLabel) of videos cached locally.")
                }

                Section("Cache") {
                    HStack {
                        Text("Used")
                        Spacer()
                        Text(SettingsViewModel.formatBytes(vm.cacheUsedBytes))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Budget")
                        Spacer()
                        Text("3.00 GB")
                            .foregroundStyle(.secondary)
                    }

                    if syncEngine.isSyncActive {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                let p = syncEngine.progress
                                if p.total > 0 {
                                    Text("Syncing \(p.completed + 1) of \(p.total)")
                                        .font(.subheadline.weight(.medium))
                                } else {
                                    Text("Preparing…")
                                        .font(.subheadline.weight(.medium))
                                }
                                Spacer()
                                if p.bytesTotal > 0 {
                                    Text("\(formatBytes(p.bytesDownloaded)) / \(formatBytes(p.bytesTotal))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if !syncEngine.progress.currentFile.isEmpty {
                                Text(syncEngine.progress.currentFile)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            if syncEngine.progress.total > 0 {
                                ProgressView(value: syncEngine.progress.fraction)
                            }
                        }
                        .padding(.vertical, 4)

                        Button("Stop Sync", role: .destructive) {
                            SyncEngine.shared.cancelSync()
                            vm.refreshCacheSize()
                        }
                    } else {
                        Button {
                            Task {
                                await vm.triggerManualSync()
                                vm.refreshCacheSize()
                            }
                        } label: {
                            Text("Sync Now")
                        }
                        .disabled(vm.serverURL == nil)
                    }

                    Button("Clear Cache", role: .destructive) {
                        vm.clearCache()
                    }
                }

                Section("Developer") {
                    Button("Debug Console") { showDebug = true }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { vm.refreshCacheSize() }
            .sheet(isPresented: $showDebug) { DebugConsoleView() }
        }
    }

    private var budgetLabel: String {
        SettingsViewModel.formatBytes(CacheManager.budgetBytes)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576.0
        if mb < 1 { return "\(bytes / 1024) KB" }
        if mb < 1000 { return String(format: "%.1f MB", mb) }
        return String(format: "%.2f GB", mb / 1024)
    }
}
