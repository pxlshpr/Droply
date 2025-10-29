//
//  MarkerTimelineView.swift
//  Droply
//
//  Created by Ahmed Khalaf on 10/29/25.
//

import SwiftUI

struct MarkerTimelineView: View {
    let currentTime: TimeInterval
    let duration: TimeInterval
    let markers: [SongMarker]
    let onSeek: (TimeInterval) -> Void
    let onMarkerTap: (SongMarker) -> Void

    @State private var isDragging = false
    @State private var dragPosition: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                // Markers visualization
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.2))
                        .frame(height: 8)

                    // Progress bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.6))
                        .frame(
                            width: progressWidth(geometry.size.width),
                            height: 8
                        )

                    // Markers on timeline
                    ForEach(markers, id: \.id) { marker in
                        markerView(for: marker, geometry: geometry)
                    }

                    // Current position indicator
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .shadow(radius: 3)
                        .offset(x: progressWidth(geometry.size.width) - 8)
                }
                .frame(height: 40)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dragPosition = value.location.x
                            let newTime = (value.location.x / geometry.size.width) * duration
                            onSeek(max(0, min(newTime, duration)))
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
        }
    }

    private func markerView(for marker: SongMarker, geometry: GeometryProxy) -> some View {
        let position = (marker.timestamp / duration) * geometry.size.width

        return VStack(spacing: 2) {
            Text(marker.emoji)
                .font(.title3)
                .background(
                    Circle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 32, height: 32)
                )
                .onTapGesture {
                    onMarkerTap(marker)
                }

            Rectangle()
                .fill(.white)
                .frame(width: 2, height: 20)

            if marker.bufferTime > 0 {
                // Show buffer indicator
                let bufferWidth = (marker.bufferTime / duration) * geometry.size.width
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: bufferWidth, height: 4)
                    .offset(x: -bufferWidth / 2)
            }
        }
        .offset(x: position - 16)
    }

    private func progressWidth(_ totalWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return (currentTime / duration) * totalWidth
    }
}

#Preview {
    MarkerTimelineView(
        currentTime: 30,
        duration: 180,
        markers: [
            SongMarker(timestamp: 45, emoji: "🔥", name: "Drop", bufferTime: 5),
            SongMarker(timestamp: 90, emoji: "🎸", name: "Solo", bufferTime: 3),
            SongMarker(timestamp: 150, emoji: "💪", name: "Final push", bufferTime: 10)
        ],
        onSeek: { _ in },
        onMarkerTap: { _ in }
    )
    .frame(height: 120)
    .padding()
    .background(Color.black)
}
