import Foundation

enum PlaylistType: String, Codable {
    case m3u
    case xtream
}

struct Playlist: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: PlaylistType
    var url: String
    var username: String?
    var password: String?
    var epgUrl: String?
    var refreshInterval: TimeInterval // in hours
    var lastUpdated: Date?
    var isActive: Bool
    var profileId: UUID // associated profile
    
    init(id: UUID = UUID(),
         name: String,
         type: PlaylistType,
         url: String,
         username: String? = nil,
         password: String? = nil,
         epgUrl: String? = nil,
         refreshInterval: TimeInterval = 24, // default 24 hours
         lastUpdated: Date? = nil,
         isActive: Bool = true,
         profileId: UUID) {
        self.id = id
        self.name = name
        self.type = type
        self.url = url
        self.username = username
        self.password = password
        self.epgUrl = epgUrl
        self.refreshInterval = refreshInterval
        self.lastUpdated = lastUpdated
        self.isActive = isActive
        self.profileId = profileId
    }
}

// MARK: - CloudKit Sync
extension Playlist {
    static let recordType = "Playlist"
    
    var cloudKitRecord: [String: Any] {
        [
            "id": id.uuidString,
            "name": name,
            "type": type.rawValue,
            "url": url,
            "username": username as Any,
            "password": password as Any, // Note: In production, password should be handled more securely
            "epgUrl": epgUrl as Any,
            "refreshInterval": refreshInterval,
            "lastUpdated": lastUpdated as Any,
            "isActive": isActive,
            "profileId": profileId.uuidString
        ]
    }
} 