import SwiftUI

struct SettingsView: View {
    @State private var showM3UConfig = false
    @State private var showXtreamConfig = false
    @State private var showProfileSheet = false
    @State private var showPlaybackSettings = false
    @State private var showEnginePrioritySettings = false
    
    enum SettingsRow: Hashable {
        case m3u, xtream, profile
    }
    
    @FocusState private var focusedRow: SettingsRow?
    
    @EnvironmentObject var playlistManager: PlaylistManager
    
    @State private var isParsingM3U = false
    
    var body: some View {
        VStack(alignment: .center, spacing: 30) {
            Text("Settings")
                .font(.largeTitle)
                .padding(.horizontal)
            
            HStack {
                Spacer()
                List {
                    Section(header: Text("Stream Sources").font(.title2)) {
                        Button(action: {
                            print("Remote List (M3U) button pressed")
                            showM3UConfig = true
                        }) {
                            Label("Remote List (M3U)", systemImage: "doc.text")
                        }
                        .sheet(isPresented: $showM3UConfig) {
                            M3UConfigView()
                        }
                        .onChange(of: showM3UConfig) {
                            print("showM3UConfig changed to", showM3UConfig)
                        }
                        
                        Button(action: { showXtreamConfig = true }) {
                            Label("Xtream", systemImage: "server.rack")
                        }
                        .sheet(isPresented: $showXtreamConfig) {
                            XtreamConfigView()
                        }
                    }
                    Section(header: Text("Playback").font(.title2)) {
                        Button(action: { showPlaybackSettings = true }) {
                            Label("Player Engine", systemImage: "play.rectangle")
                        }
                        .sheet(isPresented: $showPlaybackSettings) {
                            PlaybackSettingsView()
                        }
                        Button(action: { showEnginePrioritySettings = true }) {
                            Label("Engine Priority", systemImage: "list.number")
                        }
                        .sheet(isPresented: $showEnginePrioritySettings) {
                            EnginePrioritySettingsView()
                        }
                    }
                    Section {
                        Button(action: { showProfileSheet = true }) {
                            Label("Profile", systemImage: "person.crop.circle")
                        }
                        .sheet(isPresented: $showProfileSheet) {
                            ProfileSelectionSheet()
                        }
                    }
                }
                .listStyle(.plain)
                .frame(maxWidth: 800)
                Spacer()
            }
        }
        .onAppear {
            // No need to set focus manually with List
        }
        .padding()
    }
}

