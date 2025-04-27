import SwiftUI
import AVFoundation
import TVVLCKit

// VLCPlayerView integrates with TVVLCKit to provide a native VLC player experience
struct VLCPlayerView: UIViewRepresentable {
    let url: URL
    var onPlaybackFailed: ((String) -> Void)? = nil
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .black
        
        // Create VLC media player
        let vlcPlayer = VLCMediaPlayer()
        
        // Print debug info
        print("VLC Player - Creating media with URL: \(url.absoluteString)")
        
        // Create a VLC media object
        let media = VLCMedia(url: url)
        
        // Set media to player
        vlcPlayer.media = media
        
        // Prepare media for playback
        vlcPlayer.drawable = containerView
        
        // Set delegate to handle callbacks
        vlcPlayer.delegate = context.coordinator
        
        // Store player in coordinator
        context.coordinator.player = vlcPlayer
        context.coordinator.onPlaybackFailed = onPlaybackFailed
        
        // Setup a timer to check if playback starts
        context.coordinator.startPlaybackTimer()
        
        // Start playback
        print("VLC Player - Starting playback of: \(url.absoluteString)")
        vlcPlayer.play()
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Handle updates if needed
        context.coordinator.onPlaybackFailed = onPlaybackFailed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, VLCMediaPlayerDelegate {
        var player: VLCMediaPlayer?
        var onPlaybackFailed: ((String) -> Void)?
        private var playbackTimer: Timer?
        private var hasStartedPlaying = false
        
        // VLC Media Player delegate methods
        func mediaPlayerStateChanged(_ aNotification: Notification!) {
            // Handle state changes
            guard let player = aNotification.object as? VLCMediaPlayer else { return }
            
            // Get the current media's URL if available
            let mediaUrl = player.media?.url?.absoluteString ?? "unknown URL"
            
            switch player.state {
            case .playing:
                print("VLC Player: Playing - \(mediaUrl)")
                hasStartedPlaying = true
                playbackTimer?.invalidate()
                playbackTimer = nil
            case .paused:
                print("VLC Player: Paused - \(mediaUrl)")
            case .stopped:
                print("VLC Player: Stopped - \(mediaUrl)")
                if !hasStartedPlaying {
                    notifyPlaybackFailed("Stream stopped before playback could begin")
                }
            case .error:
                print("VLC Player: Error occurred - \(mediaUrl)")
                // Print more detailed error if available
                if let errorMessage = player.media?.userData {
                    print("VLC Player Error: \(errorMessage)")
                }
                notifyPlaybackFailed("VLC Player encountered an error")
            case .buffering:
                print("VLC Player: Buffering - \(mediaUrl)")
            default:
                print("VLC Player: State changed to \(player.state.rawValue) - \(mediaUrl)")
                break
            }
        }
        
        func startPlaybackTimer() {
            // Cancel any existing timer
            playbackTimer?.invalidate()
            hasStartedPlaying = false
            
            // Create a timer to check if playback starts
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                
                // If playback hasn't started after 10 seconds, consider it failed
                if !self.hasStartedPlaying {
                    self.notifyPlaybackFailed("Stream failed to start playback after 10 seconds")
                }
            }
        }
        
        func notifyPlaybackFailed(_ message: String) {
            // Notify the parent view of the failure
            DispatchQueue.main.async {
                self.onPlaybackFailed?(message)
            }
            
            // Clean up timer
            playbackTimer?.invalidate()
            playbackTimer = nil
        }
        
        // Clean up resources
        deinit {
            playbackTimer?.invalidate()
            player?.stop()
            player = nil
        }
    }
}

class VLCPlayerViewController: UIViewController {
    var mediaURL: URL? {
        didSet {
            if let url = mediaURL {
                play(url: url)
            }
        }
    }
    
    var onPlaybackFailed: ((String) -> Void)?
    private var mediaPlayer: VLCMediaPlayer?
    private var playbackTimer: Timer?
    private var hasStartedPlaying = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupPlayer()
    }

    private func setupPlayer() {
        let player = VLCMediaPlayer()
        player.drawable = self.view
        player.delegate = self
        self.mediaPlayer = player
        if let url = mediaURL {
            play(url: url)
        }
    }

    private func play(url: URL) {
        if mediaPlayer == nil {
            setupPlayer()
        }
        mediaPlayer?.media = VLCMedia(url: url)
        
        // Start a timer to check if playback begins
        startPlaybackTimer()
        
        mediaPlayer?.play()
    }
    
    private func startPlaybackTimer() {
        // Cancel any existing timer
        playbackTimer?.invalidate()
        hasStartedPlaying = false
        
        // Create a timer to check if playback starts
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // If playback hasn't started after 10 seconds, consider it failed
            if !self.hasStartedPlaying {
                self.onPlaybackFailed?("Stream failed to start playback after 10 seconds")
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        playbackTimer?.invalidate()
        mediaPlayer?.stop()
    }
}

extension VLCPlayerViewController: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification!) {
        guard let player = aNotification.object as? VLCMediaPlayer else { return }
        
        switch player.state {
        case .playing:
            print("VLC View Controller: Playing")
            hasStartedPlaying = true
            playbackTimer?.invalidate()
            playbackTimer = nil
        case .error:
            print("VLC View Controller: Error")
            onPlaybackFailed?("VLC Player encountered an error")
        case .stopped:
            if !hasStartedPlaying {
                onPlaybackFailed?("Stream stopped before playback could begin")
            }
        default:
            break
        }
    }
} 