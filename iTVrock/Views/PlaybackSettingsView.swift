import SwiftUI

enum PlayerEngine: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case vlc = "VLC"
    case ksplayer = "KSPlayer"
    case mpv = "MPV"
    case apple = "Apple"
    case cancel = "Cancel"
    
    var id: String { self.rawValue }
}

struct PlaybackSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedEngine: PlayerEngine = {
        if let saved = UserDefaults.standard.string(forKey: "selectedPlayerEngine"),
           let engine = PlayerEngine(rawValue: saved) {
            return engine
        }
        return .auto
    }()
    
    var body: some View {
        NavigationView {
            List(PlayerEngine.allCases.filter { $0 != .cancel }, id: \.self) { engine in
                Button(action: {
                    selectedEngine = engine
                }) {
                    HStack {
                        Text(engine.rawValue)
                        Spacer()
                        if selectedEngine == engine {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle("Player Engine")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    UserDefaults.standard.set(selectedEngine.rawValue, forKey: "selectedPlayerEngine")
                    dismiss()
                }
            )
        }
    }
} 