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
    let musicService: MusicKitService
    let onMarkerTap: (SongMarker) -> Void
    let onMarkerEdit: ((SongMarker) -> Void)?
    let onMarkerDelete: ((SongMarker) -> Void)?

    @State private var localDragTime: TimeInterval?

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
                            if localDragTime == nil {
                                // First drag event - notify service we're starting
                                musicService.startDragging()
                            }

                            let newTime = max(0, min((value.location.x / geometry.size.width) * duration, duration))
                            localDragTime = newTime
                            musicService.updateDragPosition(to: newTime)
                        }
                        .onEnded { _ in
                            if let finalTime = localDragTime {
                                Task {
                                    await musicService.endDragging(at: finalTime)
                                }
                            }
                            localDragTime = nil
                        }
                )
            }
        }
    }

    private func markerView(for marker: SongMarker, geometry: GeometryProxy) -> some View {
        let position = (marker.timestamp / duration) * geometry.size.width

        return VStack(spacing: 1) {
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
                .contextMenu {
                    if let onEdit = onMarkerEdit {
                        Button {
                            onEdit(marker)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }

                    if let onDelete = onMarkerDelete {
                        Button(role: .destructive) {
                            onDelete(marker)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

            Rectangle()
                .fill(.white)
                .frame(width: 2, height: 12)

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
        let timeToUse = localDragTime ?? currentTime
        return (timeToUse / duration) * totalWidth
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
        musicService: MusicKitService.shared,
        onMarkerTap: { _ in },
        onMarkerEdit: { _ in },
        onMarkerDelete: { _ in }
    )
    .frame(height: 120)
    .padding()
    .background(Color.black)
}
