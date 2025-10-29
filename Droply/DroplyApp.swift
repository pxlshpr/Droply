//
//  DroplyApp.swift
//  Droply
//
//  Created by Ahmed Khalaf on 10/29/25.
//

import SwiftUI
import SwiftData

@main
struct DroplyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MarkedSong.self,
            SongMarker.self,
        ])

        // Configure with CloudKit sync
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.ahmdrghb.droply")
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
