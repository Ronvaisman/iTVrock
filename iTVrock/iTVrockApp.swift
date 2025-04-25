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
            if let currentProfile = profileManager.currentProfile {
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
    @Published var movies: [Movie] = []
    @Published var shows: [TVShow] = []
    
    // TODO: Implement playlist management and content loading
}

class FavoriteManager: ObservableObject {
    @Published var favorites: [Favorite] = []
    
    // TODO: Implement favorites management
}
