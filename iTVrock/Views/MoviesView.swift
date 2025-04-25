import SwiftUI

struct MoviesView: View {
    @EnvironmentObject var vodManager: VODManager
    @EnvironmentObject var favoriteManager: FavoriteManager
    
    @State private var selectedCategory: String?
    @State private var searchText = ""
    
    private var categories: [String] {
        var cats = Set(vodManager.movies.map { $0.category })
        cats.insert("All Movies")
        cats.insert("Favorites")
        return Array(cats).sorted()
    }
    
    private var filteredMovies: [Movie] {
        var movies = vodManager.movies
        
        if let category = selectedCategory {
            switch category {
            case "All Movies":
                break // Keep all movies
            case "Favorites":
                let favoriteIds = favoriteManager.favorites
                    .filter { $0.type == .movie }
                    .map { $0.itemId }
                movies = movies.filter { favoriteIds.contains($0.id) }
            default:
                movies = movies.filter { $0.category == category }
            }
        }
        
        if !searchText.isEmpty {
            movies = movies.filter { movie in
                movie.title.localizedCaseInsensitiveContains(searchText) ||
                (movie.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return movies
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
            
            // Movies Grid
            VStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search Movies", text: $searchText)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(10)
                }
                .padding()
                
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
                                MovieCell(movie: movie)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
    }
}

struct MovieCell: View {
    let movie: Movie
    @Environment(\.isFocused) private var isFocused
    
    var body: some View {
        Button(action: {
            // TODO: Implement movie selection and playback
        }) {
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