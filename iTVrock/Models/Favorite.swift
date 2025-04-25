import Foundation

enum FavoriteType: String, Codable {
    case channel
    case movie
    case show
}

struct Favorite: Identifiable, Codable {
    let id: UUID
    let profileId: UUID
    let itemId: String
    let type: FavoriteType
    var order: Int
    var dateAdded: Date
    
    init(id: UUID = UUID(),
         profileId: UUID,
         itemId: String,
         type: FavoriteType,
         order: Int = 0,
         dateAdded: Date = Date()) {
        self.id = id
        self.profileId = profileId
        self.itemId = itemId
        self.type = type
        self.order = order
        self.dateAdded = dateAdded
    }
}

// MARK: - CloudKit Sync
extension Favorite {
    static let recordType = "Favorite"
    
    var cloudKitRecord: [String: Any] {
        [
            "id": id.uuidString,
            "profileId": profileId.uuidString,
            "itemId": itemId,
            "type": type.rawValue,
            "order": order,
            "dateAdded": dateAdded
        ]
    }
} 