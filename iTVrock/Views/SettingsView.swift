import SwiftUI

struct SettingsView: View {
    @State private var showM3UConfig = false
    @State private var showXtreamConfig = false
    @State private var showProfileSheet = false
    
    enum SettingsRow: Hashable {
        case m3u, xtream, profile
    }
    
    @FocusState private var focusedRow: SettingsRow?
    
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
    @State private var showUrlWarning = false
    @State private var isCheckingUrl = false
    @State private var showUrlError = false
    @State private var lastAddedStreamId: UUID? = nil
    @State private var failedAttempts: Int = 0
    @State private var showForceAddPrompt = false
    @State private var retryAttempts = 0
    @State private var isAutoRetrying = false
    
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
    
    var body: some View {
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
                                    if success { lastAddedStreamId = stream.id }
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
                    isAutoRetrying = true
                    autoRetryM3UUrl(trimmedUrl) { success in
                        isAutoRetrying = false
                        if success {
                            failedAttempts = 0
                            if let editing = editingStream, let idx = streams.firstIndex(of: editing) {
                                streams[idx].name = trimmedName
                                streams[idx].url = trimmedUrl
                                streams[idx].interval = updateInterval
                                streams[idx].status = .success
                                lastAddedStreamId = streams[idx].id
                                editingStream = nil
                            } else {
                                let newStream = M3UStream(id: UUID(), name: trimmedName, url: trimmedUrl, interval: updateInterval, status: .success)
                                streams.append(newStream)
                                lastAddedStreamId = newStream.id
                                streamToScan = newStream
                                showScanPrompt = true
                            }
                            name = ""
                            m3uUrl = ""
                            updateInterval = .everyDay
                        } else {
                            showForceAddPrompt = true
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
    
    var body: some View {
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
                                    if success { lastAddedStreamId = stream.id }
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
                SecureField("Enter password", text: $password)
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
                    guard !trimmedName.isEmpty, !trimmedServer.isEmpty, !trimmedUser.isEmpty, !password.isEmpty, isValidUrl(trimmedServer) else {
                        showUrlWarning = !isValidUrl(trimmedServer)
                        return
                    }
                    isAutoRetrying = true
                    autoRetryXtream(trimmedServer, trimmedUser, password) { success in
                        isAutoRetrying = false
                        if success {
                            failedAttempts = 0
                            if let editing = editingStream, let idx = streams.firstIndex(of: editing) {
                                streams[idx].name = trimmedName
                                streams[idx].serverUrl = trimmedServer
                                streams[idx].username = trimmedUser
                                streams[idx].password = password
                                streams[idx].interval = updateInterval
                                streams[idx].status = .success
                                lastAddedStreamId = streams[idx].id
                                editingStream = nil
                            } else {
                                let newStream = XtreamStream(id: UUID(), name: trimmedName, serverUrl: trimmedServer, username: trimmedUser, password: password, interval: updateInterval, status: .success)
                                streams.append(newStream)
                                lastAddedStreamId = newStream.id
                                streamToScan = newStream
                                showScanPrompt = true
                            }
                            name = ""
                            serverUrl = ""
                            username = ""
                            password = ""
                            updateInterval = .everyDay
                        } else {
                            showForceAddPrompt = true
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
                    let newStream = XtreamStream(id: UUID(), name: trimmedName, serverUrl: trimmedServer, username: trimmedUser, password: password, interval: updateInterval, status: .failed)
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
        .padding(40)
        .frame(width: 900, height: 400)
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