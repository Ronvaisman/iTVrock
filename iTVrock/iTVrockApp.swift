//
//  iTVrockApp.swift
//  iTVrock
//
//  Created by Ron Vaisman on 25/04/2025.
//

import SwiftUI

@main
struct iTVrockApp: App {
    @StateObject private var profileManager = ProfileManager()
    @StateObject private var playlistManager = PlaylistManager()
    @StateObject private var favoriteManager = FavoriteManager()
    @StateObject private var vodManager = VODManager()
    @StateObject private var epgManager = EPGManager()
    
    var body: some Scene {
        WindowGroup {
            if profileManager.currentProfile != nil {
                MainTabView()
                    .environmentObject(profileManager)
                    .environmentObject(playlistManager)
                    .environmentObject(favoriteManager)
                    .environmentObject(vodManager)
                    .environmentObject(epgManager)
            } else {
                ProfileSelectionView()
                    .environmentObject(profileManager)
            }
        }
    }
}

// MARK: - State Management
class ProfileManager: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var currentProfile: Profile?
    
    init() {
        // TODO: Load profiles from CloudKit/local storage
        // For now, create a default profile if none exists
        if profiles.isEmpty {
            let defaultProfile = Profile(name: "Default Profile")
            profiles.append(defaultProfile)
            currentProfile = defaultProfile
        }
    }
}

class PlaylistManager: ObservableObject {
    @Published var playlists: [Playlist] = []
    @Published var channels: [Channel] = []
    
    weak var vodManager: VODManager?
    
