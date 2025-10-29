//
//  ContentView.swift
//  Droply
//
//  Created by Ahmed Khalaf on 10/29/25.
//

import SwiftUI
import SwiftData
import MusicKit

struct ContentView: View {
    @StateObject private var musicService = MusicKitService.shared
    @State private var showingAuthorization = false

    var body: some View {
        Group {
            switch musicService.authorizationStatus {
            case .authorized:
                NowPlayingView()
            case .denied, .restricted:
                authorizationDeniedView
            case .notDetermined:
                authorizationRequestView
            @unknown default:
                authorizationRequestView
            }
        }
        .task {
            await musicService.updateAuthorizationStatus()
        }
    }

    private var authorizationRequestView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Welcome to Droply")
                .font(.title)
                .fontWeight(.bold)

            Text("Mark your favorite moments in songs and cue them up instantly")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task {
                    let authorized = await musicService.requestAuthorization()
                    if !authorized {
                        showingAuthorization = true
                    }
                }
            } label: {
                Text("Connect to Apple Music")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .padding()
    }

    private var authorizationDeniedView: some View {
        ContentUnavailableView(
            "Apple Music Access Required",
            systemImage: "music.note.list",
            description: Text("Please enable Apple Music access in Settings to use this app")
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [MarkedSong.self, SongMarker.self], inMemory: true)
}
