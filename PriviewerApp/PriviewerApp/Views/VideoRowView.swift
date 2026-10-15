import SwiftUI

struct VideoRowView: View {
    let item: VideoItem
    let onSave: () -> Void
    let onDelete: () -> Void

    @ObservedObject private var pinnedStore = PinnedStore.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isCached ? "arrow.down.circle.fill" : "play.circle")
                .font(.title2)
                .foregroundStyle(item.isCached ? .green : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(formatSize(item.size))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let duration = item.duration {
                        Text(formatDuration(duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if pinnedStore.isPinned(item.name) {
                        Label("Saved", systemImage: "pin.fill")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    } else if item.isCached {
                        Text("Cached")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Save / Delete button
            if pinnedStore.isPinned(item.name) {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onSave()
                } label: {
                    Image(systemName: "arrow.down.to.line")
                        .foregroundStyle(.blue)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatSize(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        if gb >= 0.1 { return String(format: "%.2f GB", gb) }
        let mb = Double(bytes) / 1_048_576.0
        return String(format: "%.0f MB", mb)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
