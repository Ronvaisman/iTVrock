import SwiftUI
import AVKit

// MARK: - Helper Models
private struct IndexedChannel: Identifiable {
    let index: Int
    let channel: Channel
    var id: String { channel.id }
}

struct ChannelsView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var favoriteManager: FavoriteManager
    
    @State private var selectedCategory: String?
    @State private var showingAddPlaylist = false
    @State private var selectedChannel: Channel? = nil
    @State private var focusedChannelIndex: Int? = nil
    
    private var categories: [String] {
        var cats = Set(playlistManager.channels.map { channel in
            channel.category
        })
        cats.insert("All Channels")
        cats.insert("Favorites")
        return Array(cats).sorted()
    }
    
    private func getFilteredChannels() -> [Channel] {
        guard let category = selectedCategory else {
            return playlistManager.channels
        }
        
        switch category {
        case "All Channels":
            return playlistManager.channels
        case "Favorites":
            let favoriteIds = favoriteManager.favorites
                .filter { $0.type == .channel }
                .map { $0.itemId }
            return playlistManager.channels.filter { channel in
                favoriteIds.contains(channel.id)
            }
        default:
            return playlistManager.channels.filter { $0.category == category }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Categories Sidebar
            ChannelSidebar(
                categories: categories,
                selectedCategory: $selectedCategory
            )
            
            // Channel Grid
            ChannelGridContent(
                filteredChannels: getFilteredChannels(),
                showingAddPlaylist: $showingAddPlaylist,
                selectedChannel: $selectedChannel,
                focusedChannelIndex: $focusedChannelIndex,
                isEmpty: playlistManager.channels.isEmpty
            )
        }
        .sheet(isPresented: $showingAddPlaylist) {
            AddPlaylistView()
        }
        .sheet(item: $selectedChannel) { channel in
            ChannelPlayerView(channel: channel) {
                selectedChannel = nil
            }
        }
        .onMoveCommand { direction in
            if direction == .down {
                // Focus the first channel when pressing down
                focusedChannelIndex = 0
            }
        }
    }
}

// MARK: - Sidebar Component
struct ChannelSidebar: View {
    let categories: [String]
    @Binding var selectedCategory: String?
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(categories, id: \.self) { category in
                categoryButton(for: category)
            }
            Spacer()
        }
        .frame(width: 300)
        .background(Color.secondary.opacity(0.1))
    }
    
    private func categoryButton(for category: String) -> some View {
        Button(action: { selectedCategory = category }) {
            HStack {
                Text(category)
                    .font(.title3)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(selectedCategory == category ? Color.secondary.opacity(0.2) : Color.clear)
        }
        .buttonStyle(.plain)
        .focusable(true)
    }
}

// MARK: - Channel Grid Component
struct ChannelGridContent: View {
    let filteredChannels: [Channel]
    @Binding var showingAddPlaylist: Bool
    @Binding var selectedChannel: Channel?
    @Binding var focusedChannelIndex: Int?
    let isEmpty: Bool
    
    // Convert the channels into a simpler array for the ForEach
    private var indexedChannels: [IndexedChannel] {
        filteredChannels.enumerated().map { IndexedChannel(index: $0.offset, channel: $0.element) }
    }
    
    // Use FocusState to track which channel is focused
    @FocusState private var focusedChannelId: String?
    
