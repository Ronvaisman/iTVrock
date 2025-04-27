import Foundation
import AVKit

// Observer class to monitor AVPlayer status
class PlayerObserver: NSObject {
    var onBufferingStateChanged: (Bool) -> Void
    var onPlaybackReadyChanged: (Bool) -> Void
    
    init(onBufferingStateChanged: @escaping (Bool) -> Void, onPlaybackReadyChanged: @escaping (Bool) -> Void) {
        self.onBufferingStateChanged = onBufferingStateChanged
        self.onPlaybackReadyChanged = onPlaybackReadyChanged
        super.init()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "timeControlStatus", let player = object as? AVPlayer {
            DispatchQueue.main.async {
                if player.timeControlStatus == .waitingToPlayAtSpecifiedRate {
                    self.onBufferingStateChanged(true)
                    self.onPlaybackReadyChanged(false)
                } else if player.timeControlStatus == .playing {
                    self.onBufferingStateChanged(false)
                    self.onPlaybackReadyChanged(true)
                } else {
                    self.onBufferingStateChanged(false)
                }
            }
        } else if keyPath == "status", let player = object as? AVPlayer {
            if player.status == .readyToPlay {
                DispatchQueue.main.async {
                    self.onPlaybackReadyChanged(true)
                }
            } else if player.status == .failed {
                DispatchQueue.main.async {
                    self.onPlaybackReadyChanged(false)
                    self.onBufferingStateChanged(false)
                }
            }
        }
    }
} 