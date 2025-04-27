import SwiftUI

struct EnginePrioritySettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var engineOrder: [PlayerEngine] = [.vlc, .ksplayer, .mpv, .apple]
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(engineOrder, id: \.self) { engine in
                        Text(engine.rawValue)
                    }
                    .onMove(perform: move)
                }
                .environment(\.editMode, .constant(.active))
                .navigationTitle("Engine Priority")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveOrder()
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .onAppear(perform: loadOrder)
        }
    }
    
    private func move(from source: IndexSet, to destination: Int) {
        engineOrder.move(fromOffsets: source, toOffset: destination)
    }
    
    private func saveOrder() {
        let orderStrings = engineOrder.map { $0.rawValue }
        UserDefaults.standard.set(orderStrings, forKey: "enginePriorityOrder")
    }
    
    private func loadOrder() {
        if let saved = UserDefaults.standard.array(forKey: "enginePriorityOrder") as? [String] {
            let engines = saved.compactMap { PlayerEngine(rawValue: $0) }
            if engines.count == 4 {
                engineOrder = engines
            }
        }
    }
} 