struct M3UConfigView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var m3uUrl: String = ""
    @State private var updateInterval: UpdateInterval = .everyDay
    @State private var streams: [M3UStream] = []
    @State private var editingStream: M3UStream? = nil
    @State private var showScanPrompt = false
    @State private var streamToScan: M3UStream? = nil
    @State private var isCheckingUrl = false
    @State private var showUrlWarning = false
    @State private var lastAddedStreamId: UUID? = nil
    @State private var failedAttempts: Int = 0
    @State private var showForceAddPrompt = false
    @State private var retryAttempts = 0
    @State private var isAutoRetrying = false
    @State private var isBlockingScan = false
    @State private var scanProgress: Double = 0
    @State private var isScanning: Bool = false
    @State private var scanCancelled: Bool = false
    @State private var epgUrl: String = ""
    
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var epgManager: EPGManager
    
    @State private var isParsingM3U = false
    
    enum UpdateInterval: String, CaseIterable, Identifiable {
        case everyDay = "Every Day"
        case every3Days = "Every 3 Days"
        case everyWeek = "Every Week"
        var id: String { rawValue }
    }
    
    enum StreamStatus { case success, failed }
    struct M3UStream: Identifiable, Equatable {
        let id: UUID
        var name: String
        var url: String
        var interval: UpdateInterval
        var status: StreamStatus
    }
    
    func isValidUrl(_ url: String) -> Bool {
        guard let url = URL(string: url), url.scheme == "http" || url.scheme == "https" else { return false }
        return true
    }
    
    func checkM3UUrl(_ url: String, completion: @escaping (Bool) -> Void) {
        isCheckingUrl = true
        guard let urlObj = URL(string: url) else {
            isCheckingUrl = false
            completion(false)
            return
        }
        let task = URLSession.shared.dataTask(with: urlObj) { data, response, error in
            DispatchQueue.main.async {
                isCheckingUrl = false
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let data = data, let body = String(data: data, encoding: .utf8), !body.isEmpty else {
                    completion(false)
                    return
                }
                // Optionally, check for #EXTM3U header
                if body.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#EXTM3U") {
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
        task.resume()
    }
    
    func autoRetryM3UUrl(_ url: String, maxAttempts: Int = 3, completion: @escaping (Bool) -> Void) {
        var attempt = 0
        func tryNext() {
            retryAttempts = attempt
            isCheckingUrl = true
            checkM3UUrl(url) { success in
                if success {
                    isCheckingUrl = false
                    completion(true)
                } else {
                    attempt += 1
                    if attempt < maxAttempts {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { tryNext() }
                    } else {
                        isCheckingUrl = false
                        completion(false)
                    }
                }
            }
        }
        tryNext()
    }
    
    func fetchAndParseM3U(for stream: M3UStream, completion: @escaping () -> Void) {
        guard let url = URL(string: stream.url) else { completion(); return }
        isParsingM3U = true
        isCheckingUrl = true
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isCheckingUrl = false
                isParsingM3U = false
                guard let data = data, let m3uString = String(data: data, encoding: .utf8) else { completion(); return }
                let (channels, _) = M3UParser.parse(m3u: m3uString, playlistId: stream.id)
                playlistManager.channels.removeAll { $0.playlistId == stream.id }
                playlistManager.channels.append(contentsOf: channels)
                completion()
            }
        }.resume()
    }
    
    func fetchAndParseM3UWithProgress(for stream: M3UStream, completion: @escaping () -> Void) {
        guard let url = URL(string: stream.url) else { completion(); return }
        isParsingM3U = true
        scanProgress = 0
        scanCancelled = false
        isCheckingUrl = true
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isCheckingUrl = false
                isParsingM3U = false
                guard let data = data, let m3uString = String(data: data, encoding: .utf8) else { completion(); return }
                let lines = m3uString.components(separatedBy: .newlines)
                let total = max(1, lines.count)
                var channels: [Channel] = []
                var movies: [Movie] = []
                var currentTitle: String?
                var currentCategory: String = "Other"
                var currentLogo: String?
                var currentType: String = "channel"
                var currentUrl: String?
                for (i, line) in lines.enumerated() {
                    if scanCancelled { break }
                    if line.hasPrefix("#EXTINF:") {
                        let info = line.dropFirst("#EXTINF:".count)
                        let parts = info.components(separatedBy: ",")
                        if let meta = parts.first, let name = parts.last {
                            currentTitle = name.trimmingCharacters(in: .whitespaces)
                            if let groupRange = meta.range(of: "group-title=\\\"([^\\\"]*)\\\"", options: .regularExpression) {
                                currentCategory = String(meta[groupRange]).replacingOccurrences(of: "group-title=\"", with: "").replacingOccurrences(of: "\"", with: "")
                            }
                            if let logoRange = meta.range(of: "tvg-logo=\\\"([^\\\"]*)\\\"", options: .regularExpression) {
                                currentLogo = String(meta[logoRange]).replacingOccurrences(of: "tvg-logo=\"", with: "").replacingOccurrences(of: "\"", with: "")
                            }
                            if meta.contains("type=movie") || (meta.contains("catchup=") && meta.contains("movie")) {
                                currentType = "movie"
                            } else {
                                currentType = "channel"
                            }
                        }
                        currentUrl = line.trimmingCharacters(in: .whitespaces)
                        if let title = currentTitle, let url = currentUrl {
                            if currentType == "movie" {
                                let movie = Movie(
                                    id: UUID().uuidString,
                                    title: title,
                                    description: nil,
                                    posterUrl: currentLogo,
                                    category: currentCategory,
                                    playlistId: stream.id,
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
                                    playlistId: stream.id
                                )
                                channels.append(channel)
                            }
                        }
                        currentTitle = nil
                        currentLogo = nil
                        currentType = "channel"
                        currentUrl = nil
                    }
                    scanProgress = Double(i+1) / Double(total)
                }
                playlistManager.channels.removeAll { $0.playlistId == stream.id }
                playlistManager.channels.append(contentsOf: channels)
                isParsingM3U = false
                completion()
            }
        }.resume()
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                Text("Add Remote List (M3U)")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                
                if !streams.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your M3U Streams")
                            .font(.headline)
                        ForEach(streams) { stream in
                            HStack {
                                Text(stream.name)
                                    .bold()
                                Text(stream.url)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                if stream.status == .success {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else if stream.status == .failed {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                                Spacer(minLength: 40)
                                Button("Edit") {
                                    name = stream.name
                                    m3uUrl = stream.url
                                    updateInterval = stream.interval
                                    editingStream = stream
                                }
                                .buttonStyle(.bordered)
                                Button(action: {
                                    let idx = streams.firstIndex(of: stream)!
                                    isCheckingUrl = true
                                    autoRetryM3UUrl(stream.url) { success in
                                        isCheckingUrl = false
                                        streams[idx].status = success ? .success : .failed
                                        if success {
                                            lastAddedStreamId = stream.id
                                            if streams[idx].status == .success {
                                                fetchAndParseM3UWithProgress(for: streams[idx]) {}
                                            }
                                        }
                                    }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                }
                                .buttonStyle(.borderedProminent)
                                Button(role: .destructive) {
                                    streams.removeAll { $0.id == stream.id }
                                    if lastAddedStreamId == stream.id { lastAddedStreamId = nil }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.bordered)
                            }
                            .frame(minWidth: 900, maxWidth: .infinity)
                        }
                    }
                    .padding(.bottom, 10)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Name")
                        .font(.headline)
                    TextField("Enter name", text: $name)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(10)
                        .frame(maxWidth: .infinity)
                    Text("M3U URL")
                        .font(.headline)
                    TextField("Enter M3U URL", text: $m3uUrl)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(10)
                        .frame(maxWidth: .infinity)
                    if !m3uUrl.isEmpty && !isValidUrl(m3uUrl) {
                        Text("Please enter a valid http(s) URL.")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    Text("Update Interval")
                        .font(.headline)
                    Picker("Update Interval", selection: $updateInterval) {
                        ForEach(UpdateInterval.allCases) { interval in
                            Text(interval.rawValue).tag(interval)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("EPG URL (optional)")
                        .font(.headline)
                    TextField("Enter EPG XMLTV URL", text: $epgUrl)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(10)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                
                HStack(spacing: 20) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button(editingStream == nil ? "Save" : "Update") {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedUrl = m3uUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedName.isEmpty, !trimmedUrl.isEmpty, isValidUrl(trimmedUrl) else {
                            showUrlWarning = !isValidUrl(trimmedUrl)
                            return
                        }
                        if editingStream == nil {
                            isBlockingScan = true
                            isScanning = true
                            scanProgress = 0
                            scanCancelled = false
                            isAutoRetrying = true
                            autoRetryM3UUrl(trimmedUrl) { success in
                                isAutoRetrying = false
                                if success {
                                    failedAttempts = 0
                                    let newStream = M3UStream(id: UUID(), name: trimmedName, url: trimmedUrl, interval: updateInterval, status: .success)
                                    streams.append(newStream)
                                    if newStream.status == .success {
                                        fetchAndParseM3UWithProgress(for: newStream) {
                                            isBlockingScan = false
                                            isScanning = false
                                            dismiss()
                                        }
                                    } else {
                                        isBlockingScan = false
                                        isScanning = false
                                    }
                                    lastAddedStreamId = newStream.id
                                    name = ""
                                    m3uUrl = ""
                                    updateInterval = .everyDay
                                    if !epgUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let url = URL(string: epgUrl) {
                                        isParsingM3U = true
                                        epgManager.fetchAndParse(from: url) { _ in
                                            isParsingM3U = false
                                        }
                                    }
                                } else {
                                    isBlockingScan = false
                                    isScanning = false
                                    showForceAddPrompt = true
                                }
                            }
                        } else if let editing = editingStream, let idx = streams.firstIndex(of: editing) {
                            isCheckingUrl = true
                            autoRetryM3UUrl(trimmedUrl) { success in
                                isCheckingUrl = false
                                streams[idx].status = success ? .success : .failed
                                if success {
                                    streams[idx].name = trimmedName
                                    streams[idx].url = trimmedUrl
                                    streams[idx].interval = updateInterval
                                    if streams[idx].status == .success {
                                        fetchAndParseM3U(for: streams[idx]) {}
                                    }
                                    lastAddedStreamId = streams[idx].id
                                    editingStream = nil
                                    if !epgUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let url = URL(string: epgUrl) {
                                        isParsingM3U = true
                                        epgManager.fetchAndParse(from: url) { _ in
                                            isParsingM3U = false
                                        }
                                    }
                                } else {
                                    showUrlWarning = true
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCheckingUrl || isAutoRetrying || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || m3uUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isValidUrl(m3uUrl))
                    .overlay(
                        Group {
                            if isCheckingUrl || isAutoRetrying {
                                ProgressView().padding(.leading, 8)
                            }
                        }, alignment: .trailing
                    )
                }
                .alert("Connection failed 3 times", isPresented: $showForceAddPrompt) {
                    Button("Yes, Add Anyway") {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedUrl = m3uUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                        let newStream = M3UStream(id: UUID(), name: trimmedName, url: trimmedUrl, interval: updateInterval, status: .failed)
                        streams.append(newStream)
                        lastAddedStreamId = newStream.id
                        streamToScan = newStream
                        showScanPrompt = true
                        name = ""
                        m3uUrl = ""
                        updateInterval = .everyDay
                        failedAttempts = 0
                        retryAttempts = 0
                    }
                    Button("No", role: .cancel) {
                        retryAttempts = 0
                    }
                } message: {
                    Text("Connection failed 3 times. Do you still want to add this source?")
                }
                .alert("Start Scanning?", isPresented: $showScanPrompt, presenting: streamToScan) { stream in
                    Button("Yes, Scan Now") {
                        print("Scanning/fetching for: \(stream.url)")
                        // TODO: Call fetch/scan logic here
                    }
                    Button("No", role: .cancel) {}
                } message: { stream in
                    Text("Do you want the system to start scanning and fetch the data for this stream?")
                }
            }
            if isCheckingUrl || isAutoRetrying {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                    if isAutoRetrying {
                        Text("Checking connection... Attempt \(retryAttempts+1)/3")
                            .foregroundColor(.white)
                            .font(.headline)
                    } else {
                        Text("Checking connection...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
                .padding(40)
                .background(Color.black.opacity(0.7))
                .cornerRadius(16)
            }
            if isParsingM3U {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Parsing channels...")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .padding(40)
                .background(Color.black.opacity(0.7))
                .cornerRadius(16)
            }
            if isScanning {
                Color.black.opacity(0.5).ignoresSafeArea()
                VStack(spacing: 24) {
                    ProgressView(value: scanProgress)
                        .frame(width: 300)
                    Text("Scanning content... \(Int(scanProgress * 100))%")
                        .foregroundColor(.white)
                        .font(.title2)
                    Button("Cancel") {
                        scanCancelled = true
                        isScanning = false
                        isBlockingScan = false
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 16)
                }
                .padding(40)
                .background(Color.black.opacity(0.8))
                .cornerRadius(20)
            }
        }
        .padding(40)
        .frame(width: 900, height: 350)
    }
}

struct XtreamConfigView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var serverUrl: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var updateInterval: UpdateInterval = .everyDay
    @State private var streams: [XtreamStream] = []
    @State private var editingStream: XtreamStream? = nil
    @State private var showScanPrompt = false
    @State private var streamToScan: XtreamStream? = nil
    @State private var isCheckingConnection = false
    @State private var showConnectionError = false
    @State private var showUrlWarning = false
    @State private var lastAddedStreamId: UUID? = nil
    @State private var failedAttempts: Int = 0
    @State private var showForceAddPrompt = false
    @State private var retryAttempts = 0
    @State private var isAutoRetrying = false
    @State private var isBlockingScan = false
    @State private var scanProgress: Double = 0
    @State private var isScanning: Bool = false
    @State private var scanCancelled: Bool = false
    @State private var epgUrl: String = ""
    
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var vodManager: VODManager
    @EnvironmentObject var epgManager: EPGManager
    
    @State private var isParsingM3U = false
    
    enum UpdateInterval: String, CaseIterable, Identifiable {
        case everyDay = "Every Day"
        case every3Days = "Every 3 Days"
        case everyWeek = "Every Week"
        var id: String { rawValue }
    }
    
    enum StreamStatus { case success, failed }
    struct XtreamStream: Identifiable, Equatable {
        let id: UUID
        var name: String
        var serverUrl: String
        var username: String
        var password: String
        var interval: UpdateInterval
        var status: StreamStatus
    }
    
    func checkXtreamConnection(server: String, user: String, pass: String, completion: @escaping (Bool) -> Void) {
        // Simulate async check (replace with real API call)
        isCheckingConnection = true
        // Build the API URL
        guard let url = URL(string: server),
              var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            isCheckingConnection = false
            completion(false)
            return
        }
        comps.path = "/player_api.php"
        comps.queryItems = [
            URLQueryItem(name: "username", value: user),
            URLQueryItem(name: "password", value: pass)
        ]
        guard let apiUrl = comps.url else {
            isCheckingConnection = false
            completion(false)
            return
        }
        let task = URLSession.shared.dataTask(with: apiUrl) { data, response, error in
            DispatchQueue.main.async {
                isCheckingConnection = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let userInfo = json["user_info"] as? [String: Any],
                      let auth = userInfo["auth"] as? Int else {
                    completion(false)
                    return
                }
                // auth == 1 means success
                completion(auth == 1)
            }
        }
        task.resume()
    }
    
    func autoRetryXtream(_ server: String, _ user: String, _ pass: String, maxAttempts: Int = 3, completion: @escaping (Bool) -> Void) {
        var attempt = 0
        func tryNext() {
            retryAttempts = attempt
            isCheckingConnection = true
            checkXtreamConnection(server: server, user: user, pass: pass) { success in
                if success {
                    isCheckingConnection = false
                    completion(true)
                } else {
                    attempt += 1
                    if attempt < maxAttempts {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { tryNext() }
                    } else {
                        isCheckingConnection = false
                        completion(false)
                    }
                }
            }
        }
        tryNext()
    }
    
    func isValidUrl(_ url: String) -> Bool {
        guard let url = URL(string: url), url.scheme == "http" || url.scheme == "https" else { return false }
        return true
    }
    
    func fetchAndParseXtream(for stream: XtreamStream, completion: @escaping () -> Void) {
        isParsingM3U = true
        // Add verbose debugging of credentials
        print("Debug - Fetching Xtream content with:")
        print("   Server URL: \(stream.serverUrl)")
        print("   Username: \(stream.username)")
        print("   Password: \(stream.password)")
        
        let credentials = XtreamCodesCredentials(serverURL: stream.serverUrl, username: stream.username, password: stream.password)
        Task {
            do {
                let xtreamChannels = try await XtreamCodesAPI.fetchLiveStreams(credentials: credentials)
                // Log the first channel data to debug
                if let firstChannel = xtreamChannels.first {
                    print("Debug - First channel data:")
                    print("   Name: \(firstChannel.name)")
                    print("   Stream URL: \(firstChannel.stream_url ?? "nil")")
                    print("   Stream ID: \(firstChannel.stream_id)")
                }
                
                let channels: [Channel] = xtreamChannels.map { xc in
                    // Construct proper URL with server/username/password if stream_url is empty or nil
                    var streamUrl = xc.stream_url ?? ""
                    if streamUrl.isEmpty {
                        let server = stream.serverUrl.hasSuffix("/") ? String(stream.serverUrl.dropLast()) : stream.serverUrl
                        streamUrl = "\(server)/live/\(stream.username)/\(stream.password)/\(xc.stream_id).ts"
                        print("Debug - Constructed URL for empty stream_url: \(streamUrl)")
                    }
                    
                    return Channel(
                        id: String(xc.stream_id),
                        name: xc.name,
                        category: xc.category_id ?? "Other",
                        streamUrl: streamUrl,
                        logoUrl: xc.stream_icon,
                        tvgId: xc.epg_channel_id,
                        playlistId: stream.id
                    )
                }
                let xtreamMovies = try await XtreamCodesAPI.fetchMovies(credentials: credentials)
                // Log the first movie data to debug
                if let firstMovie = xtreamMovies.first {
                    print("Debug - First movie data:")
                    print("   Name: \(firstMovie.name)")
                    print("   Direct Source: \(firstMovie.direct_source ?? "nil")")
                    print("   Stream ID: \(firstMovie.stream_id)")
                }
                
                let movies: [Movie] = xtreamMovies.map { xm in
                    // Construct proper URL with server/username/password if direct_source is empty or nil
                    var streamUrl = xm.direct_source ?? ""
                    if streamUrl.isEmpty {
                        let server = stream.serverUrl.hasSuffix("/") ? String(stream.serverUrl.dropLast()) : stream.serverUrl
                        streamUrl = "\(server)/movie/\(stream.username)/\(stream.password)/\(xm.stream_id).mp4"
                        print("Debug - Constructed URL for empty direct_source: \(streamUrl)")
                    }
                    
                    return Movie(
                        id: String(xm.stream_id),
                        title: xm.name,
                        description: nil,
                        posterUrl: xm.stream_icon,
                        category: xm.category_id ?? "Other",
                        playlistId: stream.id,
                        streamUrl: streamUrl,
                        duration: 5400,
                        rating: nil,
                        year: nil,
                        addedDate: nil,
                        tmdbId: nil,
                        cast: nil,
                        director: nil,
                        imdbRating: nil
                    )
                }
                
                // Debug check if any URLs are empty
                let emptyChannelUrls = channels.filter { $0.streamUrl.isEmpty }
                let emptyMovieUrls = movies.filter { $0.streamUrl.isEmpty }
                if !emptyChannelUrls.isEmpty {
                    print("Warning - \(emptyChannelUrls.count) channels have empty stream URLs")
                }
                if !emptyMovieUrls.isEmpty {
                    print("Warning - \(emptyMovieUrls.count) movies have empty stream URLs")
                }
                
                DispatchQueue.main.async {
                    playlistManager.channels.removeAll { $0.playlistId == stream.id }
                    playlistManager.channels.append(contentsOf: channels)
                    vodManager.movies.removeAll { $0.playlistId == stream.id }
                    vodManager.movies.append(contentsOf: movies)
                    isParsingM3U = false
                    completion()
                }
            } catch {
                print("Error - Failed to fetch Xtream content: \(error)")
                DispatchQueue.main.async {
                    isParsingM3U = false
                    completion()
                }
            }
        }
    }
    
    func fetchAndParseXtreamWithProgress(for stream: XtreamStream, completion: @escaping () -> Void) {
        isParsingM3U = true
        scanProgress = 0
        scanCancelled = false
        
        // Add verbose debugging of credentials
        print("Debug - Fetching Xtream content with progress:")
        print("   Server URL: \(stream.serverUrl)")
        print("   Username: \(stream.username)")
        print("   Password: \(stream.password)")
        
        let credentials = XtreamCodesCredentials(serverURL: stream.serverUrl, username: stream.username, password: stream.password)
        Task {
            do {
                let xtreamChannels = try await XtreamCodesAPI.fetchLiveStreams(credentials: credentials)
                let total = max(1, xtreamChannels.count)
                var channels: [Channel] = []
                for (i, xc) in xtreamChannels.enumerated() {
                    if scanCancelled { break }
                    
                    // Construct proper URL with server/username/password if stream_url is empty or nil
                    var streamUrl = xc.stream_url ?? ""
                    if streamUrl.isEmpty {
                        let server = stream.serverUrl.hasSuffix("/") ? String(stream.serverUrl.dropLast()) : stream.serverUrl
                        streamUrl = "\(server)/live/\(stream.username)/\(stream.password)/\(xc.stream_id).ts"
                    }
                    
                    let channel = Channel(
                        id: String(xc.stream_id),
                        name: xc.name,
                        category: xc.category_id ?? "Other",
                        streamUrl: streamUrl,
                        logoUrl: xc.stream_icon,
                        tvgId: xc.epg_channel_id,
                        playlistId: stream.id
                    )
                    channels.append(channel)
                    scanProgress = Double(i+1) / Double(total)
                    
                    // Log the first channel URL for debugging
                    if i == 0 {
                        print("Debug - First channel URL: \(streamUrl)")
                    }
                }
                let xtreamMovies = try await XtreamCodesAPI.fetchMovies(credentials: credentials)
                let totalMovies = max(1, xtreamMovies.count)
                var movies: [Movie] = []
                for (i, xm) in xtreamMovies.enumerated() {
                    if scanCancelled { break }
                    
                    // Construct proper URL with server/username/password if direct_source is empty or nil
                    var streamUrl = xm.direct_source ?? ""
                    if streamUrl.isEmpty {
                        let server = stream.serverUrl.hasSuffix("/") ? String(stream.serverUrl.dropLast()) : stream.serverUrl
                        streamUrl = "\(server)/movie/\(stream.username)/\(stream.password)/\(xm.stream_id).mp4"
                    }
                    
                    let movie = Movie(
                        id: String(xm.stream_id),
                        title: xm.name,
                        description: nil,
                        posterUrl: xm.stream_icon,
                        category: xm.category_id ?? "Other",
                        playlistId: stream.id,
                        streamUrl: streamUrl,
                        duration: 5400,
                        rating: nil,
                        year: nil,
                        addedDate: nil,
                        tmdbId: nil,
                        cast: nil,
                        director: nil,
                        imdbRating: nil
                    )
                    movies.append(movie)
                    scanProgress = 0.5 + 0.5 * Double(i+1) / Double(totalMovies)
                    
                    // Log the first movie URL for debugging
                    if i == 0 {
                        print("Debug - First movie URL: \(streamUrl)")
                    }
                }
                
                // Debug check if any URLs are empty
                let emptyChannelUrls = channels.filter { $0.streamUrl.isEmpty }
                let emptyMovieUrls = movies.filter { $0.streamUrl.isEmpty }
                if !emptyChannelUrls.isEmpty {
                    print("Warning - \(emptyChannelUrls.count) channels have empty stream URLs")
                }
                if !emptyMovieUrls.isEmpty {
                    print("Warning - \(emptyMovieUrls.count) movies have empty stream URLs")
                }
                
                DispatchQueue.main.async {
                    playlistManager.channels.removeAll { $0.playlistId == stream.id }
                    playlistManager.channels.append(contentsOf: channels)
                    vodManager.movies.removeAll { $0.playlistId == stream.id }
                    vodManager.movies.append(contentsOf: movies)
                    isParsingM3U = false
                    completion()
                }
            } catch {
                print("Error - Failed to fetch Xtream content with progress: \(error)")
                DispatchQueue.main.async {
                    isParsingM3U = false
                    completion()
                }
            }
        }
    }
    
    func updateXtreamEpgUrl() {
        let trimmedServer = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPass = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedServer.isEmpty, !trimmedUser.isEmpty, !trimmedPass.isEmpty else {
            epgUrl = ""
            return
        }
        var url = trimmedServer
        if url.hasSuffix("/") { url.removeLast() }
        epgUrl = "\(url)/xmltv.php?username=\(trimmedUser)&password=\(trimmedPass)"
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                Text("Add Xtream Server")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                
                if !streams.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Xtream Servers")
                            .font(.headline)
                        ForEach(streams) { stream in
                            HStack {
                                Text(stream.name)
                                    .bold()
                                Text(stream.serverUrl)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                if stream.status == .success {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else if stream.status == .failed {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                                Spacer(minLength: 40)
                                Button("Edit") {
                                    name = stream.name
                                    serverUrl = stream.serverUrl
                                    username = stream.username
                                    password = stream.password
                                    updateInterval = stream.interval
                                    editingStream = stream
                                }
                                .buttonStyle(.bordered)
                                Button(action: {
                                    let idx = streams.firstIndex(of: stream)!
                                    isCheckingConnection = true
                                    autoRetryXtream(stream.serverUrl, stream.username, stream.password) { success in
                                        isCheckingConnection = false
                                        streams[idx].status = success ? .success : .failed
                                        if success {
                                            lastAddedStreamId = stream.id
                                            if streams[idx].status == .success {
                                                fetchAndParseXtreamWithProgress(for: streams[idx]) {}
                                            }
                                        }
                                    }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                }
                                .buttonStyle(.borderedProminent)
                                Button(role: .destructive) {
                                    streams.removeAll { $0.id == stream.id }
                                    if lastAddedStreamId == stream.id { lastAddedStreamId = nil }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.bordered)
                            }
                            .frame(minWidth: 900, maxWidth: .infinity)
                        }
                    }
                    .padding(.bottom, 10)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Name")
                        .font(.headline)
                    TextField("Enter name", text: $name)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(10)
                        .frame(maxWidth: .infinity)
                    Text("Server URL")
                        .font(.headline)
                    TextField("Enter server URL", text: $serverUrl)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(10)
                        .frame(maxWidth: .infinity)
                    if !serverUrl.isEmpty && !isValidUrl(serverUrl) {
                        Text("Please enter a valid http(s) URL.")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    Text("Username")
                        .font(.headline)
                    TextField("Enter username", text: $username)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(10)
                        .frame(maxWidth: .infinity)
                    
                    Text("Password")
                        .font(.headline)
                    TextField("Enter password", text: $password)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(10)
                        .frame(maxWidth: .infinity)
                    Text("Update Interval")
                        .font(.headline)
                    Picker("Update Interval", selection: $updateInterval) {
                        ForEach(UpdateInterval.allCases) { interval in
                            Text(interval.rawValue).tag(interval)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("EPG URL (optional)")
                        .font(.headline)
                    TextField("EPG XMLTV URL", text: $epgUrl)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(10)
                        .frame(maxWidth: .infinity)
                        .disabled(true)
                }
                .frame(maxWidth: .infinity)
                
                HStack(spacing: 20) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button(editingStream == nil ? "Save" : "Update") {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedServer = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedPass = password.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedName.isEmpty, !trimmedServer.isEmpty, !trimmedUser.isEmpty, !trimmedPass.isEmpty, isValidUrl(trimmedServer) else {
                            showUrlWarning = !isValidUrl(trimmedServer)
                            return
                        }
                        if editingStream == nil {
                            isBlockingScan = true
                            isScanning = true
                            scanProgress = 0
                            scanCancelled = false
                            isAutoRetrying = true
                            autoRetryXtream(trimmedServer, trimmedUser, trimmedPass) { success in
                                isAutoRetrying = false
                                if success {
                                    failedAttempts = 0
                                    let newStream = XtreamStream(id: UUID(), name: trimmedName, serverUrl: trimmedServer, username: trimmedUser, password: trimmedPass, interval: updateInterval, status: .success)
                                    streams.append(newStream)
                                    if newStream.status == .success {
                                        fetchAndParseXtreamWithProgress(for: newStream) {
                                            isBlockingScan = false
                                            isScanning = false
                                            dismiss()
                                        }
                                    } else {
                                        isBlockingScan = false
                                        isScanning = false
                                    }
                                    lastAddedStreamId = newStream.id
                                    name = ""
                                    serverUrl = ""
                                    username = ""
                                    password = ""
                                    updateInterval = .everyDay
                                    if !epgUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let url = URL(string: epgUrl) {
                                        isParsingM3U = true
                                        epgManager.fetchAndParse(from: url) { _ in
                                            isParsingM3U = false
                                        }
                                    }
                                } else {
                                    isBlockingScan = false
                                    isScanning = false
                                    showForceAddPrompt = true
                                }
                            }
                        } else if let editing = editingStream, let idx = streams.firstIndex(of: editing) {
                            isCheckingConnection = true
                            autoRetryXtream(trimmedServer, trimmedUser, trimmedPass) { success in
                                isCheckingConnection = false
                                streams[idx].status = success ? .success : .failed
                                if success {
                                    streams[idx].name = trimmedName
                                    streams[idx].serverUrl = trimmedServer
                                    streams[idx].username = trimmedUser
                                    streams[idx].password = trimmedPass
                                    streams[idx].interval = updateInterval
                                    if streams[idx].status == .success {
                                        fetchAndParseXtream(for: streams[idx]) {}
                                    }
                                    lastAddedStreamId = streams[idx].id
                                    editingStream = nil
                                    if !epgUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let url = URL(string: epgUrl) {
                                        isParsingM3U = true
                                        epgManager.fetchAndParse(from: url) { _ in
                                            isParsingM3U = false
                                        }
                                    }
                                } else {
                                    showConnectionError = true
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCheckingConnection || isAutoRetrying || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || serverUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || !isValidUrl(serverUrl))
                    .overlay(
                        Group {
                            if isCheckingConnection || isAutoRetrying {
                                ProgressView().padding(.leading, 8)
                            }
                        }, alignment: .trailing
                    )
                }
                .alert("Connection failed 3 times", isPresented: $showForceAddPrompt) {
                    Button("Yes, Add Anyway") {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedServer = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedPass = password.trimmingCharacters(in: .whitespacesAndNewlines)
                        let newStream = XtreamStream(id: UUID(), name: trimmedName, serverUrl: trimmedServer, username: trimmedUser, password: trimmedPass, interval: updateInterval, status: .failed)
                        streams.append(newStream)
                        lastAddedStreamId = newStream.id
                        streamToScan = newStream
                        showScanPrompt = true
                        name = ""
                        serverUrl = ""
                        username = ""
                        password = ""
                        updateInterval = .everyDay
                        failedAttempts = 0
                        retryAttempts = 0
                    }
                    Button("No", role: .cancel) {
                        retryAttempts = 0
                    }
                } message: {
                    Text("Connection failed 3 times. Do you still want to add this source?")
                }
                .alert("Start Scanning?", isPresented: $showScanPrompt, presenting: streamToScan) { stream in
                    Button("Yes, Scan Now") {
                        print("Scanning/fetching for: \(stream.name) @ \(stream.serverUrl)")
                        // TODO: Call fetch/scan logic here
                    }
                    Button("No", role: .cancel) {}
                } message: { stream in
                    Text("Do you want the system to start scanning and fetch the data for this server?")
                }
            }
            if isCheckingConnection || isAutoRetrying {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                    if isAutoRetrying {
                        Text("Checking connection... Attempt \(retryAttempts+1)/3")
                            .foregroundColor(.white)
                            .font(.headline)
                    } else {
                        Text("Checking connection...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
                .padding(40)
                .background(Color.black.opacity(0.7))
                .cornerRadius(16)
            }
            if isParsingM3U {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Parsing channels...")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .padding(40)
                .background(Color.black.opacity(0.7))
                .cornerRadius(16)
            }
            if isScanning {
                Color.black.opacity(0.5).ignoresSafeArea()
                VStack(spacing: 24) {
                    ProgressView(value: scanProgress)
                        .frame(width: 300)
                    Text("Scanning content... \(Int(scanProgress * 100))%")
                        .foregroundColor(.white)
                        .font(.title2)
                    Button("Cancel") {
                        scanCancelled = true
                        isScanning = false
                        isBlockingScan = false
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 16)
                }
                .padding(40)
                .background(Color.black.opacity(0.8))
                .cornerRadius(20)
            }
        }
        .padding(40)
        .frame(width: 900, height: 400)
        .onChange(of: serverUrl) { updateXtreamEpgUrl() }
        .onChange(of: username) { updateXtreamEpgUrl() }
        .onChange(of: password) { updateXtreamEpgUrl() }
    }
}

struct ProfileSelectionSheet: View {
    @EnvironmentObject var profileManager: ProfileManager
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(spacing: 24) {
            Text("Select Profile")
                .font(.title2)
            ForEach(profileManager.profiles) { profile in
                Button(action: {
                    profileManager.currentProfile = profile
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "person.crop.circle")
                        Text(profile.name)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(profileManager.currentProfile?.id == profile.id ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .focusable(true)
            }
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 400)
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 