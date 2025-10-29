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
                .foregroundStyle(.white)
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
                        .foregroundStyle(.white)
                }

                Text(formatTime(marker.timestamp))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.15))
        )
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct HorizontalMarkerStrip: View {
    let markers: [SongMarker]
    let onTap: (SongMarker) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(markers) { marker in
                    MarkerPill(marker: marker)
                        .onTapGesture {
                            onTap(marker)
                        }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct MarkerPill: View {
    let marker: SongMarker

    var body: some View {
        HStack(spacing: 6) {
            Text(marker.emoji)
                .font(.body)

            Text(formatTime(marker.timestamp))
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.white.opacity(0.2))
        )
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.3), lineWidth: 1)
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
            SongMarker(timestamp: 45, emoji: "🔥", name: "Drop"),
            SongMarker(timestamp: 90, emoji: "🎸", name: "Solo"),
            SongMarker(timestamp: 150, emoji: "💪", name: "Final push")
        ],
        onTap: { _ in },
        onDelete: { _ in }
    )
    .padding()
    .background(Color.black)
}

#Preview("Horizontal Strip") {
    HorizontalMarkerStrip(
        markers: [
            SongMarker(timestamp: 45, emoji: "🔥", name: "Drop"),
            SongMarker(timestamp: 90, emoji: "🎸", name: "Solo"),
            SongMarker(timestamp: 150, emoji: "💪", name: "Final push"),
            SongMarker(timestamp: 200, emoji: "🎹", name: "Bridge")
        ],
        onTap: { _ in }
    )
    .padding()
    .background(Color.black)
}
