import SwiftUI
import AVKit
import TVVLCKit

struct ChannelPlayerView: View {
    let channel: Channel
    let onClose: () -> Void
    
    @State private var player: AVPlayer? = nil
    @State private var isPlaying: Bool = true
    @State private var showInfo: Bool = false
    @State private var volume: Float = 0.8
    @State private var showControls: Bool = true
    @State private var isLoading: Bool = true
    @State private var isBuffering: Bool = false
    @State private var isPlaybackReady: Bool = false
    @State private var playerObserver: LocalPlayerObserver? = nil
    
    // New states for handling broken streams
    @State private var playbackFailed: Bool = false
    @State private var showRetryPrompt: Bool = false
    @State private var playbackTimer: Timer? = nil
    @State private var timeoutSeconds: Int = 15  // Timeout after 15 seconds
    @State private var currentSecond: Int = 0
    @State private var errorMessage: String = "Stream failed to load"
    @FocusState private var focusedButton: RetryPromptButton?
    
    enum RetryPromptButton: Hashable {
        case retry, cancel
    }
    
    @Environment(\.presentationMode) private var presentationMode
    
    // Inner class to monitor AVPlayer status - to avoid ambiguity with the global one
    class LocalPlayerObserver: NSObject {
        var onBufferingStateChanged: (Bool) -> Void
        var onPlaybackReadyChanged: (Bool) -> Void
        var onPlaybackFailed: (String) -> Void
        
