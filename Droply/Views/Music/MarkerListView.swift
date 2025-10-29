//
//  MarkerListView.swift
//  Droply
//
//  Created by Ahmed Khalaf on 10/29/25.
//

import SwiftUI

struct MarkerListView: View {
    let markers: [SongMarker]
    let onTap: (SongMarker) -> Void
    let onDelete: (SongMarker) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Markers")
                .font(.headline)
                .padding(.horizontal)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(markers) { marker in
                        MarkerRow(marker: marker)
                            .onTapGesture {
                                onTap(marker)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    onDelete(marker)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 200)
        }
    }
}

struct MarkerRow: View {
    let marker: SongMarker

    var body: some View {
        HStack {
            Text(marker.emoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                if let name = marker.name, !name.isEmpty {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                HStack(spacing: 8) {
                    Text(formatTime(marker.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    if marker.bufferTime > 0 {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("\(Int(marker.bufferTime))s buffer")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    MarkerListView(
        markers: [
            SongMarker(timestamp: 45, emoji: "🔥", name: "Drop", bufferTime: 5),
            SongMarker(timestamp: 90, emoji: "🎸", name: "Solo", bufferTime: 3),
            SongMarker(timestamp: 150, emoji: "💪", name: "Final push", bufferTime: 10)
        ],
        onTap: { _ in },
        onDelete: { _ in }
    )
    .padding()
    .background(Color.black)
}
