import SwiftUI
import AVKit

// MARK: - Models for passing around movie data
private struct IndexedMovie: Identifiable {
    let index: Int
    let movie: Movie
    var id: String { movie.id }
}

struct MoviesView: View {
    @EnvironmentObject var vodManager: VODManager
    @EnvironmentObject var favoriteManager: FavoriteManager
    
    @State private var selectedCategory: String?
    @State private var selectedMovie: Movie? = nil
    @State private var isSidebarVisible: Bool = false
    @State private var focusedMovieIndex: Int? = nil
    
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
            // Main Content
            MovieGridContent(
                filteredMovies: getFilteredMovies(),
                isSidebarVisible: $isSidebarVisible,
                selectedMovie: $selectedMovie,
                focusedMovieIndex: $focusedMovieIndex
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
            // Wrap everything in a VStack to ensure it's a proper View
            VStack {
                // Debug movie URL before passing to channel player
                // These print statements don't return Views and need to be moved outside or handled
                // separately from the View hierarchy
                
                // Create a channel object from movie data
                let channelFromMovie = Channel(
                    id: movie.id,
                    name: movie.title,
                    category: movie.category,
                    streamUrl: movie.streamUrl,
                    logoUrl: movie.posterUrl,
                    tvgId: nil,
                    playlistId: movie.playlistId,
                    order: 0,
                    catchupAvailable: false
                )
                
                ChannelPlayerView(channel: channelFromMovie) {
                    // Debug prints
                    print("Debug - Playing movie with URL: \(movie.streamUrl)")
                    print("Debug - Channel created for movie playback with URL: \(channelFromMovie.streamUrl)")
                    selectedMovie = nil
                }
                .edgesIgnoringSafeArea(.all)
            }
        }
        .onMoveCommand { direction in
            if direction == .down {
                // Focus the first movie when pressing down
                focusedMovieIndex = 0
            }
        }
    }
}

// MARK: - Movie Grid Component
struct MovieGridContent: View {
    let filteredMovies: [Movie]
    @Binding var isSidebarVisible: Bool
    @Binding var selectedMovie: Movie?
    @Binding var focusedMovieIndex: Int?
    
    // Convert the movies into a simpler array for the ForEach
    private var indexedMovies: [IndexedMovie] {
        filteredMovies.enumerated().map { IndexedMovie(index: $0.offset, movie: $0.element) }
    }
    
    // Use FocusState to track which movie is focused
    @FocusState private var focusedMovieId: String?
    
    var body: some View {
        VStack {
            if filteredMovies.isEmpty {
                noMoviesView
            } else {
                moviesGridView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onMoveCommand { direction in
            if !isSidebarVisible && direction == .left {
                withAnimation { isSidebarVisible = true }
            }
        }
        // Sync focusedMovieId with parent's focusedMovieIndex
        .onChange(of: focusedMovieId) { newValue in
            if let newId = newValue, 
               let index = indexedMovies.firstIndex(where: { $0.id == newId }) {
                focusedMovieIndex = index
            }
        }
        .onChange(of: focusedMovieIndex) { newValue in
            if let index = newValue, index < indexedMovies.count {
                focusedMovieId = indexedMovies[index].id
            }
        }
    }
    
    // Break up the view into smaller components
    private var noMoviesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "film")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Movies Found")
                .font(.title)
                .foregroundColor(.white)
            
            Text("Try adjusting your search or category filter")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var moviesGridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 20) {
                // Instead of using Array enumeration inline, use the pre-computed array
                ForEach(indexedMovies) { indexedMovie in
                    createMovieCell(for: indexedMovie)
                }
            }
            .padding()
        }
    }
    
    // Create a movie cell for an indexed movie
    private func createMovieCell(for indexedMovie: IndexedMovie) -> some View {
        let movie = indexedMovie.movie
        let index = indexedMovie.index
        let isFocused = index == focusedMovieIndex
        
        return MovieCell(movie: movie, isFocused: isFocused) {
            print("Selected movie: \(movie.title)")
            selectedMovie = movie
        }
        .id(movie.id)
        .focused($focusedMovieId, equals: movie.id)
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
            sidebarCloseButton
            
            // Category list
            categoriesList
        }
        .frame(width: 300)
        .background(Color(.darkGray))
        .transition(.move(edge: .leading))
        .onMoveCommand { direction in
            if direction == .right {
                withAnimation {
                    isSidebarVisible = false
                }
            }
        }
    }
    
    private var sidebarCloseButton: some View {
        Button(action: { withAnimation { isSidebarVisible = false } }) {
            Image(systemName: "chevron.left")
                .padding()
        }
        .buttonStyle(.plain)
    }
    
    private var categoriesList: some View {
        VStack(spacing: 2) {
            ForEach(categories, id: \.self) { category in
                categoryButton(for: category)
            }
            Spacer()
        }
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

struct MovieCell: View {
    let movie: Movie
    let isFocused: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack {
                posterView
                movieTitle
            }
            .padding(8)
            .background(isFocused ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.1))
            .cornerRadius(10)
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .buttonStyle(CardButtonStyle())
    }
    
    private var posterView: some View {
        Group {
            if let posterUrl = movie.posterUrl {
                AsyncImage(url: URL(string: posterUrl)) { image in
                    image.resizable().aspectRatio(2/3, contentMode: .fit)
                } placeholder: {
                    posterPlaceholder
                }
            } else {
                posterPlaceholder
            }
        }
    }
    
    private var posterPlaceholder: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .aspectRatio(2/3, contentMode: .fit)
            .overlay(
                Image(systemName: "film")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            )
    }
    
    private var movieTitle: some View {
        Text(movie.title)
            .font(.headline)
            .lineLimit(2)
            .multilineTextAlignment(.center)
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