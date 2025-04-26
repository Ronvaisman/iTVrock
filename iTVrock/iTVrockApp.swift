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
    
    var body: some Scene {
        WindowGroup {
            if profileManager.currentProfile != nil {
                MainTabView()
                    .environmentObject(profileManager)
                    .environmentObject(playlistManager)
                    .environmentObject(favoriteManager)
                    .environmentObject(vodManager)
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
        // Simulate multiple channels
        let channels = (1...3).map { i in
            Channel(
                id: UUID().uuidString,
                name: "Xtream Channel \(i)",
                category: ["Sports", "News", "Kids"][i % 3],
                streamUrl: "https://xtream.example.com/stream\(i).m3u8",
                logoUrl: nil,
                tvgId: nil,
                playlistId: playlist.id
            )
        }
        // Simulate multiple movies
        let movies = (1...2).map { i in
            Movie(
                id: UUID().uuidString,
                title: "Xtream Movie \(i)",
                description: "A simulated Xtream Codes movie #\(i)",
                posterUrl: nil,
                category: ["Action", "Comedy"][i % 2],
                playlistId: playlist.id,
                streamUrl: "https://xtream.example.com/movie\(i).mp4",
                duration: 6000 + Double(i * 300),
                rating: ["PG-13", "R"][i % 2],
                year: 2021 + i,
                addedDate: Date(),
                tmdbId: nil,
                cast: nil,
                director: nil,
                imdbRating: nil
            )
        }
        // Simulate a show
        let shows = [TVShow(
            id: UUID().uuidString,
            title: "Xtream Show",
            description: "A simulated Xtream Codes show",
            posterUrl: nil,
            category: "Drama",
            playlistId: playlist.id,
            rating: "TV-14",
            year: 2022,
            seasons: [TVShow.Season(number: 1, episodes: [
                Episode(
                    id: UUID().uuidString,
                    title: "Pilot",
                    description: "The first episode",
                    seasonNumber: 1,
                    episodeNumber: 1,
                    streamUrl: "https://xtream.example.com/show1e1.mp4",
                    thumbnailUrl: nil,
                    duration: 1800,
                    airDate: Date()
                )
            ])],
            tmdbId: nil
        )]
        self.channels.append(contentsOf: channels)
        vodManager?.updateContent(from: playlist, movies: movies, shows: shows)
    }
}

class FavoriteManager: ObservableObject {
    @Published var favorites: [Favorite] = []
    
    // TODO: Implement favorites management
}