    var body: some View {
        ScrollView {
            if isEmpty {
                emptyStateView
            } else {
                channelGridView
            }
        }
        // Sync focusedChannelId with parent's focusedChannelIndex
        .onChange(of: focusedChannelId) { newValue in
            if let newId = newValue, 
               let index = indexedChannels.firstIndex(where: { $0.id == newId }) {
                focusedChannelIndex = index
            }
        }
        .onChange(of: focusedChannelIndex) { newValue in
            if let index = newValue, index < indexedChannels.count {
                focusedChannelId = indexedChannels[index].id
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tv")
                .font(.system(size: 60))
            Text("No Channels Available")
                .font(.title)
            Text("Add a playlist to start watching")
                .foregroundColor(.secondary)
            Button("Add Playlist") {
                showingAddPlaylist = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var channelGridView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 20) {
            ForEach(indexedChannels) { indexedChannel in
                createChannelCell(for: indexedChannel)
            }
        }
        .padding()
    }
    
    private func createChannelCell(for indexedChannel: IndexedChannel) -> some View {
        let channel = indexedChannel.channel
        let index = indexedChannel.index
        let isFocused = index == focusedChannelIndex
        
        return ChannelCell(channel: channel, isFocused: isFocused) {
            selectedChannel = channel
        }
        .id(channel.id)
        .focused($focusedChannelId, equals: channel.id)
    }
}

struct ChannelCell: View {
    let channel: Channel
    let isFocused: Bool
    let onSelect: () -> Void
    @Environment(\.isFocused) private var isEnvironmentFocused
    
    // Computed property to determine if cell is focused
    private var cellIsFocused: Bool {
        isFocused || isEnvironmentFocused
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                channelLogo
                channelInfo
                Spacer()
            }
            .padding()
            .background(cellIsFocused ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.1))
            .cornerRadius(10)
            .scaleEffect(cellIsFocused ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: cellIsFocused)
        }
        .buttonStyle(.cardButton)
    }
    
    private var channelLogo: some View {
        Group {
            if let logoUrl = channel.logoUrl {
                AsyncImage(url: URL(string: logoUrl)) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    Image(systemName: "tv")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.secondary)
                }
                .frame(width: 60, height: 60)
            } else {
                Image(systemName: "tv")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var channelInfo: some View {
        VStack(alignment: .leading) {
            Text(channel.name)
                .font(.headline)
            
            if let currentProgram = channel.currentProgram {
                Text(currentProgram.title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ProgressView(value: currentProgram.progress)
                    .progressViewStyle(.linear)
            }
        }
    }
}

struct ChannelPlayerView: View {
    let channel: Channel
    let onClose: () -> Void
    @State private var player: AVPlayer? = nil
    @State private var isPlaying: Bool = true
    @State private var showInfo: Bool = false
    @State private var volume: Float = 0.8
    @State private var showControls: Bool = true
    @Environment(\.presentationMode) private var presentationMode
    
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
        }
        .background(Color.black.ignoresSafeArea())
        .onTapGesture {
            withAnimation {
                showControls.toggle()
            }
        }
        // Handle back button on remote
        .onExitCommand {
            onClose()
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
            
            // Controls overlay
            if showControls {
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
    
    private var streamInfoOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Channel: \(channel.name)")
                .font(.headline)
            Text("Category: \(channel.category)")
            if let currentProgram = channel.currentProgram {
                Text("Now playing: \(currentProgram.title)")
                if let description = currentProgram.description {
                    Text(description)
                        .font(.caption)
                }
            }
            Text("Stream URL: \(channel.streamUrl)")
                .font(.caption)
                .lineLimit(1)
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
        .padding()
    }
    
    private var playerControlsBar: some View {
        HStack(spacing: 60) {
            // Play/Pause
            Button(action: togglePlayPause) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 48))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            
            // Stop
            Button(action: stopPlayback) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 48))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            
            // Volume controls - tvOS friendly
            HStack(spacing: 30) {
                Button(action: decreaseVolume) {
                    Image(systemName: "speaker.wave.1.fill")
                        .font(.system(size: 40))
                }
                .buttonStyle(.plain)
                
                Text("\(Int(volume * 100))%")
                    .font(.title2)
                
                Button(action: increaseVolume) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 40))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            // Info button
            Button(action: { showInfo.toggle() }) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 48))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 40)
        .background(Color.black.opacity(0.6))
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
    
    private func updateVolume() {
        player?.volume = volume
    }
    
    private func increaseVolume() {
        volume = min(1.0, volume + 0.1)
        updateVolume()
    }
    
    private func decreaseVolume() {
        volume = max(0.0, volume - 0.1)
        updateVolume()
    }
    
    private var applePlayerView: some View {
        Group {
            // Try to create a valid URL from the stream
            let validUrl = getValidStreamUrl(from: channel.streamUrl)
            
            if let url = validUrl {
                VideoPlayer(player: AVPlayer(url: url))
                    .onAppear {
                        player = AVPlayer(url: url)
                        player?.volume = volume
                        if isPlaying {
                            player?.play()
                        }
                    }
                    .onDisappear {
                        player?.pause()
                        player = nil
                    }
            } else {
                invalidStreamView
            }
        }
    }
    
    private var vlcPlayerView: some View {
        Group {
            // Try to create a valid URL from the stream
            let validUrl = getValidStreamUrl(from: channel.streamUrl)
            
            if let url = validUrl {
                VLCPlayerView(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                invalidStreamView
            }
        }
    }
    
    private var invalidStreamView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Invalid stream URL")
                .font(.title)
                .foregroundColor(.red)
            
            Text("Cannot play: \(channel.streamUrl)")
                .font(.callout)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Check that your playlist contains valid stream URLs and try again.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    // Helper function to validate and format stream URLs
    private func getValidStreamUrl(from urlString: String) -> URL? {
        // Try to create URL directly
        if let url = URL(string: urlString) {
            return url
        }
        
        // Handle common issues with URLs
        var fixedString = urlString
        
        // Fix missing scheme
        if !urlString.starts(with: "http://") && !urlString.starts(with: "https://") {
            fixedString = "http://" + urlString
        }
        
        // Try with percent encoding for special characters
        let allowedCharSet = CharacterSet.urlQueryAllowed
        if let encodedString = fixedString.addingPercentEncoding(withAllowedCharacters: allowedCharSet) {
            return URL(string: encodedString)
        }
        
        return nil
    }
}

// MARK: - Preview
struct ChannelsView_Previews: PreviewProvider {
    static var previews: some View {
        ChannelsView()
            .environmentObject(PlaylistManager())
            .environmentObject(FavoriteManager())
    }
} 