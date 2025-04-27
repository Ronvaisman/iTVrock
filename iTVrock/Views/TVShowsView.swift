import SwiftUI

// MARK: - Helper Models
private struct IndexedShow: Identifiable {
    let index: Int
    let show: TVShow
    var id: String { show.id }
}

struct TVShowsView: View {
    @EnvironmentObject var vodManager: VODManager
    @EnvironmentObject var favoriteManager: FavoriteManager
    
    @State private var selectedCategory: String?
    @State private var selectedShow: TVShow?
    @State private var isSidebarVisible: Bool = false
    @State private var isSidebarFocused: Bool = true
    @State private var focusedShowIndex: Int? = nil
    
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
        
        return shows
    }
    
    // Convert the shows into a simpler array for the ForEach
    private var indexedShows: [IndexedShow] {
        filteredShows.enumerated().map { IndexedShow(index: $0.offset, show: $0.element) }
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Main Content
            if let show = selectedShow {
                ShowDetailView(show: show, onDismiss: { selectedShow = nil })
            } else {
                // Shows Grid
                TVShowGridContent(
                    filteredShows: filteredShows,
                    selectedShow: $selectedShow,
                    focusedShowIndex: $focusedShowIndex,
                    isSidebarVisible: $isSidebarVisible,
                    isSidebarFocused: $isSidebarFocused
                )
            }
            
            // Sidebar with categories
            if isSidebarVisible && selectedShow == nil {
                TVShowSidebar(
                    categories: categories,
                    selectedCategory: $selectedCategory,
                    isSidebarVisible: $isSidebarVisible,
                    isSidebarFocused: $isSidebarFocused
                )
                .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isSidebarVisible)
        .onMoveCommand { direction in
            // Only handle navigation if not in show detail view
            if selectedShow == nil {
                switch direction {
                case .left:
                    // Show sidebar when pressing left from grid
                    if !isSidebarVisible && !isSidebarFocused {
                        withAnimation { isSidebarVisible = true }
                        isSidebarFocused = true
                    }
                case .right:
                    // Move focus to show grid when pressing right from sidebar
                    if isSidebarFocused {
                        isSidebarFocused = false
                        if focusedShowIndex == nil && !filteredShows.isEmpty {
                            focusedShowIndex = 0
                        }
                    }
                case .down:
                    // If focus is on grid and no show is focused yet, focus the first one
                    if !isSidebarFocused && focusedShowIndex == nil && !filteredShows.isEmpty {
                        focusedShowIndex = 0
                    }
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Sidebar Component
struct TVShowSidebar: View {
    let categories: [String]
    @Binding var selectedCategory: String?
    @Binding var isSidebarVisible: Bool
    @Binding var isSidebarFocused: Bool
    @FocusState private var focusedCategoryIndex: Int?
    
    var body: some View {
        VStack(spacing: 2) {
            // Hide sidebar button
            Button(action: { withAnimation { isSidebarVisible = false } }) {
                Image(systemName: "chevron.left")
                    .padding()
            }
            .buttonStyle(.plain)
            .focusable(true)
            
            // Categories list
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
        .onMoveCommand { direction in
            if direction == .right {
                withAnimation {
                    isSidebarVisible = false
                    isSidebarFocused = false
                }
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

// MARK: - Shows Grid Content
struct TVShowGridContent: View {
    let filteredShows: [TVShow]
    @Binding var selectedShow: TVShow?
    @Binding var focusedShowIndex: Int?
    @Binding var isSidebarVisible: Bool
    @Binding var isSidebarFocused: Bool
    
    // Use FocusState to track which show is focused
    @FocusState private var focusedShowId: String?
    
    private var indexedShows: [IndexedShow] {
        filteredShows.enumerated().map { IndexedShow(index: $0.offset, show: $0.element) }
    }
    
    var body: some View {
        VStack {
            ScrollView {
                if filteredShows.isEmpty {
                    emptyStateView
                } else {
                    showsGridView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Sync focusedShowId with parent's focusedShowIndex
        .onChange(of: focusedShowId) { newValue in
            if let newId = newValue, 
               let index = indexedShows.firstIndex(where: { $0.id == newId }) {
                focusedShowIndex = index
                if newId != nil {
                    isSidebarFocused = false
                }
            }
        }
        .onChange(of: focusedShowIndex) { newValue in
            if let index = newValue, index < indexedShows.count {
                focusedShowId = indexedShows[index].id
            }
        }
        .onMoveCommand { direction in
            switch direction {
            case .left:
                // Show sidebar when pressing left from first column
                if !isSidebarVisible || (focusedShowIndex == 0 || focusedShowIndex?.isMultiple(of: 5) == true) {
                    withAnimation {
                        isSidebarVisible = true
                        isSidebarFocused = true
                    }
                    focusedShowId = nil
                }
            default:
                break
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.tv")
                .font(.system(size: 60))
            Text("No TV Shows Available")
                .font(.title)
            Text("Add a playlist with VOD content to start watching")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var showsGridView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 20)], spacing: 30) {
            ForEach(indexedShows) { indexedShow in
                createShowCell(for: indexedShow)
            }
        }
        .padding()
    }
    
    private func createShowCell(for indexedShow: IndexedShow) -> some View {
        let show = indexedShow.show
        let index = indexedShow.index
        let isFocused = index == focusedShowIndex
        
        return ShowCell(show: show, isFocused: isFocused) {
            selectedShow = show
        }
        .id(show.id)
        .focused($focusedShowId, equals: show.id)
    }
}

// MARK: - Show Cell Component
struct ShowCell: View {
    let show: TVShow
    let isFocused: Bool
    let onSelect: () -> Void
    @EnvironmentObject var favoriteManager: FavoriteManager
    @Environment(\.isFocused) private var isEnvironmentFocused
    
    // Computed property to determine if cell is focused
    private var cellIsFocused: Bool {
        isFocused || isEnvironmentFocused
    }
    
    // Check if the show is a favorite
    private var isFavorite: Bool {
        favoriteManager.favorites.contains(where: { $0.type == .show && $0.itemId == show.id })
    }
    
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
                    
                    HStack {
                        if let year = show.year {
                            Text(String(year))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Show icon if show is in favorites
                        if isFavorite {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Text("\(show.seasons.count) Season\(show.seasons.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
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