    // Empty init without auto-adding default playlist
    init() {
        // Default initialization without adding any playlists
        
        // Add debug print
        print("PlaylistManager initialized. Loading empty playlist...")
        
        // Load playlist functionality, but without test credentials
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.addDefaultXtreamPlaylist()
        }
    }
    
    // Add the default Xtream Codes playlist - now a public method that can be called when needed
    func addDefaultXtreamPlaylist() {
        // Create empty playlist without test credentials
        let defaultPlaylist = Playlist(
            name: "My Playlist",
            type: .xtream,
            url: "",
            username: "",
            password: "",
            refreshInterval: 24,
            isActive: true,
            profileId: UUID()
        )
        
        // Add to playlists array
        self.playlists.append(defaultPlaylist)
        
        // Debug print
        print("Debug - Adding default empty playlist and generating sample content with valid URLs")
        
        // Generate sample content with valid URLs even though playlist is empty
        generateSampleContent(for: defaultPlaylist)
    }
    
    // New method for generating sample content with valid URLs
    func generateSampleContent(for playlist: Playlist) {
        // Generate some sample channels
        let channelCategories = ["Sports", "News", "Entertainment", "Movies", "Kids"]
        
        var sampleChannels: [Channel] = []
        
        // Create sample channels with working URLs
        for (categoryIndex, category) in channelCategories.enumerated() {
            for i in 1...3 {
                let id = "\(categoryIndex)_\(i)"
                // Use a sample streaming URL that works for testing
                let sampleUrl = "https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8"
                
                let channel = Channel(
                    id: id,
                    name: "\(category) Channel \(i)",
                    category: category,
                    streamUrl: sampleUrl,
                    logoUrl: "https://via.placeholder.com/150?text=\(category)\(i)",
                    tvgId: nil,
                    playlistId: playlist.id,
                    order: i,
                    catchupAvailable: false
                )
                sampleChannels.append(channel)
                
                // Print the first channel URL for debugging
                if categoryIndex == 0 && i == 1 {
                    print("Debug - Created sample channel with URL: \(sampleUrl)")
                }
            }
        }
        
        // Generate sample movies
        var sampleMovies: [Movie] = []
        let movieCategories = ["Action", "Comedy", "Drama", "Horror"]
        let movieTitles = [
            "The Last Journey", "Midnight Express", "Stellar Conflict", "Ocean's Depth",
            "The Hidden Truth", "Shadows of the Past", "Eternal Sunshine", "The Dark Knight"
        ]
        
        // Use Big Buck Bunny as a sample movie that should reliably work
        let sampleMovieUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        
        for (i, title) in movieTitles.enumerated() {
            let category = movieCategories[i % movieCategories.count]
            let movie = Movie(
                id: "movie_\(i)",
                title: title,
                description: "A compelling movie with great performances.",
                posterUrl: "https://via.placeholder.com/300x450?text=\(title.replacingOccurrences(of: " ", with: "+"))",
                category: category,
                playlistId: playlist.id,
                streamUrl: sampleMovieUrl,
                duration: Double(5400 + i * 300),
                rating: "PG-13",
                year: 2020 + i,
                addedDate: Date(),
                tmdbId: nil,
                cast: ["Actor 1", "Actor 2"],
                director: "Director",
                imdbRating: 7.5
            )
            sampleMovies.append(movie)
            
            // Print the first movie URL for debugging
            if i == 0 {
                print("Debug - Created sample movie with URL: \(sampleMovieUrl)")
            }
        }
        
        // Add content to managers
        self.channels.append(contentsOf: sampleChannels)
        vodManager?.movies.removeAll { $0.playlistId == playlist.id }
        vodManager?.movies.append(contentsOf: sampleMovies)
        
        print("Debug - Added \(sampleChannels.count) sample channels and \(sampleMovies.count) sample movies with working URLs")
    }
    
    // Load content from an Xtream Codes playlist
    func loadXtreamContent(from playlist: Playlist) {
        // For now, use the stub implementation
        // In a real app, this would make actual API calls to the Xtream service
        stubXtreamCodesContent(for: playlist)
        
        // Notify listeners that content has been updated
        onContentUpdated?()
    }
    
    // Simulated parser: splits playlist into channels, movies, and shows
    func parseAndDistributeContent(from playlist: Playlist) {
        // Simulate multiple channels
        let sampleChannels = (1...5).map { i in
            Channel(
                id: UUID().uuidString,
                name: "Channel \(i)",
                category: ["News", "Sports", "Kids", "Movies", "Music"][i % 5],
                streamUrl: "https://example.com/stream\(i).m3u8",
                logoUrl: nil,
                tvgId: nil,
                playlistId: playlist.id
            )
        }
        // Simulate multiple movies
        let sampleMovies = (1...6).map { i in
            Movie(
                id: UUID().uuidString,
                title: "Movie \(i)",
                description: "A simulated movie #\(i) from playlist",
                posterUrl: nil,
                category: ["Drama", "Action", "Comedy", "Horror", "Sci-Fi", "Documentary"][i % 6],
                playlistId: playlist.id,
                streamUrl: "https://example.com/movie\(i).mp4",
                duration: 5400 + Double(i * 300),
                rating: ["PG", "PG-13", "R", nil][i % 4],
                year: 2020 + i,
                addedDate: Date(),
                tmdbId: nil,
                cast: nil,
                director: nil,
                imdbRating: nil
            )
        }
        // Simulate multiple shows with seasons and episodes
        let sampleShows = (1...3).map { i in
            TVShow(
                id: UUID().uuidString,
                title: "Show \(i)",
                description: "A simulated show #\(i) from playlist",
                posterUrl: nil,
                category: ["Comedy", "Drama", "Kids"][i % 3],
                playlistId: playlist.id,
                rating: ["TV-G", "TV-14", nil][i % 3],
                year: 2018 + i,
                seasons: (1...2).map { seasonNum in
                    TVShow.Season(
                        number: seasonNum,
                        episodes: (1...4).map { epNum in
                            Episode(
                                id: UUID().uuidString,
                                title: "S\(seasonNum)E\(epNum) - Episode Title",
                                description: "Description for episode \(epNum) of season \(seasonNum)",
                                seasonNumber: seasonNum,
                                episodeNumber: epNum,
                                streamUrl: "https://example.com/show\(i)s\(seasonNum)e\(epNum).mp4",
                                thumbnailUrl: nil,
                                duration: 1800 + Double(epNum * 60),
                                airDate: Calendar.current.date(byAdding: .day, value: -epNum, to: Date())
                            )
                        }
                    )
                },
                tmdbId: nil
            )
        }
        // Update channels
        self.channels.append(contentsOf: sampleChannels)
        // Update VODManager
        vodManager?.updateContent(from: playlist, movies: sampleMovies, shows: sampleShows)
    }
    
    // Notify when content is updated
    var onContentUpdated: (() -> Void)?
    
    func updateContent(from playlist: Playlist) {
        // TODO: Parse playlist content
        // For now, just print for debugging
        print("Updating content from playlist: \(playlist.name)")
    }
    
    // Stub: Simulate Xtream Codes API response
    func stubXtreamCodesContent(for playlist: Playlist) {
        // For real implementation, this would fetch actual content from the Xtream API
        
        // Ensure we have non-nil URL, username, and password
        guard let username = playlist.username, let password = playlist.password else {
            print("Error: Missing username or password for Xtream Codes playlist")
            return
        }
        
        let baseUrl = playlist.url
        // Add port 80 to the base URL for proper connection
        let streamBaseUrl = baseUrl + ":80"
        
        // Debug print
        print("Debug - Stream base URL: \(streamBaseUrl)")
        
        // Generate more channels for better testing
        let channelCategories = ["Sports", "News", "Entertainment", "Movies", "Kids", "Music", "Documentary", "Premium"]
        
        var channels: [Channel] = []
        
        // Create channels across different categories
        for (categoryIndex, category) in channelCategories.enumerated() {
            // Create 5-10 channels per category
            let channelCount = 5 + Int.random(in: 0...5)
            
            for i in 1...channelCount {
                let channelNumber = categoryIndex * 100 + i
                let streamUrl = "\(streamBaseUrl)/live/\(username)/\(password)/\(channelNumber).ts"
                
                // Debug print first channel of each category
                if i == 1 {
                    print("Debug - Created channel: \(category) Channel \(i) with URL: \(streamUrl)")
                }
                
                channels.append(Channel(
                    id: UUID().uuidString,
                    name: "\(category) Channel \(i)",
                    category: category,
                    streamUrl: streamUrl,
                    logoUrl: "https://via.placeholder.com/150?text=\(category)\(i)",
                    tvgId: "ch\(channelNumber)",
                    playlistId: playlist.id,
                    order: channelNumber,
                    catchupAvailable: Bool.random()
                ))
            }
        }
        
        // Generate a simple list of movies without category-based organization
        var movies: [Movie] = []
        let movieCount = 50  // Create a reasonable number of movies
        
        // Some sample movie titles
        let movieTitles = [
            "The Last Journey", "Midnight Express", "Stellar Conflict", "Ocean's Depth", 
            "The Hidden Truth", "Shadows of the Past", "Eternal Sunshine", "The Dark Knight",
            "Adventure Time", "Lost in Translation", "The Matrix", "Inception",
            "Interstellar", "The Godfather", "Pulp Fiction", "Fight Club",
            "The Shawshank Redemption", "Forrest Gump", "The Green Mile", "Goodfellas",
            "The Silence of the Lambs", "Se7en", "The Usual Suspects", "The Departed",
            "Gladiator", "Saving Private Ryan", "Braveheart", "Schindler's List"
        ]
        
        // Movie categories
        let categories = ["Action", "Comedy", "Drama", "Horror", "Sci-Fi", "Thriller", "Romance", "Family"]
        
        for i in 0..<movieCount {
            // Use predefined titles if available, or generate one
            let title = i < movieTitles.count ? movieTitles[i] : "Movie \(i + 1)"
            let category = categories[i % categories.count]
            let movieId = UUID().uuidString
            let streamUrl = "\(streamBaseUrl)/movie/\(username)/\(password)/\(movieId).mp4"
            
            // Debug print first movie of each category
            if i < 8 {
                print("Debug - Created movie: \(title) with URL: \(streamUrl)")
            }
            
            movies.append(Movie(
                id: movieId,
                title: title,
                description: "A compelling movie with great performances.",
                posterUrl: "https://via.placeholder.com/300x450?text=\(title.replacingOccurrences(of: " ", with: "+"))",
                category: category,
                playlistId: playlist.id,
                streamUrl: streamUrl,
                duration: Double(5400 + Int.random(in: 0...3600)),
                rating: ["PG", "PG-13", "R", "G"][Int.random(in: 0...3)],
                year: 2010 + Int.random(in: 0...13),
                addedDate: Date(),
                tmdbId: nil,
                cast: ["Actor 1", "Actor 2", "Actor 3"],
                director: "Director Name",
                imdbRating: Double.random(in: 5.0...9.5)
            ))
        }
        
        // Generate TV shows
        let showCategories = ["Drama Series", "Comedy Series", "Reality TV", "Documentary Series"]
        var shows: [TVShow] = []
        
        for category in showCategories {
            // Create 2-4 shows per category
            let showCount = 2 + Int.random(in: 0...2)
            
            for i in 1...showCount {
                let seasonCount = 1 + Int.random(in: 0...3)
                var seasons: [TVShow.Season] = []
                
                for s in 1...seasonCount {
                    let episodeCount = 5 + Int.random(in: 0...10)
                    let episodes = (1...episodeCount).map { e in
                        Episode(
                            id: UUID().uuidString,
                            title: "S\(s)E\(e) - Episode Title",
                            description: "Season \(s) Episode \(e) of this amazing show.",
                            seasonNumber: s,
                            episodeNumber: e,
                            streamUrl: "\(streamBaseUrl)/series/\(username)/\(password)/\(i)_\(s)_\(e).mp4",
                            thumbnailUrl: "https://via.placeholder.com/300x170?text=S\(s)E\(e)",
                            duration: 1800 + Double(e * 60),
                            airDate: Calendar.current.date(byAdding: .day, value: -((s-1) * 100 + e), to: Date())
                        )
                    }
                    
                    seasons.append(TVShow.Season(number: s, episodes: episodes))
                }
                
                shows.append(TVShow(
                    id: UUID().uuidString,
                    title: "\(category) \(i)",
                    description: "A compelling \(category.lowercased()) that audiences love.",
                    posterUrl: "https://via.placeholder.com/300x450?text=\(category)\(i)",
                    category: category,
                    playlistId: playlist.id,
                    rating: ["TV-G", "TV-14", "TV-MA"][Int.random(in: 0...2)],
                    year: 2015 + Int.random(in: 0...8),
                    seasons: seasons,
                    tmdbId: nil
                ))
            }
        }
        
        // Add generated content to the managers
        self.channels.append(contentsOf: channels)
        vodManager?.updateContent(from: playlist, movies: movies, shows: shows)
    }
}

// FavoriteManager class is now defined in Models/Favorites.swift
// class FavoriteManager: ObservableObject {
//     @Published var favorites: [Favorite] = []
//     
//     // TODO: Implement favorites management
// }
