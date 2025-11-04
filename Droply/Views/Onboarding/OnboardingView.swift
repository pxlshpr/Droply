//
//  OnboardingView.swift
//  Droply
//
//  Created by Ahmed Khalaf on 11/04/25.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    private let totalPages = 4

    var body: some View {
        VStack {
            // Progress indicators
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentPage ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .animation(.easeInOut, value: currentPage)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            // Content pages
            TabView(selection: $currentPage) {
                welcomePage
                    .tag(0)

                markingSongsPage
                    .tag(1)

                cueTimePage
                    .tag(2)

                appleMusicPage
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Navigation buttons
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button(currentPage == totalPages - 1 ? "Get Started" : "Next") {
                    if currentPage == totalPages - 1 {
                        hasSeenOnboarding = true
                        dismiss()
                    } else {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                }
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
            }
            .padding()
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Page Views

    private var welcomePage: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "waveform")
                .font(.system(size: 100))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Text("Welcome to Droply")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Mark your favorite moments in songs and drop in instantly")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }

    private var markingSongsPage: some View {
        VStack(spacing: 30) {
            Spacer()

            // Illustration of marking songs
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.blue.opacity(0.1))
                    .frame(width: 280, height: 280)

                VStack(spacing: 20) {
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)

                    Image(systemName: "arrow.down")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(0..<3) { _ in
                            Circle()
                                .fill(.blue)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
            }

            VStack(spacing: 12) {
                Text("Mark Key Moments")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Play any song and tap to add markers at your favorite parts - the chorus, a sick drop, or any moment you want to remember")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }

    private var cueTimePage: some View {
        VStack(spacing: 30) {
            Spacer()

            // Illustration of cue time
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.purple.opacity(0.1))
                    .frame(width: 280, height: 280)

                VStack(spacing: 30) {
                    // Timeline illustration
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(.gray.opacity(0.3))
                            .frame(width: 100, height: 4)

                        Circle()
                            .fill(.purple)
                            .frame(width: 16, height: 16)

                        Rectangle()
                            .fill(.gray.opacity(0.3))
                            .frame(width: 100, height: 4)
                    }

                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 60))
                        .foregroundStyle(.purple)

                    Text("5s")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.purple)
                }
            }

            VStack(spacing: 12) {
                Text("Drop In at the Perfect Time")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Set a cue time for each marker. When you play a marked song, it'll start a few seconds before your marker so you drop in right at the moment")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }

    private var appleMusicPage: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "apple.logo")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.pink, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "music.note")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            VStack(spacing: 12) {
                Text("Connect Apple Music")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Droply works with your Apple Music library and subscription to play your marked songs")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
