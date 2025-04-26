import Foundation

struct M3UParser {
    static func parse(m3u: String, playlistId: UUID) -> ([Channel], [Movie]) {
        var channels: [Channel] = []
        var movies: [Movie] = []
        
        let lines = m3u.components(separatedBy: .newlines)
        var currentTitle: String?
        var currentCategory: String = "Other"
        var currentLogo: String?
        var currentType: String = "channel"
        var currentUrl: String?
        
        for line in lines {
            if line.hasPrefix("#EXTINF:") {
                // Example: #EXTINF:-1 tvg-id="" tvg-name="Channel Name" tvg-logo="logo.png" group-title="Category",Channel Name
                let info = line.dropFirst("#EXTINF:".count)
                let parts = info.components(separatedBy: ",")
                if let meta = parts.first, let name = parts.last {
                    currentTitle = name.trimmingCharacters(in: .whitespaces)
                    // Parse group-title (category)
                    if let groupRange = meta.range(of: "group-title=\\\"([^\\\"]*)\\\"", options: .regularExpression) {
                        currentCategory = String(meta[groupRange]).replacingOccurrences(of: "group-title=\"", with: "").replacingOccurrences(of: "\"", with: "")
                    }
                    // Parse tvg-logo
                    if let logoRange = meta.range(of: "tvg-logo=\\\"([^\\\"]*)\\\"", options: .regularExpression) {
                        currentLogo = String(meta[logoRange]).replacingOccurrences(of: "tvg-logo=\"", with: "").replacingOccurrences(of: "\"", with: "")
                    }
                    // Parse type (movie or channel)
                    if meta.contains("type=movie") || meta.contains("catchup="), meta.contains("movie") {
                        currentType = "movie"
                    } else {
                        currentType = "channel"
                    }
                }
            } else if !line.hasPrefix("#") && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                currentUrl = line.trimmingCharacters(in: .whitespaces)
                if let title = currentTitle, let url = currentUrl {
                    if currentType == "movie" {
                        let movie = Movie(
                            id: UUID().uuidString,
                            title: title,
                            description: nil,
                            posterUrl: currentLogo,
                            category: currentCategory,
                            playlistId: playlistId,
                            streamUrl: url,
                            duration: 5400,
                            rating: nil,
                            year: nil,
                            addedDate: Date(),
                            tmdbId: nil,
                            cast: nil,
                            director: nil,
                            imdbRating: nil
                        )
                        movies.append(movie)
                    } else {
                        let channel = Channel(
                            id: UUID().uuidString,
                            name: title,
                            category: currentCategory,
                            streamUrl: url,
                            logoUrl: currentLogo,
                            tvgId: nil,
                            playlistId: playlistId
                        )
                        channels.append(channel)
                    }
                }
                // Reset for next entry
                currentTitle = nil
                currentLogo = nil
                currentType = "channel"
                currentUrl = nil
            }
        }
        return (channels, movies)
    }
} 