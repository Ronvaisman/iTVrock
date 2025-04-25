import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var favoriteManager: FavoriteManager
    @EnvironmentObject var profileManager: ProfileManager
    
    @State private var selectedContentType: FavoriteType = .channel
    @State private var searchText = ""
    
    private let columns = Array(repeating: GridItem(.adaptive(minimum: 200), spacing: 20), count: 5)
    
    private var filteredFavorites: [Favorite] {
        guard let currentProfile = profileManager.currentProfile else { return [] }
        
        return favoriteManager.favorites
            .filter { favorite in
                favorite.profileId == currentProfile.id &&
                favorite.type == selectedContentType &&
                matchesSearch(favorite)
            }
            .sorted { $0.dateAdded > $1.dateAdded }
    }
    
    private func matchesSearch(_ favorite: Favorite) -> Bool {
        guard !searchText.isEmpty else { return true }
        
        switch favorite.type {
        case .channel:
            if let channel = playlistManager.channels.first(where: { $0.id == favorite.itemId }) {
                return channel.name.localizedCaseInsensitiveContains(searchText)
            }
        case .movie:
            if let movie = playlistManager.movies.first(where: { $0.id == favorite.itemId }) {
                return movie.title.localizedCaseInsensitiveContains(searchText)
            }
        case .show:
            if let show = playlistManager.shows.first(where: { $0.id == favorite.itemId }) {
                return show.title.localizedCaseInsensitiveContains(searchText)
            }
        }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Text("Favorites")
                    .font(.largeTitle)
                
                // Content Type Picker
                Picker("Content Type", selection: $selectedContentType) {
                    Text("Channels").tag(FavoriteType.channel)
                    Text("Movies").tag(FavoriteType.movie)
                    Text("TV Shows").tag(FavoriteType.show)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search Favorites", text: $searchText)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(8)
                }
                .frame(maxWidth: 400)
            }
            .padding()
            
            // Content Grid
            ScrollView {
                if filteredFavorites.isEmpty {
                    EmptyFavoritesView(type: selectedContentType)
                } else {
                    LazyVGrid(columns: columns, spacing: 30) {
                        ForEach(filteredFavorites) { favorite in
                            FavoriteCell(favorite: favorite)
                                .focusable(true)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct FavoriteCell: View {
    let favorite: Favorite
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var favoriteManager: FavoriteManager
    @State private var isFocused = false
    
    var body: some View {
        Button(action: {
            // TODO: Implement content playback/navigation
        }) {
            VStack {
                // Content Poster/Image
                Group {
                    switch favorite.type {
                    case .channel:
                        if let channel = playlistManager.channels.first(where: { $0.id == favorite.itemId }),
                           let logoUrl = channel.logoUrl {
                            AsyncImage(url: URL(string: logoUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                            } placeholder: {
                                Image(systemName: "tv")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Image(systemName: "tv")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        }
                        
                    case .movie:
                        if let movie = playlistManager.movies.first(where: { $0.id == favorite.itemId }),
                           let posterUrl = movie.posterUrl {
                            AsyncImage(url: URL(string: posterUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                            } placeholder: {
                                Image(systemName: "film")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Image(systemName: "film")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        }
                        
                    case .show:
                        if let show = playlistManager.shows.first(where: { $0.id == favorite.itemId }),
                           let posterUrl = show.posterUrl {
                            AsyncImage(url: URL(string: posterUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                            } placeholder: {
                                Image(systemName: "play.tv")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Image(systemName: "play.tv")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 200)
                
                // Content Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(contentTitle)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(contentSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Added \(formatDate(favorite.dateAdded))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .background(isFocused ? Color.secondary.opacity(0.2) : Color.clear)
            .cornerRadius(10)
            .shadow(radius: isFocused ? 5 : 0)
            .overlay(
                Button(action: removeFavorite) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .offset(x: -8, y: 8),
                alignment: .topTrailing
            )
        }
        .buttonStyle(.plain)
        .focusable()
        .onLongPressGesture(minimumDuration: 0.01) {
            withAnimation {
                isFocused = true
            }
        }
    }
    
    private var contentTitle: String {
        switch favorite.type {
        case .channel:
            return playlistManager.channels.first { $0.id == favorite.itemId }?.name ?? "Unknown Channel"
        case .movie:
            return playlistManager.movies.first { $0.id == favorite.itemId }?.title ?? "Unknown Movie"
        case .show:
            return playlistManager.shows.first { $0.id == favorite.itemId }?.title ?? "Unknown Show"
        }
    }
    
    private var contentSubtitle: String {
        switch favorite.type {
        case .channel:
            if let channel = playlistManager.channels.first(where: { $0.id == favorite.itemId }),
               let currentProgram = channel.currentProgram {
                return "Now: \(currentProgram.title)"
            }
            return "Live TV"
        case .movie:
            if let movie = playlistManager.movies.first(where: { $0.id == favorite.itemId }) {
                return movie.year.map { String($0) } ?? "Movie"
            }
            return "Movie"
        case .show:
            if let show = playlistManager.shows.first(where: { $0.id == favorite.itemId }) {
                return "\(show.seasons.count) Season\(show.seasons.count == 1 ? "" : "s")"
            }
            return "TV Show"
        }
    }
    
    private func removeFavorite() {
        withAnimation {
            favoriteManager.favorites.removeAll { $0.id == favorite.id }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "Added " + formatter.string(from: date)
    }
}

struct EmptyFavoritesView: View {
    let type: FavoriteType
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: imageName)
                .font(.system(size: 60))
            Text(message)
                .font(.title)
            Text("Add some \(contentType) to your favorites")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var imageName: String {
        switch type {
        case .channel: return "tv"
        case .movie: return "film"
        case .show: return "play.tv"
        }
    }
    
    private var contentType: String {
        switch type {
        case .channel: return "channels"
        case .movie: return "movies"
        case .show: return "TV shows"
        }
    }
    
    private var message: String {
        "No Favorite \(contentType.capitalized)"
    }
}

// MARK: - Preview
struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        FavoritesView()
            .environmentObject(PlaylistManager())
            .environmentObject(FavoriteManager())
            .environmentObject(ProfileManager())
    }
} 