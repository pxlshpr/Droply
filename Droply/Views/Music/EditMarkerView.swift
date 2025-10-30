//
//  EditMarkerView.swift
//  Droply
//
//  Created by Ahmed Khalaf on 10/30/25.
//

import SwiftUI
import SwiftData

struct EditMarkerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var musicService = MusicKitService.shared

    let marker: SongMarker

    @State private var selectedEmoji: String
    @State private var markerName: String
    @State private var timestamp: TimeInterval

    private let commonEmojis = [
        "🎵", "🔥", "💪", "🎸", "🎹", "🥁",
        "🎤", "🎧", "⚡️", "💥", "🌟", "✨",
        "🚀", "🎯", "💯", "👊", "🙌", "🎉"
    ]

    init(marker: SongMarker) {
        self.marker = marker
        _selectedEmoji = State(initialValue: marker.emoji)
        _markerName = State(initialValue: marker.name ?? "")
        _timestamp = State(initialValue: marker.timestamp)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Position")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(formatTime(timestamp))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                    }

                    Section("Emoji") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                            ForEach(commonEmojis, id: \.self) { emoji in
                                Text(emoji)
                                    .font(.largeTitle)
                                    .frame(width: 50, height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedEmoji == emoji ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                                    .onTapGesture {
                                        selectedEmoji = emoji
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Section("Name (Optional)") {
                        TextField("e.g., Drop, Solo, Final push", text: $markerName)
                    }

                    // Spacer to make room for floating buttons
                    Section {
                        Color.clear
                            .frame(height: 120)
                    }
                }

                // Floating buttons
                VStack(spacing: 12) {
                    Spacer()

                    seekButtons
                    saveButton
                }
            }
            .navigationTitle("Edit Marker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Button Views

    private var seekButtons: some View {
        HStack(spacing: 12) {
            seekButton(systemName: "gobackward.15", label: "15s", offset: -15)
            seekButton(systemName: "gobackward.5", label: "5s", offset: -5)
            seekButton(systemName: "goforward.5", label: "5s", offset: 5)
            seekButton(systemName: "goforward.15", label: "15s", offset: 15)
        }
        .padding(.horizontal, 20)
    }

    private func seekButton(systemName: String, label: String, offset: TimeInterval) -> some View {
        Button {
            Task {
                let newTime: TimeInterval
                if offset < 0 {
                    newTime = max(0, musicService.playbackTime + offset)
                } else {
                    newTime = min(musicService.playbackDuration, musicService.playbackTime + offset)
                }
                await musicService.seek(to: newTime)
                timestamp = newTime
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemName)
                    .font(.title2)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.glass)
    }

    private var saveButton: some View {
        Button(action: saveChanges) {
            Text("Save Changes")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.glassProminent)
        .disabled(selectedEmoji.isEmpty)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Helper Methods

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func saveChanges() {
        marker.emoji = selectedEmoji
        marker.name = markerName.isEmpty ? nil : markerName
        marker.timestamp = timestamp

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: MarkedSong.self, SongMarker.self, configurations: config)

    let marker = SongMarker(timestamp: 45.5, emoji: "🔥", name: "Drop")
    container.mainContext.insert(marker)

    return EditMarkerView(marker: marker)
        .modelContainer(container)
}
