import SwiftUI

struct EditPlaylistView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var playlistManager: PlaylistManager
    
    let playlist: Playlist
    
    @State private var name: String
    @State private var url: String
    @State private var username: String
    @State private var password: String
    @State private var epgUrl: String
    @State private var refreshInterval: TimeInterval
    @State private var isActive: Bool
    
    @State private var isLoading = false
    @State private var error: String?
    
    private let refreshIntervals = [
        (label: "Never", value: TimeInterval(0)),
        (label: "12 Hours", value: TimeInterval(12 * 3600)),
        (label: "24 Hours", value: TimeInterval(24 * 3600)),
        (label: "Weekly", value: TimeInterval(7 * 24 * 3600))
    ]
    
    init(playlist: Playlist) {
        self.playlist = playlist
        _name = State(initialValue: playlist.name)
        _url = State(initialValue: playlist.url)
        _username = State(initialValue: playlist.username ?? "")
        _password = State(initialValue: playlist.password ?? "")
        _epgUrl = State(initialValue: playlist.epgUrl ?? "")
        _refreshInterval = State(initialValue: playlist.refreshInterval)
        _isActive = State(initialValue: playlist.isActive)
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Edit Playlist")
                .font(.largeTitle)
            
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Playlist Name")
                        .font(.headline)
                    TextField("Playlist Name", text: $name)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(10)
                }
                
                if playlist.type == .m3u {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("M3U URL")
                            .font(.headline)
                        TextField("M3U URL", text: $url)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(10)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server URL")
                            .font(.headline)
                        TextField("Server URL", text: $url)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.headline)
                        TextField("Username", text: $username)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                        SecureField("Password", text: $password)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(10)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("EPG URL (Optional)")
                        .font(.headline)
                    TextField("EPG URL", text: $epgUrl)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(10)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto-Refresh Interval")
                        .font(.headline)
                    
                    Picker("Refresh Interval", selection: $refreshInterval) {
                        ForEach(refreshIntervals, id: \.value) { interval in
                            Text(interval.label).tag(interval.value)
                        }
                    }
                }
                
                Toggle("Active", isOn: $isActive)
                    .font(.headline)
            }
            .frame(maxWidth: 400)
            
            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.callout)
            }
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button(action: saveChanges) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Save Changes")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || !isValid)
            }
            
            if !isLoading {
                Button("Test Playlist") {
                    testPlaylist()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(50)
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private var isValid: Bool {
        !name.isEmpty && !url.isEmpty && (playlist.type == .m3u || (!username.isEmpty && !password.isEmpty))
    }
    
    private func saveChanges() {
        guard isValid else { return }
        
        isLoading = true
        error = nil
        
        // Create updated playlist
        var updatedPlaylist = playlist
        updatedPlaylist.name = name
        updatedPlaylist.url = url
        updatedPlaylist.username = username.isEmpty ? nil : username
        updatedPlaylist.password = password.isEmpty ? nil : password
        updatedPlaylist.epgUrl = epgUrl.isEmpty ? nil : epgUrl
        updatedPlaylist.refreshInterval = refreshInterval
        updatedPlaylist.isActive = isActive
        
        // Update in manager
        if let index = playlistManager.playlists.firstIndex(where: { $0.id == playlist.id }) {
            playlistManager.playlists[index] = updatedPlaylist
            
            // Simulate loading
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                isLoading = false
                dismiss()
            }
        } else {
            error = "Failed to update playlist"
            isLoading = false
        }
    }
    
    private func testPlaylist() {
        isLoading = true
        error = nil
        
        // Simulate playlist testing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLoading = false
            // TODO: Implement actual playlist validation
            if url.contains("http") {
                // Success simulation
                withAnimation {
                    error = nil
                }
            } else {
                // Error simulation
                withAnimation {
                    error = "Invalid playlist URL. Please check the URL and try again."
                }
            }
        }
    }
}

// MARK: - Preview
struct EditPlaylistView_Previews: PreviewProvider {
    static var previews: some View {
        EditPlaylistView(playlist: Playlist(
            name: "Test Playlist",
            type: .m3u,
            url: "https://example.com/playlist.m3u",
            refreshInterval: 24 * 3600,
            profileId: UUID()
        ))
        .environmentObject(PlaylistManager())
    }
} 