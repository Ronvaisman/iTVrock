import Foundation

class VODManager: ObservableObject {
    @Published var movies: [Movie] = []
    @Published var shows: [TVShow] = []
    @Published var watchProgress: [WatchProgress] = []
    
    // MARK: - Movie Management
    func addMovie(_ movie: Movie) {
        movies.append(movie)
        saveMovies()
    }
    
    func removeMovie(_ movie: Movie) {
        movies.removeAll { $0.id == movie.id }
        saveMovies()
    }
    
    func updateMovie(_ movie: Movie) {
        if let index = movies.firstIndex(where: { $0.id == movie.id }) {
            movies[index] = movie
            saveMovies()
        }
    }
    
    // MARK: - TV Show Management
    func addShow(_ show: TVShow) {
        shows.append(show)
        saveShows()
    }
    
    func removeShow(_ show: TVShow) {
        shows.removeAll { $0.id == show.id }
        saveShows()
    }
    
    func updateShow(_ show: TVShow) {
        if let index = shows.firstIndex(where: { $0.id == show.id }) {
            shows[index] = show
            saveShows()
        }
    }
    
    // MARK: - Watch Progress
    func updateProgress(contentId: String, profileId: UUID, position: TimeInterval, duration: TimeInterval) {
        let progress = WatchProgress(
            contentId: contentId,
            profileId: profileId,
            position: position,
            duration: duration,
            lastWatched: Date(),
            completed: position >= duration * 0.9
        )
        
        if let index = watchProgress.firstIndex(where: { 
            $0.contentId == contentId && $0.profileId == profileId 
        }) {
            watchProgress[index] = progress
        } else {
            watchProgress.append(progress)
        }
        
        saveWatchProgress()
    }
    
    func getProgress(contentId: String, profileId: UUID) -> WatchProgress? {
        watchProgress.first { 
            $0.contentId == contentId && $0.profileId == profileId 
        }
    }
    
    // MARK: - Persistence
    private func saveMovies() {
        // TODO: Implement persistence
        // For now, just print for debugging
        print("Saving \(movies.count) movies")
    }
    
    private func saveShows() {
        // TODO: Implement persistence
        // For now, just print for debugging
        print("Saving \(shows.count) shows")
    }
    
    private func saveWatchProgress() {
        // TODO: Implement persistence
        // For now, just print for debugging
        print("Saving \(watchProgress.count) watch progress entries")
    }
    
    private func loadContent() {
        // TODO: Implement loading from persistence
        // For now, just add some sample content for testing
        movies = [
            Movie(
                id: "movie1",
                title: "Sample Movie 1",
                description: "A great sample movie",
                posterUrl: nil,
                category: "Action",
                playlistId: UUID(),
                streamUrl: "https://example.com/movie1.mp4",
                duration: 7200
            ),
            Movie(
                id: "movie2",
                title: "Sample Movie 2",
                description: "Another great sample movie",
                posterUrl: nil,
                category: "Drama",
                playlistId: UUID(),
                streamUrl: "https://example.com/movie2.mp4",
                duration: 6300
            )
        ]
    }
    
    init() {
        loadContent()
    }
} 