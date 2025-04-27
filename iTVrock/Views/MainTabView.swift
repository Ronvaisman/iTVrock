import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var favoriteManager: FavoriteManager
    @EnvironmentObject var vodManager: VODManager
    
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $selectedTab) {
                ChannelsView()
                    .tabItem {
                        Label("Channels", systemImage: "tv")
                    }
                    .tag(0)
                
                MoviesView()
                    .tabItem {
                        Label("Movies", systemImage: "film")
                    }
                    .tag(1)
                
                TVShowsView()
                    .tabItem {
                        Label("TV Shows", systemImage: "play.tv")
                    }
                    .tag(2)
                
                // TVGuideView()
                //     .tabItem {
                //         Label("TV Guide", systemImage: "calendar")
                //     }
                //     .tag(3)
                
                FavoritesView()
                    .tabItem {
                        Label("Favorites", systemImage: "star")
                    }
                    .tag(4)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(5)
            }
            .onAppear {
                // Configure appearance for tvOS
                UITabBar.appearance().isTranslucent = true
                
                // Connect managers
                playlistManager.vodManager = vodManager
                
                // Refresh all playlists to ensure content is loaded
                for playlist in playlistManager.playlists {
                    if playlist.type == .xtream {
                        playlistManager.loadXtreamContent(from: playlist)
                    } else {
                        playlistManager.parseAndDistributeContent(from: playlist)
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(ProfileManager())
            .environmentObject(PlaylistManager())
            .environmentObject(FavoriteManager())
            .environmentObject(VODManager())
    }
} 