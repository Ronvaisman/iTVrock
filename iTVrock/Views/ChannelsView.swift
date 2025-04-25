import SwiftUI

struct ChannelsView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var favoriteManager: FavoriteManager
    
    @State private var selectedCategory: String?
    @State private var showingAddPlaylist = false
    
    private var categories: [String] {
        var cats = Set(playlistManager.channels.map { channel in
            channel.category
        })
        cats.insert("All Channels")
        cats.insert("Favorites")
        return Array(cats).sorted()
    }
    
    private var filteredChannels: [Channel] {
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
            VStack(spacing: 2) {
                ForEach(categories, id: \.self) { category in
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
                Spacer()
            }
            .frame(width: 300)
            .background(Color.secondary.opacity(0.1))
            
            // Channel Grid
            ScrollView {
                if playlistManager.channels.isEmpty {
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
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 20) {
                        ForEach(filteredChannels) { channel in
                            ChannelCell(channel: channel)
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingAddPlaylist) {
            AddPlaylistView()
        }
    }
}

struct ChannelCell: View {
    let channel: Channel
    @Environment(\.isFocused) private var isFocused
    
    var body: some View {
        Button(action: {
            // TODO: Implement channel selection and playback
        }) {
            HStack {
                // Channel Logo
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
                
                Spacer()
            }
            .padding()
            .background(isFocused ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.1))
            .cornerRadius(10)
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .buttonStyle(.plain)
        .focusable()
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