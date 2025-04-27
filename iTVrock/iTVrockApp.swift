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
        print("Debug - Added empty playlist - user needs to configure it with credentials")
        
        // No content loading - will happen after user configures playlist
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
        // This method should be updated to parse real content from playlist
        // No sample data generation
        print("Parsing content from playlist: \(playlist.name)")
        
        // In a real implementation, this would extract channels, movies, and shows
        // from the playlist and update the corresponding managers
        
        // Use stubXtreamCodesContent for actual content loading based on the playlist credentials
        if playlist.type == .xtream {
            stubXtreamCodesContent(for: playlist)
        }
        
        // Notify listeners that content has been updated
        onContentUpdated?()
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
        
        // Ensure we have a valid URL
        // We'll allow empty username/password for demo purposes, but handle it properly
        let username = playlist.username ?? ""
        let password = playlist.password ?? ""
        
        // Normalize the base URL to ensure it has a protocol and no trailing slash
        var baseUrl = playlist.url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If URL is empty or just a path component, use a default server address for testing
        if baseUrl.isEmpty || !baseUrl.contains(".") {
            print("Warning: Invalid server URL detected. Using example.com for testing.")
            baseUrl = "http://example.com"
        }
        
        // Add protocol if missing
        if !baseUrl.contains("://") {
            baseUrl = "http://" + baseUrl
        }
        
        // Remove trailing slash if present
        if baseUrl.hasSuffix("/") {
            baseUrl = String(baseUrl.dropLast())
        }
        
        // Debug print
        print("Debug - Normalized base URL: \(baseUrl)")
        
        // Create path components - handle empty credentials to avoid triple slashes
        let authPart: String
        if username.isEmpty && password.isEmpty {
            authPart = ""
        } else {
            authPart = "/\(username)/\(password)"
        }
        
        // Check if we have actual credentials to load content
        if username.isEmpty || password.isEmpty {
            print("Notice: No valid credentials provided. All content lists will remain empty until proper credentials are provided.")
            // Empty content lists
            var channels: [Channel] = []
            var movies: [Movie] = []
            var shows: [TVShow] = []
            
            // Add empty lists to the managers
            self.channels.append(contentsOf: channels)
            vodManager?.updateContent(from: playlist, movies: movies, shows: shows)
            return
        }
        
        // Generate more channels for better testing
        let channelCategories = ["Sports", "News", "Entertainment", "Movies", "Kids", "Music", "Documentary", "Premium"]
        
        var channels: [Channel] = []
        
        // Create channels across different categories
        for (categoryIndex, category) in channelCategories.enumerated() {
            // Create 5-10 channels per category
            let channelCount = 5 + Int.random(in: 0...5)
            
            for i in 1...channelCount {
                let channelNumber = categoryIndex * 100 + i
                let streamUrl = "\(baseUrl)/live\(authPart)/\(channelNumber).ts"
                
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
        
        // No fake movies generation - removed per request
        var movies: [Movie] = []
        
        // Generate TV shows for demo and testing 
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
                            streamUrl: "\(baseUrl)/series\(authPart)/\(i)_\(s)_\(e).mp4",
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
                
                // Debug print first show of each category
                if i == 1 {
                    print("Debug - Created TV show: \(category) \(i) with \(seasonCount) seasons")
                }
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
