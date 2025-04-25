import Foundation

struct Channel: Identifiable, Codable {
    let id: String // Unique identifier (could be composite of playlist + channel name/id)
    var name: String
    var category: String
    var streamUrl: String
    var logoUrl: String?
    var tvgId: String? // For EPG matching
    var playlistId: UUID // Reference to source playlist
    var order: Int
    var catchupAvailable: Bool
    var catchupDays: Int?
    var catchupUrlTemplate: String?
    
    // Current program info (updated from EPG)
    var currentProgram: Program?
    var nextProgram: Program?
    
    init(id: String,
         name: String,
         category: String,
         streamUrl: String,
         logoUrl: String? = nil,
         tvgId: String? = nil,
         playlistId: UUID,
         order: Int = 0,
         catchupAvailable: Bool = false,
         catchupDays: Int? = nil,
         catchupUrlTemplate: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.streamUrl = streamUrl
        self.logoUrl = logoUrl
        self.tvgId = tvgId
        self.playlistId = playlistId
        self.order = order
        self.catchupAvailable = catchupAvailable
        self.catchupDays = catchupDays
        self.catchupUrlTemplate = catchupUrlTemplate
    }
}

// MARK: - Program Info
struct Program: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var startTime: Date
    var endTime: Date
    var category: String?
    var year: Int?
    var rating: String?
    var isNew: Bool
    
    var isCurrentlyAiring: Bool {
        let now = Date()
        return now >= startTime && now < endTime
    }
    
    var progress: Double {
        let now = Date()
        guard isCurrentlyAiring else { return 0 }
        let total = endTime.timeIntervalSince(startTime)
        let elapsed = now.timeIntervalSince(startTime)
        return elapsed / total
    }
    
    init(id: UUID = UUID(),
         title: String,
         description: String? = nil,
         startTime: Date,
         endTime: Date,
         category: String? = nil,
         year: Int? = nil,
         rating: String? = nil,
         isNew: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.startTime = startTime
        self.endTime = endTime
        self.category = category
        self.year = year
        self.rating = rating
        self.isNew = isNew
    }
}

// MARK: - Local Storage
extension Channel {
    // Convert to dictionary for local storage
    var dictionary: [String: Any] {
        [
            "id": id,
            "name": name,
            "category": category,
            "streamUrl": streamUrl,
            "logoUrl": logoUrl as Any,
            "tvgId": tvgId as Any,
            "playlistId": playlistId.uuidString,
            "order": order,
            "catchupAvailable": catchupAvailable,
            "catchupDays": catchupDays as Any,
            "catchupUrlTemplate": catchupUrlTemplate as Any
        ]
    }
} 