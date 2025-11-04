//
//  DroplyApp.swift
//  Droply
//
//  Created by Ahmed Khalaf on 10/29/25.
//

import SwiftUI
import SwiftData

enum ModelContainerError: LocalizedError {
    case cloudKitUnavailable(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .cloudKitUnavailable(let error):
            return "iCloud is unavailable. Please check your iCloud settings and internet connection.\n\nError: \(error.localizedDescription)"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

enum ContainerState {
    case loading
    case ready(ModelContainer)
    case failed(ModelContainerError)
}

@main
struct DroplyApp: App {
    @State private var containerState: ContainerState = .loading

    private static let schema = Schema([
        MarkedSong.self,
        SongMarker.self,
    ])

    var body: some Scene {
        WindowGroup {
            Group {
                switch containerState {
                case .loading:
                    LoadingView()
                case .ready(let container):
                    ContentView()
                        .modelContainer(container)
                case .failed(let error):
                    ErrorView(error: error, onRetry: initializeContainer, onUseFallback: useFallbackStorage)
                }
            }
            .task {
                initializeContainer()
            }
        }
    }

    private func initializeContainer() {
        containerState = .loading

        // Configure with CloudKit sync
        let cloudKitConfiguration = ModelConfiguration(
            schema: Self.schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.ahmdrghb.droply")
        )

        do {
            let container = try ModelContainer(for: Self.schema, configurations: [cloudKitConfiguration])
            containerState = .ready(container)
        } catch {
            // Check if this is a CloudKit/iCloud error
            let nsError = error as NSError
            if nsError.domain.contains("CloudKit") || nsError.domain.contains("iCloud") {
                containerState = .failed(.cloudKitUnavailable(error))
            } else {
                containerState = .failed(.unknown(error))
            }
        }
    }

    private func useFallbackStorage() {
        // Configure with in-memory storage as fallback
        let fallbackConfiguration = ModelConfiguration(
            schema: Self.schema,
            isStoredInMemoryOnly: true
        )

        do {
            let container = try ModelContainer(for: Self.schema, configurations: [fallbackConfiguration])
            containerState = .ready(container)
        } catch {
            // If even in-memory storage fails, show error
            containerState = .failed(.unknown(error))
        }
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Initializing...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Error View
struct ErrorView: View {
    let error: ModelContainerError
    let onRetry: () -> Void
    let onUseFallback: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.icloud.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Storage Error")
                .font(.title.bold())

            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Button(action: onRetry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button(action: onUseFallback) {
                    VStack(spacing: 4) {
                        Label("Continue Without iCloud", systemImage: "play.circle")
                        Text("Data will not sync across devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}