        init(onBufferingStateChanged: @escaping (Bool) -> Void, 
             onPlaybackReadyChanged: @escaping (Bool) -> Void,
             onPlaybackFailed: @escaping (String) -> Void) {
            self.onBufferingStateChanged = onBufferingStateChanged
            self.onPlaybackReadyChanged = onPlaybackReadyChanged
            self.onPlaybackFailed = onPlaybackFailed
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
                        if let error = player.error {
                            self.onPlaybackFailed("Player error: \(error.localizedDescription)")
                        } else {
                            self.onPlaybackFailed("Player failed to load content")
                        }
                    }
                }
            }
        }
    }
    
    private var selectedEngine: PlayerEngine {
        if let saved = UserDefaults.standard.string(forKey: "selectedPlayerEngine"),
           let engine = PlayerEngine(rawValue: saved) {
            return engine
        }
        return .auto
    }
    
    var body: some View {
        ZStack {
            // Black background for full screen
            Color.black.ignoresSafeArea()
            
            // Main content
            VStack(spacing: 0) {
                // Only show header if controls are visible
                if showControls {
                    playerHeader
                }
                
                // Player and controls
                playerContent
                    .edgesIgnoringSafeArea(.all)
            }
            
            // Retry prompt overlay
            if showRetryPrompt {
                retryPromptOverlay
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onTapGesture {
            withAnimation {
                showControls.toggle()
            }
        }
        // Handle back button on remote
        .onExitCommand {
            // Cleanup timer when exiting
            playbackTimer?.invalidate()
            playbackTimer = nil
            onClose()
        }
        .onAppear {
            // Start timeout timer to detect broken streams
            startPlaybackTimeoutTimer()
        }
        .onDisappear {
            // Cleanup timer when view disappears
            playbackTimer?.invalidate()
            playbackTimer = nil
        }
    }
    
    // Function to start the timer that checks if playback started
    private func startPlaybackTimeoutTimer() {
        // Reset timer state
        playbackTimer?.invalidate()
        currentSecond = 0
        playbackFailed = false
        showRetryPrompt = false
        
        // Create a new timer
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if isPlaybackReady {
                // If playback started successfully, invalidate the timer
                playbackTimer?.invalidate()
                playbackTimer = nil
                return
            }
            
            currentSecond += 1
            
            // Check if we've reached the timeout
            if currentSecond >= timeoutSeconds {
                // Timeout reached, show retry prompt
                playbackFailed = true
                showRetryPrompt = true
                errorMessage = "Stream failed to load after \(timeoutSeconds) seconds"
                playbackTimer?.invalidate()
                playbackTimer = nil
            }
        }
    }
    
    // Function to retry playback
    private func retryPlayback() {
        // Reset states
        isLoading = true
        isBuffering = false
        isPlaybackReady = false
        playbackFailed = false
        showRetryPrompt = false
        
        // Clean up previous player
        removeBufferingObserver()
        player?.pause()
        player = nil
        
        // Restart the timeout timer
        startPlaybackTimeoutTimer()
        
        // Re-create the player with the URL
        if let url = getValidStreamUrl(from: channel.streamUrl) {
            player = AVPlayer(url: url)
            player?.volume = volume
            setupBufferingObserver()
            player?.play()
        }
    }
    
    // New overlay for the retry prompt
    private var retryPromptOverlay: some View {
        ZStack {
            // Dark background overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Playback Issue")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(errorMessage)
                    .font(.title3)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 50) {
                    Button(action: retryPlayback) {
                        VStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.largeTitle)
                            Text("Retry")
                                .font(.headline)
                        }
                        .frame(width: 160, height: 120)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .focused($focusedButton, equals: .retry)
                    .scaleEffect(focusedButton == .retry ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: focusedButton)
                    
                    Button(action: onClose) {
                        VStack {
                            Image(systemName: "xmark")
                                .font(.largeTitle)
                            Text("Cancel")
                                .font(.headline)
                        }
                        .frame(width: 160, height: 120)
                        .background(Color.gray.opacity(0.8))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .focused($focusedButton, equals: .cancel)
                    .scaleEffect(focusedButton == .cancel ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: focusedButton)
                }
                
                Text("Press and select to navigate")
                    .font(.callout)
                    .foregroundColor(.gray)
                    .padding(.top, 20)
            }
            .padding(40)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .shadow(radius: 20)
        }
        .onAppear {
            // Set initial focus to retry button
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.focusedButton = .retry
            }
        }
    }
    
    private var playerHeader: some View {
        HStack {
            Text(channel.name)
                .font(.title2)
                .padding()
            Spacer()
        }
        .background(Color.black.opacity(0.7))
        .transition(.move(edge: .top))
    }
    
    private var playerContent: some View {
        ZStack {
            // Player
            Group {
                switch selectedEngine {
                case .apple, .auto:
                    applePlayerView
                case .vlc:
                    vlcPlayerView
                case .ksplayer:
                    Text("KSPlayer integration coming soon.")
                        .foregroundColor(.orange)
                        .padding()
                case .mpv:
                    Text("MPV Player integration coming soon.")
                        .foregroundColor(.orange)
                        .padding()
                case .cancel:
                    Text("No player selected.")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Loading overlay - show until playback is ready or failed
            if (isLoading || isBuffering || !isPlaybackReady) && !playbackFailed {
                loadingOverlay
            }
            
            // Controls overlay
            if showControls && !playbackFailed {
                VStack {
                    Spacer()
                    
                    // Stream info overlay
                    if showInfo {
                        streamInfoOverlay
                    }
                    
                    // Controls bar
                    playerControlsBar
                        .transition(.move(edge: .bottom))
                }
                .transition(.opacity)
            }
        }
    }
    
    // Loading overlay with spinner and text
    private var loadingOverlay: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
                .frame(width: 50, height: 50)
            Text("Loading stream...")
                .font(.headline)
                .padding(.top)
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(10)
    }
    
    // Stream info overlay showing details about the stream
    private var streamInfoOverlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Stream Info")
                .font(.headline)
            
            Group {
                Text("Channel: \(channel.name)")
                Text("Category: \(channel.category)")
                if let tvgId = channel.tvgId {
                    Text("TVG ID: \(tvgId)")
                }
                Text("Stream URL: \(channel.streamUrl)")
            }
            .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.7))
    }
    
    // Player controls bar at the bottom
    private var playerControlsBar: some View {
        HStack(spacing: 20) {
            // Play/Pause
            Button(action: togglePlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
            }
            
            // Volume controls
            Button(action: decreaseVolume) {
                Image(systemName: "speaker.wave.1.fill")
                    .font(.title3)
            }
            
            // Volume indicator
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(width: geometry.size.width, height: 8)
                        .opacity(0.3)
                        .foregroundColor(.gray)
                    
                    Rectangle()
                        .frame(width: geometry.size.width * CGFloat(volume), height: 8)
                        .foregroundColor(.white)
                }
                .cornerRadius(4)
            }
            .frame(width: 100, height: 8)
            
            Button(action: increaseVolume) {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.title3)
            }
            
            Spacer()
            
            // Info button
            Button(action: { showInfo.toggle() }) {
                Image(systemName: "info.circle")
                    .font(.title3)
            }
            
            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark.circle")
                    .font(.title3)
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
    }
    
    // Invalid stream view to show when URL can't be parsed
    private var invalidStreamView: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
                .padding()
            
            Text("Invalid Stream URL")
                .font(.title)
            
            Text(channel.streamUrl)
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding()
                .multilineTextAlignment(.center)
            
            Button(action: onClose) {
                Text("Close")
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(5)
                    .foregroundColor(.white)
            }
            .padding()
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(10)
    }
    
    private func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying {
            player?.play()
        } else {
            player?.pause()
        }
    }
    
    private func stopPlayback() {
        player?.pause()
        player?.seek(to: .zero)
        isPlaying = false
    }
    
    private func increaseVolume() {
        volume = min(1.0, volume + 0.1)
        updateVolume()
    }
    
    private func decreaseVolume() {
        volume = max(0.0, volume - 0.1)
        updateVolume()
    }
    
    private func updateVolume() {
        player?.volume = volume
    }
    
    private var applePlayerView: some View {
        Group {
            // Try to create a valid URL from the stream
            let validUrl = getValidStreamUrl(from: channel.streamUrl)
            
            if let url = validUrl {
                VideoPlayer(player: AVPlayer(url: url))
                    .onAppear {
                        // Reset all status flags
                        isLoading = true
                        isBuffering = false
                        isPlaybackReady = false
                        
                        // Create player
                        player = AVPlayer(url: url)
                        player?.volume = volume
                        
                        // Setup observers before starting playback
                        setupBufferingObserver()
                        
                        // Start playback when ready
                        if isPlaying {
                            player?.play()
                        }
                    }
                    .onDisappear {
                        removeBufferingObserver()
                        player?.pause()
                        player = nil
                    }
            } else {
                invalidStreamView
            }
        }
    }
    
    private func setupBufferingObserver() {
        // Create observer to detect buffering
        playerObserver = LocalPlayerObserver(
            onBufferingStateChanged: { isBuffering in
                self.isBuffering = isBuffering
            },
            onPlaybackReadyChanged: { isReady in
                self.isPlaybackReady = isReady
                if isReady {
                    // When playback is ready, we can hide the loading indicator
                    self.isLoading = false
                }
            },
            onPlaybackFailed: { errorMsg in
                // Handle playback failure
                self.playbackFailed = true
                self.showRetryPrompt = true
                self.errorMessage = errorMsg
                
                // Stop the timer since we've already detected a failure
                self.playbackTimer?.invalidate()
                self.playbackTimer = nil
            }
        )
        
        // Add observer to player
        if let observer = playerObserver, let player = player {
            player.addObserver(
                observer,
                forKeyPath: "timeControlStatus",
                options: [.old, .new],
                context: nil
            )
            
            // Also observe the player status
            player.addObserver(
                observer,
                forKeyPath: "status",
                options: [.old, .new],
                context: nil
            )
        }
    }
    
    private func removeBufferingObserver() {
        // Remove observer when view disappears
        if let observer = playerObserver, let player = player {
            player.removeObserver(observer, forKeyPath: "timeControlStatus")
            player.removeObserver(observer, forKeyPath: "status")
            playerObserver = nil
        }
    }
    
    // Helper function to validate and format stream URLs
    private func getValidStreamUrl(from urlString: String) -> URL? {
        // Log the URL for debugging
        print("Debug - Stream URL attempt: \(urlString)")
        
        // Check if URL is empty
        if urlString.isEmpty {
            print("Error: Stream URL is empty!")
            return nil
        }
        
        // Try to create URL directly
        if let url = URL(string: urlString) {
            print("Debug - Valid URL created: \(url)")
            return url
        } else {
            print("Error: Invalid URL format: \(urlString)")
        }
        
        // Handle common issues with URLs
        var fixedString = urlString
        
        // Fix missing scheme
        if !urlString.starts(with: "http://") && !urlString.starts(with: "https://") {
            fixedString = "http://" + urlString
            print("Debug - Adding http:// scheme: \(fixedString)")
        }
        
        // Try with percent encoding for special characters
        let allowedCharSet = CharacterSet.urlQueryAllowed
        if let encodedString = fixedString.addingPercentEncoding(withAllowedCharacters: allowedCharSet) {
            if let url = URL(string: encodedString) {
                print("Debug - URL created after encoding: \(url)")
                return url
            } else {
                print("Error: Still invalid URL after encoding: \(encodedString)")
            }
        } else {
            print("Error: Failed to percent encode URL: \(fixedString)")
        }
        
        return nil
    }
    
    private var vlcPlayerView: some View {
        Group {
            // Try to create a valid URL from the stream
            let validUrl = getValidStreamUrl(from: channel.streamUrl)
            
            if let url = validUrl {
                ZStack {
                    VLCPlayerView(url: url, onPlaybackFailed: { errorMsg in
                        // Handle VLC playback failure
                        self.playbackFailed = true
                        self.showRetryPrompt = true
                        self.errorMessage = errorMsg
                        
                        // Stop the timer since we've already detected a failure
                        self.playbackTimer?.invalidate()
                        self.playbackTimer = nil
                    })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        // For VLC player, we'll use a timeout approach
                        isLoading = true
                        isPlaybackReady = false
                        
                        // After a reasonable timeout, assume playback has started or failed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            // If not already failed and the retry prompt isn't showing
                            if !playbackFailed && !showRetryPrompt {
                                isLoading = false
                                isPlaybackReady = true
                            }
                        }
                    }
                }
            } else {
                invalidStreamView
            }
        }
    }
} 