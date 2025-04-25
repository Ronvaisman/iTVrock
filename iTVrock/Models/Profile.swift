import Foundation
import CoreData

struct Profile: Identifiable, Codable {
    let id: UUID
    var name: String
    var avatarIndex: Int
    var pin: String?
    var isParentalControlEnabled: Bool
    var allowedContentRating: String
    var lastPlayedChannelId: String?
    
    init(id: UUID = UUID(), 
         name: String, 
         avatarIndex: Int = 0, 
         pin: String? = nil,
         isParentalControlEnabled: Bool = false,
         allowedContentRating: String = "ALL",
         lastPlayedChannelId: String? = nil) {
        self.id = id
        self.name = name
        self.avatarIndex = avatarIndex
        self.pin = pin
        self.isParentalControlEnabled = isParentalControlEnabled
        self.allowedContentRating = allowedContentRating
        self.lastPlayedChannelId = lastPlayedChannelId
    }
}

// MARK: - CloudKit Sync
extension Profile {
    static let recordType = "Profile"
    
    var cloudKitRecord: [String: Any] {
        [
            "id": id.uuidString,
            "name": name,
            "avatarIndex": avatarIndex,
            "pin": pin as Any,
            "isParentalControlEnabled": isParentalControlEnabled,
            "allowedContentRating": allowedContentRating,
            "lastPlayedChannelId": lastPlayedChannelId as Any
        ]
    }
} 