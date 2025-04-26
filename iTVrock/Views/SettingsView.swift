import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var profileManager: ProfileManager
    @State private var selectedSection = SettingsSection.playlists
    
    private enum SettingsSection: String, CaseIterable {
        case playlists = "Playlists"
        case profiles = "Profiles"
        case parentalControls = "Parental Controls"
        case preferences = "Preferences"
        
        var icon: String {
            switch self {
            case .playlists: return "list.bullet"
            case .profiles: return "person.circle"
            case .parentalControls: return "lock.shield"
            case .preferences: return "gear"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 16) {
                ForEach(SettingsSection.allCases, id: \.self) { section in
                    Button(action: { selectedSection = section }) {
                        HStack {
                            Image(systemName: section.icon)
                                .frame(width: 30)
                            Text(section.rawValue)
                                .font(.caption)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(selectedSection == section ? Color.secondary.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .focusable(true)
                }
                Spacer()
            }
            .frame(width: 300)
            .padding(.vertical)
            .background(Color.secondary.opacity(0.1))
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    Text(selectedSection.rawValue)
                        .font(.largeTitle)
                        .padding(.horizontal)
                    
                    switch selectedSection {
                    case .playlists:
                        PlaylistSettingsView()
                    case .profiles:
                        ProfileSettingsView()
                    case .parentalControls:
                        ParentalControlsView()
                    case .preferences:
                        PreferencesView()
                    }
                }
                .padding()
            }
        }
    }
}

struct PlaylistSettingsView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var showingAddPlaylist = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Manage Playlists")
                    .font(.title2)
                
                Spacer()
                
                Button(action: { showingAddPlaylist = true }) {
                    Label("Add Playlist", systemImage: "plus")
                }
            }
            
            if playlistManager.playlists.isEmpty {
                ContentUnavailableView(
                    "No Playlists",
                    systemImage: "list.bullet",
                    description: Text("Add a playlist to start watching content")
                )
            } else {
                ForEach(playlistManager.playlists) { playlist in
                    PlaylistRow(playlist: playlist)
                }
            }
        }
        .sheet(isPresented: $showingAddPlaylist) {
            AddPlaylistView()
        }
    }
}

struct PlaylistRow: View {
    let playlist: Playlist
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Never" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text(playlist.name)
                        .font(.headline)
                    Text(playlist.type.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let lastUpdated = playlist.lastUpdated {
                    Text("Updated: \(formatDate(lastUpdated))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: { isEditing = true }) {
                    Image(systemName: "pencil")
                }
                
                Button(action: { showingDeleteConfirmation = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            if playlist.refreshInterval > 0 {
                Text("Auto-refresh: Every \(Int(playlist.refreshInterval / 3600)) hours")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
        .alert("Delete Playlist", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                withAnimation {
                    playlistManager.playlists.removeAll { $0.id == playlist.id }
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(playlist.name)'? This action cannot be undone.")
        }
        .sheet(isPresented: $isEditing) {
            EditPlaylistView(playlist: playlist)
        }
    }
}

struct ProfileSettingsView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var showingCreateProfile = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Manage Profiles")
                    .font(.title2)
                
                Spacer()
                
                Button(action: { showingCreateProfile = true }) {
                    Label("Add Profile", systemImage: "plus")
                }
            }
            
            ForEach(profileManager.profiles) { profile in
                ProfileRow(profile: profile)
            }
        }
        .sheet(isPresented: $showingCreateProfile) {
            CreateProfileView()
        }
    }
}

struct ProfileRow: View {
    let profile: Profile
    @EnvironmentObject var profileManager: ProfileManager
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(profile.name.prefix(2).uppercased())
                        .foregroundColor(.white)
                        .font(.headline)
                )
            
            VStack(alignment: .leading) {
                Text(profile.name)
                    .font(.headline)
                
                if profile.isParentalControlEnabled {
                    Text("Parental Controls: \(profile.allowedContentRating)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: { isEditing = true }) {
                Image(systemName: "pencil")
            }
            
            if profileManager.profiles.count > 1 {
                Button(action: { showingDeleteConfirmation = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
        .alert("Delete Profile", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                withAnimation {
                    profileManager.profiles.removeAll { $0.id == profile.id }
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(profile.name)'? This action cannot be undone.")
        }
        .sheet(isPresented: $isEditing) {
            EditProfileView(profile: profile)
        }
    }
}

struct ParentalControlsView: View {
    @EnvironmentObject var profileManager: ProfileManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Parental Controls")
                .font(.title2)
            
            if let currentProfile = profileManager.currentProfile {
                Toggle("Enable Parental Controls", isOn: .init(
                    get: { currentProfile.isParentalControlEnabled },
                    set: { newValue in
                        if var profile = profileManager.currentProfile {
                            profile.isParentalControlEnabled = newValue
                            // Update profile in manager
                        }
                    }
                ))
                
                if currentProfile.isParentalControlEnabled {
                    Picker("Content Rating", selection: .init(
                        get: { currentProfile.allowedContentRating },
                        set: { newValue in
                            if var profile = profileManager.currentProfile {
                                profile.allowedContentRating = newValue
                                // Update profile in manager
                            }
                        }
                    )) {
                        Text("G").tag("G")
                        Text("PG").tag("PG")
                        Text("PG-13").tag("PG-13")
                        Text("R").tag("R")
                        Text("NC-17").tag("NC-17")
                    }
                    .pickerStyle(.segmented)
                    
                    SecureField("PIN", text: .init(
                        get: { currentProfile.pin ?? "" },
                        set: { newValue in
                            if var profile = profileManager.currentProfile {
                                profile.pin = newValue.isEmpty ? nil : newValue
                                // Update profile in manager
                            }
                        }
                    ))
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(10)
                    .frame(maxWidth: 200)
                }
            }
        }
    }
}

struct PreferencesView: View {
    @AppStorage("autoPlayNextEpisode") private var autoPlayNextEpisode = true
    @AppStorage("showContentRatings") private var showContentRatings = true
    @AppStorage("enablePictureInPicture") private var enablePictureInPicture = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("App Preferences")
                .font(.title2)
            
            Toggle("Auto-play Next Episode", isOn: $autoPlayNextEpisode)
            Toggle("Show Content Ratings", isOn: $showContentRatings)
            Toggle("Enable Picture in Picture", isOn: $enablePictureInPicture)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("About")
                    .font(.headline)
                Text("iTVrock v1.0")
                    .foregroundColor(.secondary)
                Text("© 2024 iTVrock. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(PlaylistManager())
            .environmentObject(ProfileManager())
    }
} 