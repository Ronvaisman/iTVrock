import SwiftUI

struct TVShowsView: View {
    @EnvironmentObject var vodManager: VODManager
    @EnvironmentObject var favoriteManager: FavoriteManager
    
    @State private var selectedCategory: String?
    @State private var searchText = ""
    @State private var selectedShow: TVShow?
    
    private let columns = Array(repeating: GridItem(.adaptive(minimum: 200), spacing: 20), count: 5)
    
    private var categories: [String] {
        var cats = Set(vodManager.shows.map { $0.category })
        cats.insert("All Shows")
        cats.insert("Favorites")
        return Array(cats).sorted()
    }
    
    private var filteredShows: [TVShow] {
        var shows = vodManager.shows
        
        // Apply category filter
        if let category = selectedCategory {
            switch category {
            case "All Shows":
                break // Keep all shows
            case "Favorites":
                let favoriteIds = favoriteManager.favorites
                    .filter { $0.type == .show }
                    .map { $0.itemId }
                shows = shows.filter { favoriteIds.contains($0.id) }
            default:
                shows = shows.filter { $0.category == category }
            }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            shows = shows.filter { show in
                show.title.localizedCaseInsensitiveContains(searchText) ||
                (show.description ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return shows
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Categories Sidebar
            List(categories, id: \.self, selection: $selectedCategory) { category in
                Text(category)
                    .font(.title3)
            }
            .frame(width: 300)
            .listStyle(.plain)
            
            // Shows Grid or Show Detail
            if let show = selectedShow {
                ShowDetailView(show: show, onDismiss: { selectedShow = nil })
            } else {
                VStack {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search TV Shows", text: $searchText)
                            .padding(8)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .padding()
                    
                    ScrollView {
                        if vodManager.shows.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "play.tv")
                                    .font(.system(size: 60))
                                Text("No TV Shows Available")
                                    .font(.title)
                                Text("Add a playlist with VOD content to start watching")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            LazyVGrid(columns: columns, spacing: 30) {
                                ForEach(filteredShows) { show in
                                    ShowCell(show: show) {
                                        selectedShow = show
                                    }
                                    .focusable(true)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
        }
    }
}

struct ShowCell: View {
    let show: TVShow
    let onSelect: () -> Void
    @State private var isFocused = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack {
                // Show Poster
                if let posterUrl = show.posterUrl {
                    AsyncImage(url: URL(string: posterUrl)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .overlay(
                                Image(systemName: "play.tv")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                            )
                    }
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay(
                            Image(systemName: "play.tv")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(show.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if let year = show.year {
                        Text(String(year))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(show.seasons.count) Season\(show.seasons.count == 1 ? "" : "s")")
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
        }
        .buttonStyle(.plain)
        .focusable()
        .onLongPressGesture(minimumDuration: 0.01) {
            withAnimation {
                isFocused = true
            }
        }
    }
}

struct ShowDetailView: View {
    let show: TVShow
    let onDismiss: () -> Void
    @State private var selectedSeason: TVShow.Season?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                    Text("Back to Shows")
                }
                Spacer()
            }
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Show Info
                    HStack(spacing: 20) {
                        if let posterUrl = show.posterUrl {
                            AsyncImage(url: URL(string: posterUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 300)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(width: 300, height: 450)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(show.title)
                                .font(.largeTitle)
                            
                            if let year = show.year {
                                Text("Released: \(year)")
                                    .foregroundColor(.secondary)
                            }
                            
                            if let description = show.description {
                                Text(description)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    
                    // Seasons List
                    ForEach(show.seasons, id: \.number) { season in
                        VStack(alignment: .leading, spacing: 10) {
                            Button(action: {
                                withAnimation {
                                    if selectedSeason?.number == season.number {
                                        selectedSeason = nil
                                    } else {
                                        selectedSeason = season
                                    }
                                }
                            }) {
                                HStack {
                                    Text("Season \(season.number)")
                                        .font(.title2)
                                    Spacer()
                                    Image(systemName: selectedSeason?.number == season.number ? "chevron.down" : "chevron.right")
                                }
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .focusable()
                            
                            if selectedSeason?.number == season.number {
                                VStack(spacing: 10) {
                                    ForEach(season.episodes) { episode in
                                        EpisodeRow(episode: episode)
                                            .focusable(true)
                                    }
                                }
                                .padding(.leading)
                                .transition(.opacity)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}

struct EpisodeRow: View {
    let episode: Episode
    @State private var isFocused = false
    
    var body: some View {
        Button(action: {
            // TODO: Implement episode playback
        }) {
            HStack {
                if let thumbnailUrl = episode.thumbnailUrl {
                    AsyncImage(url: URL(string: thumbnailUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 160, height: 90)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 160, height: 90)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Episode \(episode.episodeNumber): \(episode.title)")
                        .font(.headline)
                    
                    if let description = episode.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Text(episode.duration.formattedDuration)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(isFocused ? Color.secondary.opacity(0.2) : Color.clear)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .focusable()
        .onLongPressGesture(minimumDuration: 0.01) {
            withAnimation {
                isFocused = true
            }
        }
    }
}

// MARK: - Helpers
extension TimeInterval {
    var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) / 60 % 60
        if hours > 0 {
            return String(format: "%d:%02d:00", hours, minutes)
        } else {
            return String(format: "%d:00", minutes)
        }
    }
}

// MARK: - Preview
struct TVShowsView_Previews: PreviewProvider {
    static var previews: some View {
        TVShowsView()
            .environmentObject(VODManager())
            .environmentObject(FavoriteManager())
    }
} 