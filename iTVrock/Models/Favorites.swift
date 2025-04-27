import Foundation

// FavoriteItem is replaced by the Favorite model from Favorite.swift
// We only add here the FavoriteManager implementation

// Manager for handling favorites
class FavoriteManager: ObservableObject {
    @Published var favorites: [Favorite] = []
    
    private let saveKey = "favorites"
    
    init() {
        loadFavorites()
    }
    
    func toggleFavorite(itemId: String, type: FavoriteType, profileId: UUID) {
        if isFavorite(itemId: itemId, type: type) {
            removeFavorite(itemId: itemId, type: type)
        } else {
            addFavorite(itemId: itemId, type: type, profileId: profileId)
        }
    }
    
    func addFavorite(itemId: String, type: FavoriteType, profileId: UUID) {
        // Make sure it's not already a favorite
        guard !isFavorite(itemId: itemId, type: type) else { return }
        
        // Add to favorites
        let favorite = Favorite(
            profileId: profileId,
            itemId: itemId,
            type: type
        )
        favorites.append(favorite)
        saveFavorites()
    }
    
    func removeFavorite(itemId: String, type: FavoriteType) {
        favorites.removeAll(where: { $0.itemId == itemId && $0.type == type })
        saveFavorites()
    }
    
    func isFavorite(itemId: String, type: FavoriteType) -> Bool {
        favorites.contains(where: { $0.itemId == itemId && $0.type == type })
    }
    
    // MARK: - Persistence
    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Favorite].self, from: data) {
            favorites = decoded
        }
    }
} 