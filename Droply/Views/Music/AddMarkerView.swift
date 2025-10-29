//
//  AddMarkerView.swift
//  Droply
//
//  Created by Ahmed Khalaf on 10/29/25.
//

import SwiftUI
import SwiftData

struct AddMarkerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let currentTime: TimeInterval
    let markedSong: MarkedSong

    @State private var selectedEmoji = "🎵"
    @State private var markerName = ""
    @State private var bufferTime: Double = 0

    private let commonEmojis = [
        "🎵", "🔥", "💪", "🎸", "🎹", "🥁",
        "🎤", "🎧", "⚡️", "💥", "🌟", "✨",
        "🚀", "🎯", "💯", "👊", "🙌", "🎉"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Position")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(formatTime(currentTime))
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

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Buffer Time")
                            Spacer()
                            Text("\(Int(bufferTime))s")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Slider(value: $bufferTime, in: 0...30, step: 1)

                        Text("Start playback \(Int(bufferTime)) seconds before the marker")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Buffer Time")
                } footer: {
                    Text("Perfect for setting up before a big moment - like getting in position for a lift or preparing for a difficult section")
                }

                Section {
                    Button(action: saveMarker) {
                        HStack {
                            Spacer()
                            Text("Save Marker")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(selectedEmoji.isEmpty)
                }
            }
            .navigationTitle("Add Marker")
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

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func saveMarker() {
        let marker = SongMarker(
            timestamp: currentTime,
            emoji: selectedEmoji,
            name: markerName.isEmpty ? nil : markerName,
            bufferTime: bufferTime
        )

        marker.song = markedSong
        modelContext.insert(marker)

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: MarkedSong.self, SongMarker.self, configurations: config)

    let song = MarkedSong(
        appleMusicID: "123",
        title: "Test Song",
        artist: "Test Artist",
        duration: 180
    )
    container.mainContext.insert(song)

    return AddMarkerView(currentTime: 45.5, markedSong: song)
        .modelContainer(container)
}
