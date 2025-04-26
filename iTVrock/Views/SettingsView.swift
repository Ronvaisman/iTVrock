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
    @State private var m3uUrl: String = ""
    @State private var updateInterval: UpdateInterval = .everyDay
    @State private var streams: [M3UStream] = []
    @State private var editingStream: M3UStream? = nil
    @State private var showScanPrompt = false
    @State private var streamToScan: M3UStream? = nil
    @State private var showUrlWarning = false
    @State private var isCheckingUrl = false
    @State private var showUrlError = false
    
    enum UpdateInterval: String, CaseIterable, Identifiable {
        case everyDay = "Every Day"
        case every3Days = "Every 3 Days"
        case everyWeek = "Every Week"
        var id: String { rawValue }
    }
    
    struct M3UStream: Identifiable, Equatable {
        let id: UUID
        var url: String
        var interval: UpdateInterval
    }
    
    func isValidUrl(_ url: String) -> Bool {
        guard let url = URL(string: url), url.scheme == "http" || url.scheme == "https" else { return false }
        return true
    }
    
    func checkM3UUrl(_ url: String, completion: @escaping (Bool) -> Void) {
        isCheckingUrl = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isCheckingUrl = false
            // Simulate: fail if url contains "fail", succeed otherwise
            completion(!url.lowercased().contains("fail"))
        }
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
                            Text(stream.url)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("Edit") {
                                m3uUrl = stream.url
                                updateInterval = stream.interval
                                editingStream = stream
                            }
                            .buttonStyle(.bordered)
                            Button("Refresh") {
                                print("Force reload for: \(stream.url)")
                                // TODO: Call fetch/scan logic here
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding(.bottom, 10)
            }
            VStack(alignment: .leading, spacing: 12) {
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
                    let trimmedUrl = m3uUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedUrl.isEmpty, isValidUrl(trimmedUrl) else {
                        showUrlWarning = !isValidUrl(trimmedUrl)
                        return
                    }
                    isCheckingUrl = true
                    checkM3UUrl(trimmedUrl) { success in
                        isCheckingUrl = false
                        if success {
                            if let editing = editingStream, let idx = streams.firstIndex(of: editing) {
                                streams[idx].url = trimmedUrl
                                streams[idx].interval = updateInterval
                                editingStream = nil
                            } else {
                                let newStream = M3UStream(id: UUID(), url: trimmedUrl, interval: updateInterval)
                                streams.append(newStream)
                                streamToScan = newStream
                                showScanPrompt = true
                            }
                            m3uUrl = ""
                            updateInterval = .everyDay
                        } else {
                            showUrlError = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCheckingUrl || m3uUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isValidUrl(m3uUrl))
                .overlay(
                    Group {
                        if isCheckingUrl {
                            ProgressView().padding(.leading, 8)
                        }
                    }, alignment: .trailing
                )
            }
            .alert("URL Check Failed", isPresented: $showUrlError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Could not access the M3U URL. Please check your link and try again.")
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
    
    enum UpdateInterval: String, CaseIterable, Identifiable {
        case everyDay = "Every Day"
        case every3Days = "Every 3 Days"
        case everyWeek = "Every Week"
        var id: String { rawValue }
    }
    
    struct XtreamStream: Identifiable, Equatable {
        let id: UUID
        var name: String
        var serverUrl: String
        var username: String
        var password: String
        var interval: UpdateInterval
    }
    
    func checkXtreamConnection(server: String, user: String, pass: String, completion: @escaping (Bool) -> Void) {
        // Simulate async check (replace with real API call)
        isCheckingConnection = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isCheckingConnection = false
            // Simulate: fail if server contains "fail", succeed otherwise
            completion(!server.lowercased().contains("fail"))
        }
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
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Edit") {
                                name = stream.name
                                serverUrl = stream.serverUrl
                                username = stream.username
                                password = stream.password
                                updateInterval = stream.interval
                                editingStream = stream
                            }
                            .buttonStyle(.bordered)
                            Button("Refresh") {
                                print("Force reload for: \(stream.name) @ \(stream.serverUrl)")
                                // TODO: Call fetch/scan logic here
                            }
                            .buttonStyle(.borderedProminent)
                        }
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
                    isCheckingConnection = true
                    checkXtreamConnection(server: trimmedServer, user: trimmedUser, pass: password) { success in
                        isCheckingConnection = false
                        if success {
                            if let editing = editingStream, let idx = streams.firstIndex(of: editing) {
                                streams[idx].name = trimmedName
                                streams[idx].serverUrl = trimmedServer
                                streams[idx].username = trimmedUser
                                streams[idx].password = password
                                streams[idx].interval = updateInterval
                                editingStream = nil
                            } else {
                                let newStream = XtreamStream(id: UUID(), name: trimmedName, serverUrl: trimmedServer, username: trimmedUser, password: password, interval: updateInterval)
                                streams.append(newStream)
                                streamToScan = newStream
                                showScanPrompt = true
                            }
                            name = ""
                            serverUrl = ""
                            username = ""
                            password = ""
                            updateInterval = .everyDay
                        } else {
                            showConnectionError = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCheckingConnection || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || serverUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || !isValidUrl(serverUrl))
                .overlay(
                    Group {
                        if isCheckingConnection {
                            ProgressView().padding(.leading, 8)
                        }
                    }, alignment: .trailing
                )
            }
            .alert("Connection Failed", isPresented: $showConnectionError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Could not connect to the server. Please check your details and try again.")
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