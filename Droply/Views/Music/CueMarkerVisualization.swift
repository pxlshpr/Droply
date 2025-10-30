//
//  CueMarkerVisualization.swift
//  Droply
//
//  Created by Claude Code on 10/30/25.
//

import SwiftUI

struct CueMarkerVisualization: View {
    let marker: SongMarker
    let progress: Double // 0.0 to 1.0
    let isActive: Bool
    let onTap: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        Button(action: onTap) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )

                    // Progress fill with sparkly gradient
                    if isActive && progress > 0 {
                        ZStack {
                            // Main gradient fill
                            LinearGradient(
                                colors: [
                                    .pink.opacity(0.9),
                                    .purple.opacity(0.9),
                                    .blue.opacity(0.9),
                                    .cyan.opacity(0.9)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )

                            // Shimmer effect overlay
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .white.opacity(0.4),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .offset(x: shimmerOffset * geometry.size.width)

                            // Sparkle particles
                            Canvas { context, size in
                                let particleCount = 6
                                for i in 0..<particleCount {
                                    let x = (CGFloat(i) / CGFloat(particleCount)) * size.width * CGFloat(progress)
                                    let y = size.height / 2 + sin(shimmerOffset * 10 + CGFloat(i)) * 3
                                    let opacity = (sin(shimmerOffset * 5 + CGFloat(i)) + 1) / 2

                                    context.opacity = opacity * 0.6
                                    context.fill(
                                        Circle().path(in: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)),
                                        with: .color(.white)
                                    )
                                }
                            }
                        }
                        .frame(width: geometry.size.width * CGFloat(progress))
                        .clipShape(Capsule())
                        .shadow(color: .purple.opacity(0.6), radius: 6)
                        .onAppear {
                            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                shimmerOffset = 2
                            }
                        }
                    }

                    // Content
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
                }
            }
            .frame(height: 32)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onEdit = onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// ScrollViewReader helper for auto-scrolling
struct HorizontalMarkerStripWithAutoScroll: View {
    let markers: [SongMarker]
    let activeMarker: SongMarker?
    let progress: Double
    let onTap: (SongMarker) -> Void
    let onMarkerEdit: ((SongMarker) -> Void)?
    let onMarkerDelete: ((SongMarker) -> Void)?

    @State private var hasScrolledToActive = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if markers.isEmpty {
                        // Placeholder when no markers
                        Text("No markers yet")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 8)
                    } else {
                        // Existing markers
                        ForEach(markers) { marker in
                            let isActive = activeMarker?.id == marker.id

                            if isActive {
                                CueMarkerVisualization(
                                    marker: marker,
                                    progress: progress,
                                    isActive: true,
                                    onTap: { onTap(marker) },
                                    onEdit: onMarkerEdit != nil ? { onMarkerEdit?(marker) } : nil,
                                    onDelete: onMarkerDelete != nil ? { onMarkerDelete?(marker) } : nil
                                )
                                .id(marker.id)
                            } else {
                                MarkerPill(
                                    marker: marker,
                                    onEdit: onMarkerEdit,
                                    onDelete: onMarkerDelete
                                )
                                .onTapGesture {
                                    onTap(marker)
                                }
                                .id(marker.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .onChange(of: activeMarker?.id) { _, newMarkerID in
                if let markerID = newMarkerID {
                    hasScrolledToActive = false
                    // Small delay to ensure the marker is visible before scrolling
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            proxy.scrollTo(markerID, anchor: .center)
                        }
                        hasScrolledToActive = true
                    }
                }
            }
        }
    }
}

#Preview("Inactive Marker") {
    CueMarkerVisualization(
        marker: SongMarker(timestamp: 45, emoji: "🔥", name: "Drop"),
        progress: 0,
        isActive: false,
        onTap: {},
        onEdit: {},
        onDelete: {}
    )
    .padding()
    .frame(width: 120)
    .background(Color.black)
}

#Preview("Active Marker - 50%") {
    CueMarkerVisualization(
        marker: SongMarker(timestamp: 45, emoji: "🔥", name: "Drop"),
        progress: 0.5,
        isActive: true,
        onTap: {},
        onEdit: {},
        onDelete: {}
    )
    .padding()
    .frame(width: 120)
    .background(Color.black)
}

#Preview("Horizontal Strip with Active") {
    HorizontalMarkerStripWithAutoScroll(
        markers: [
            SongMarker(timestamp: 45, emoji: "🔥", name: "Drop"),
            SongMarker(timestamp: 90, emoji: "🎸", name: "Solo"),
            SongMarker(timestamp: 150, emoji: "💪", name: "Final push"),
            SongMarker(timestamp: 200, emoji: "🎹", name: "Bridge")
        ],
        activeMarker: SongMarker(timestamp: 150, emoji: "💪", name: "Final push"),
        progress: 0.6,
        onTap: { _ in },
        onMarkerEdit: { _ in },
        onMarkerDelete: { _ in }
    )
    .frame(height: 60)
    .background(Color.black)
}
