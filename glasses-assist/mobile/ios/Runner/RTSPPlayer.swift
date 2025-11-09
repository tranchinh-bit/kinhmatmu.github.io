import Foundation
import MobileVLCKit

class RTSPPlayer: NSObject, VLCMediaPlayerDelegate {
    private let player = VLCMediaPlayer()
    private var channel: FlutterMethodChannel
    private var timer: Timer?
    private var intervalMs: Int = 120   // mặc định ~8.3Hz

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
        player.delegate = self
        player.drawable = UIView(frame: .zero)
    }

    func start(url: String) {
        player.media = VLCMedia(url: URL(string: url)!)
        player.play()
        startTimer()
    }

    func stop() {
        timer?.invalidate(); timer = nil
        player.stop()
    }

    func setInterval(ms: Int) {
        intervalMs = max(60, ms) // clamp tối thiểu 60ms
        if player.isPlaying { startTimer() }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Double(intervalMs)/1000.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let img = self.player.videoSnapshot(as: .png, withWidth: 640, andHeight: 360),
               let data = img.pngData() {
                self.channel.invokeMethod("onFrame", arguments: data)
            }
        }
    }
}
