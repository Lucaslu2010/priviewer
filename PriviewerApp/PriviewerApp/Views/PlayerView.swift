import SwiftUI
import AVKit

struct PlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        dlog("[Player] loading \(url.absoluteString)")
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true
        ])
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        let vc = AVPlayerViewController()
        vc.player = player
        vc.allowsPictureInPicturePlayback = true

        context.coordinator.observe(item: item, player: player)

        player.play()
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        private var itemObservation: NSKeyValueObservation?
        private var errorObservation: NSKeyValueObservation?

        func observe(item: AVPlayerItem, player: AVPlayer) {
            itemObservation = item.observe(\.status, options: [.new]) { item, _ in
                switch item.status {
                case .readyToPlay:
                    dlog("[Player] ready to play")
                case .failed:
                    let desc = item.error?.localizedDescription ?? "unknown"
                    dlog("[Player] FAILED: \(desc)")
                    if let err = item.error as NSError? {
                        dlog("[Player] domain=\(err.domain) code=\(err.code)")
                        if let underlying = err.userInfo[NSUnderlyingErrorKey] as? NSError {
                            dlog("[Player] underlying: \(underlying.localizedDescription)")
                        }
                    }
                default:
                    break
                }
            }
            errorObservation = player.observe(\.error, options: [.new]) { player, _ in
                if let err = player.error {
                    dlog("[Player] player error: \(err.localizedDescription)")
                }
            }
        }
    }
}
