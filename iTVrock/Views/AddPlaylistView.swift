import SwiftUI

struct AddPlaylistView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var profileManager: ProfileManager
    
    @State private var playlistType = PlaylistType.m3u
    @State private var name = ""
    @State private var url = ""
    @State private var username = ""
    @State private var password = ""
    @State private var epgUrl = ""
    @State private var refreshInterval: TimeInterval = 24
    @State private var isLoading = false
    @State private var error: String?
    
    private let refreshIntervals = [
        (label: "Never", value: 0),
        (label: "12 Hours", value: 12),
        (label: "24 Hours", value: 24),
        (label: "Weekly", value: 168)
    ]
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Add Playlist")
                .font(.largeTitle)
            
            Picker("Playlist Type", selection: $playlistType) {
                Text("M3U Playlist").tag(PlaylistType.m3u)
                Text("Xtream Codes").tag(PlaylistType.xtream)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 400)
            
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Playlist Name")
                        .font(.headline)
                    TextField("Enter playlist name", text: $name)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(10)
                }
                
                if playlistType == .m3u {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("M3U URL")
                            .font(.headline)
                        TextField("Enter M3U URL", text: $url)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(10)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server URL")
                            .font(.headline)
                        TextField("Enter server URL", text: $url)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.headline)
                        TextField("Enter username", text: $username)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                        SecureField("Enter password", text: $password)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(10)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("EPG URL (Optional)")
                        .font(.headline)
                    TextField("Enter EPG URL", text: $epgUrl)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(10)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Refresh Interval")
                        .font(.headline)
                    Picker("Refresh Interval", selection: $refreshInterval) {
                        ForEach(refreshIntervals, id: \.value) { interval in
                            Text(interval.label).tag(Double(interval.value))
                        }
                    }
                }
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
                
                Button(action: addPlaylist) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Add Playlist")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || !isValid)
            }
        }
        .padding(50)
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private var isValid: Bool {
        !name.isEmpty && !url.isEmpty && (playlistType == .m3u || (!username.isEmpty && !password.isEmpty))
    }
    
    private func addPlaylist() {
        guard let currentProfile = profileManager.currentProfile else { return }
        
        isLoading = true
        error = nil
        
        let playlist = Playlist(
            name: name,
            type: playlistType,
            url: url,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password,
            epgUrl: epgUrl.isEmpty ? nil : epgUrl,
            refreshInterval: refreshInterval * 3600, // Convert hours to seconds
            profileId: currentProfile.id
        )
        
        // TODO: Implement actual playlist loading and validation
        // For now, just add it to the manager
        playlistManager.playlists.append(playlist)
        
        // Simulate parsing and distributing content
        playlistManager.parseAndDistributeContent(from: playlist)
        
        // Simulate loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
            dismiss()
        }
    }
}

// MARK: - Preview
struct AddPlaylistView_Previews: PreviewProvider {
    static var previews: some View {
        AddPlaylistView()
            .environmentObject(PlaylistManager())
            .environmentObject(ProfileManager())
    }
} 