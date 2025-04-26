import Foundation

struct XtreamCodesCredentials {
    let serverURL: String
    let username: String
    let password: String
}

struct XtreamCodesAPI {
    static func fetchLiveStreams(credentials: XtreamCodesCredentials) async throws -> [XtreamChannel] {
        let urlString = "\(credentials.serverURL)/player_api.php?username=\(credentials.username)&password=\(credentials.password)&action=get_live_streams"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode([XtreamChannel].self, from: data)
        return response
    }
    
    static func fetchMovies(credentials: XtreamCodesCredentials) async throws -> [XtreamMovie] {
        let urlString = "\(credentials.serverURL)/player_api.php?username=\(credentials.username)&password=\(credentials.password)&action=get_vod_streams"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode([XtreamMovie].self, from: data)
        return response
    }
    
    static func fetchSeries(credentials: XtreamCodesCredentials) async throws -> [XtreamSeries] {
        let urlString = "\(credentials.serverURL)/player_api.php?username=\(credentials.username)&password=\(credentials.password)&action=get_series"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode([XtreamSeries].self, from: data)
        return response
    }
}

// MARK: - Minimal Models for Decoding
struct XtreamChannel: Codable {
    let name: String
    let stream_id: Int
    let stream_type: String?
    let category_id: String?
    let stream_icon: String?
    let tv_archive: Int?
    let epg_channel_id: String?
    let custom_sid: String?
    let added: String?
    let stream_url: String? // Not always present
}

struct XtreamMovie: Codable {
    let name: String
    let stream_id: Int
    let category_id: String?
    let stream_icon: String?
    let added: String?
    let container_extension: String?
    let direct_source: String?
}

struct XtreamSeries: Codable {
    let name: String
    let series_id: Int
    let cover: String?
    let plot: String?
    let cast: String?
    let director: String?
    let genre: String?
    let releaseDate: String?
} 