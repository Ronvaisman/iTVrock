import SwiftUI

struct MoviesView: View {
    @EnvironmentObject var vodManager: VODManager
    @EnvironmentObject var favoriteManager: FavoriteManager
    
    @State private var selectedCategory: String?
    @State private var selectedMovie: Movie? = nil
    @State private var isSidebarVisible: Bool = false
    
    private var categories: [String] {
        let movies = vodManager.movies
        let movieCategories: [String] = movies.compactMap { $0.category }
        var cats = Set<String>()
        for cat in movieCategories {
            cats.insert(cat)
        }
        cats.insert("All Movies")
        cats.insert("Favorites")
        return Array(cats).sorted()
    }
    
    private func getFilteredMovies() -> [Movie] {
        var movies = vodManager.movies
        if let category = selectedCategory {
            switch category {
            case "All Movies":
                break // Keep all movies
            case "Favorites":
                let favorites = favoriteManager.favorites.filter { $0.type == .movie }
                let favoriteIds: [String] = favorites.map { $0.itemId }
                movies = movies.filter { favoriteIds.contains($0.id) }
            default:
                movies = movies.filter { $0.category == category }
            }
        }
        return movies
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Sidebar reveal button (only when sidebar is hidden)
            if !isSidebarVisible {
                SidebarRevealButton(isSidebarVisible: $isSidebarVisible)
            }
            
            // Main Content
            MovieGridContent(
                filteredMovies: getFilteredMovies(),
                isSidebarVisible: $isSidebarVisible,
                selectedMovie: $selectedMovie
            )
            
            // Sidebar
            if isSidebarVisible {
                MovieSidebar(
                    categories: categories,
                    selectedCategory: $selectedCategory,
                    isSidebarVisible: $isSidebarVisible
                )
            }
        }
        .sheet(item: $selectedMovie) { movie in
            ChannelPlayerView(channel: Channel(
                id: movie.id,
                name: movie.title,
                category: movie.category,
                streamUrl: movie.streamUrl,
                logoUrl: movie.posterUrl,
                tvgId: nil,
                playlistId: movie.playlistId
            )) {
                selectedMovie = nil
            }
        }
    }
}

// MARK: - Sidebar Button Component
struct SidebarRevealButton: View {
    @Binding var isSidebarVisible: Bool
    
    var body: some View {
        VStack {
            Button(action: { withAnimation { isSidebarVisible = true } }) {
                Image(systemName: "sidebar.left")
                    .padding()
                    .background(Color(.darkGray))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(width: 60)
        .zIndex(2)
    }
}

// MARK: - Movie Grid Component
struct MovieGridContent: View {
    let filteredMovies: [Movie]
    @Binding var isSidebarVisible: Bool
    @Binding var selectedMovie: Movie?
    
    var body: some View {
        VStack {
            if filteredMovies.isEmpty {
                ContentUnavailableView(
                    "No Movies Found",
                    systemImage: "film",
                    description: Text("Try adjusting your search or category filter")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 20) {
                        ForEach(filteredMovies) { movie in
                            MovieCell(movie: movie) {
                                print("Selected movie: \(movie.title)")
                                selectedMovie = movie
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onMoveCommand { direction in
            if !isSidebarVisible && direction == .left {
                withAnimation { isSidebarVisible = true }
            }
        }
    }
}

// MARK: - Sidebar Component
struct MovieSidebar: View {
    let categories: [String]
    @Binding var selectedCategory: String?
    @Binding var isSidebarVisible: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            // Hide sidebar button
            Button(action: { withAnimation { isSidebarVisible = false } }) {
                Image(systemName: "chevron.left")
                    .padding()
            }
            .buttonStyle(.plain)
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
        .background(Color(.darkGray))
        .transition(.move(edge: .leading))
    }
}

struct MovieCell: View {
    let movie: Movie
    let onSelect: () -> Void
    @Environment(\.isFocused) private var isFocused
    
    var body: some View {
        Button(action: onSelect) {
            VStack {
                // Movie Poster
                if let posterUrl = movie.posterUrl {
                    AsyncImage(url: URL(string: posterUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(2/3, contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .aspectRatio(2/3, contentMode: .fit)
                            .overlay(
                                Image(systemName: "film")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                            )
                    }
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .aspectRatio(2/3, contentMode: .fit)
                        .overlay(
                            Image(systemName: "film")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        )
                }
                
                Text(movie.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(8)
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
struct MoviesView_Previews: PreviewProvider {
    static var previews: some View {
        MoviesView()
            .environmentObject(VODManager())
            .environmentObject(FavoriteManager())
    }
} 