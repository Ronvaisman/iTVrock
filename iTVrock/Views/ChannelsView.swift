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
    @State private var isSidebarFocused: Bool = true
    
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
                selectedCategory: $selectedCategory,
                isSidebarFocused: $isSidebarFocused
            )
            
            // Channel Grid
            ChannelGridContent(
                filteredChannels: getFilteredChannels(),
                showingAddPlaylist: $showingAddPlaylist,
                selectedChannel: $selectedChannel,
                focusedChannelIndex: $focusedChannelIndex,
                isSidebarFocused: $isSidebarFocused,
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
            switch direction {
            case .left:
                // Move focus to sidebar when pressing left
                isSidebarFocused = true
            case .right:
                // Move focus to channel grid when pressing right
                if isSidebarFocused {
                    isSidebarFocused = false
                    // Only set focused channel if none is focused yet
                    if focusedChannelIndex == nil && !getFilteredChannels().isEmpty {
                        focusedChannelIndex = 0
                    }
                }
            case .down:
                // If in sidebar, move within sidebar, otherwise handle channel grid
                if !isSidebarFocused {
                    // Only focus first channel if none focused yet
                    if focusedChannelIndex == nil && !getFilteredChannels().isEmpty {
                        focusedChannelIndex = 0
                    }
                }
            default:
                break
            }
        }
    }
}

// MARK: - Sidebar Component
struct ChannelSidebar: View {
    let categories: [String]
    @Binding var selectedCategory: String?
    @Binding var isSidebarFocused: Bool
    @FocusState private var focusedCategoryIndex: Int?
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(categories.enumerated()), id: \.element) { index, category in
                categoryButton(for: category, at: index)
            }
            Spacer()
        }
        .frame(width: 300)
        .background(Color.secondary.opacity(0.1))
        .onChange(of: isSidebarFocused) { newValue in
            if newValue && focusedCategoryIndex == nil && !categories.isEmpty {
                focusedCategoryIndex = 0
            }
        }
    }
    
    private func categoryButton(for category: String, at index: Int) -> some View {
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
        .focused($focusedCategoryIndex, equals: index)
        .onChange(of: focusedCategoryIndex) { newValue in
            if newValue == index {
                isSidebarFocused = true
            }
        }
    }
}

// MARK: - Channel Grid Component
struct ChannelGridContent: View {
    let filteredChannels: [Channel]
    @Binding var showingAddPlaylist: Bool
    @Binding var selectedChannel: Channel?
    @Binding var focusedChannelIndex: Int?
    @Binding var isSidebarFocused: Bool
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
                if newId != nil {
                    isSidebarFocused = false
                }
            }
        }
        .onChange(of: focusedChannelIndex) { newValue in
            if let index = newValue, index < indexedChannels.count {
                focusedChannelId = indexedChannels[index].id
            }
        }
        .onMoveCommand { direction in
            switch direction {
            case .left:
                // If user presses left on the first item of a row, move to sidebar
                if focusedChannelIndex == 0 || focusedChannelIndex?.isMultiple(of: 3) == true {
                    isSidebarFocused = true
                    focusedChannelId = nil
                }
            default:
                break
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

// MARK: - Channel Cell Component
struct ChannelCell: View {
    let channel: Channel
    let isFocused: Bool
    let onSelect: () -> Void
    @EnvironmentObject var favoriteManager: FavoriteManager
    @Environment(\.isFocused) private var isEnvironmentFocused
    
    // Computed property to determine if cell is focused
    private var cellIsFocused: Bool {
        isFocused || isEnvironmentFocused
    }
    
    // Check if the channel is a favorite
    private var isFavorite: Bool {
        favoriteManager.favorites.contains(where: { $0.type == .channel && $0.itemId == channel.id })
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading) {
                // Channel thumbnail or logo
                ChannelThumbnail(channel: channel)
                    .frame(height: 180)
                
                // Channel info
                VStack(alignment: .leading, spacing: 5) {
                    Text(channel.name)
                        .font(.headline)
                    
                    HStack {
                        Text(channel.category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Show icon if channel is in favorites
                        if isFavorite {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Current program if available
                    if let currentProgram = channel.currentProgram {
                        Text("Now: \(currentProgram.title)")
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .background(cellIsFocused ? Color.secondary.opacity(0.3) : Color.secondary.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(cellIsFocused ? Color.blue : Color.clear, lineWidth: 4)
            )
            .scaleEffect(cellIsFocused ? 1.05 : 1.0)
        }
        .buttonStyle(CardButtonStyle())
    }
}

// MARK: - Channel Thumbnail Component
struct ChannelThumbnail: View {
    let channel: Channel
    
    var body: some View {
        ZStack {
            // Background color
            Color.black
            
            // If channel has a logo URL, load it
            if let logoUrl = channel.logoUrl, !logoUrl.isEmpty {
                AsyncImage(url: URL(string: logoUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        fallbackImage
                    @unknown default:
                        fallbackImage
                    }
                }
            } else {
                fallbackImage
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
    
    private var fallbackImage: some View {
        VStack {
            Image(systemName: "tv")
                .font(.system(size: 40))
            Text(channel.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 5)
        }
        .foregroundColor(.white)
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