import Foundation

class VODManager: ObservableObject {
    @Published var movies: [Movie] = []
    @Published var shows: [TVShow] = []
    @Published var watchProgress: [WatchProgress] = []
    
    // MARK: - Content Management
    func updateContent(from playlist: Playlist, movies: [Movie], shows: [TVShow]) {
        // Remove existing content from this playlist
        self.movies.removeAll { $0.playlistId == playlist.id }
        self.shows.removeAll { $0.playlistId == playlist.id }
        
        // Add new content
        self.movies.append(contentsOf: movies)
        self.shows.append(contentsOf: shows)
        
        // Save changes
        saveMovies()
        saveShows()
    }
    
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
        // TODO: Implement persistence using UserDefaults or CloudKit
        print("Saving \(movies.count) movies")
    }
    
    private func saveShows() {
        // TODO: Implement persistence using UserDefaults or CloudKit
        print("Saving \(shows.count) shows")
    }
    
    private func saveWatchProgress() {
        // TODO: Implement persistence using UserDefaults or CloudKit
        print("Saving \(watchProgress.count) watch progress entries")
    }
    
    private func loadContent() {
        // TODO: Load content from persistence
        // For now, just add sample content
        let sampleMovie = Movie(
            id: "movie1",
            title: "Sample Movie",
            description: "A great sample movie",
            posterUrl: nil,
            category: "Action",
            playlistId: UUID(),
            streamUrl: "https://example.com/movie.mp4",
            duration: 7200
        )
        movies = [sampleMovie]
    }
    
    init() {
        loadContent()
    }
} 