//
//  iTVrockApp.swift
//  iTVrock
//
//  Created by Ron Vaisman on 25/04/2025.
//

import SwiftUI

@main
struct iTVrockApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
