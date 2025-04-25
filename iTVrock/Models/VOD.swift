import Foundation

// Base protocol for VOD content
protocol VODContent: Identifiable, Codable {
    var id: String { get }
    var title: String { get }
    var description: String? { get }
    var posterUrl: String? { get }
    var category: String { get }
    var playlistId: UUID { get }
    var rating: String? { get }
    var year: Int? { get }
}

struct Movie: VODContent {
    let id: String
    var title: String
    var description: String?
    var posterUrl: String?
    var category: String
    var playlistId: UUID
    var streamUrl: String
    var duration: TimeInterval
    var rating: String?
    var year: Int?
    var addedDate: Date?
    var tmdbId: Int?
    
    // Additional metadata from TMDb
    var cast: [String]?
    var director: String?
    var imdbRating: Double?
}

struct TVShow: VODContent {
    let id: String
    var title: String
    var description: String?
    var posterUrl: String?
    var category: String
    var playlistId: UUID
    var rating: String?
    var year: Int?
    var seasons: [Season]
    var tmdbId: Int?
    
    struct Season: Codable {
        let number: Int
        var episodes: [Episode]
    }
}

struct Episode: Identifiable, Codable {
    let id: String
    var title: String
    var description: String?
    var seasonNumber: Int
    var episodeNumber: Int
    var streamUrl: String
    var thumbnailUrl: String?
    var duration: TimeInterval
    var airDate: Date?
}

// MARK: - Watch Progress
struct WatchProgress: Codable {
    let contentId: String
    let profileId: UUID
    var position: TimeInterval
    var duration: TimeInterval
    var lastWatched: Date
    var completed: Bool
    
    var progress: Double {
        duration > 0 ? position / duration : 0
    }
}

// MARK: - Local Storage
extension Movie {
    var dictionary: [String: Any] {
        [
            "id": id,
            "title": title,
            "description": description as Any,
            "posterUrl": posterUrl as Any,
            "category": category,
            "playlistId": playlistId.uuidString,
            "streamUrl": streamUrl,
            "duration": duration,
            "rating": rating as Any,
            "year": year as Any,
            "addedDate": addedDate as Any,
            "tmdbId": tmdbId as Any,
            "cast": cast as Any,
            "director": director as Any,
            "imdbRating": imdbRating as Any
        ]
    }
}

extension TVShow {
    var dictionary: [String: Any] {
        [
            "id": id,
            "title": title,
            "description": description as Any,
            "posterUrl": posterUrl as Any,
            "category": category,
            "playlistId": playlistId.uuidString,
            "rating": rating as Any,
            "year": year as Any,
            "tmdbId": tmdbId as Any,
            "seasons": seasons.map { season in
                [
                    "number": season.number,
                    "episodes": season.episodes.map { $0.dictionary }
                ]
            }
        ]
    }
}

extension Episode {
    var dictionary: [String: Any] {
        [
            "id": id,
            "title": title,
            "description": description as Any,
            "seasonNumber": seasonNumber,
            "episodeNumber": episodeNumber,
            "streamUrl": streamUrl,
            "thumbnailUrl": thumbnailUrl as Any,
            "duration": duration,
            "airDate": airDate as Any
        ]
    }
} 