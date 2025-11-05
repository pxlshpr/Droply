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
    var meshColors: [Color]? // Optional mesh gradient colors from artwork
    var showBufferTimePopover: Binding<Bool>? // Binding to control popover visibility
    var bufferTimePopoverContent: (() -> AnyView)? // Content for the popover

    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onTap()
        }) {
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
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background capsule
                        Capsule()
                            .fill(.white.opacity(0.2))
                            .overlay(
                                Capsule()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )

                        // Progress fill with mesh gradient or fallback
                        if isActive && progress > 0 {
                            ZStack {
                                // Use mesh gradient if available and iOS 18+
                                if #available(iOS 18.0, *), let meshColors = meshColors {
                                    AnimatedMeshGradient(
                                        colors: meshColors,
                                        progress: progress,
                                        isAnimated: true
                                    )
                                } else {
                                    // Fallback linear gradient
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
                                }

                                // Subtle shimmer effect overlay
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        .white.opacity(0.3),
                                        .clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .offset(x: shimmerOffset * geometry.size.width)
                            }
                            .frame(width: geometry.size.width * CGFloat(progress))
                            .animation(.linear, value: progress)
                            .clipShape(Capsule())
                            .shadow(color: .purple.opacity(0.6), radius: 6)
                            .onAppear {
                                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                    shimmerOffset = 2
                                }
                            }
                        }
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: showBufferTimePopover ?? .constant(false)) {
            if let content = bufferTimePopoverContent {
                content()
            }
        }
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
    var meshColors: [Color]? // Optional mesh gradient colors from artwork
    var showBufferTimePopover: Binding<Bool>? // Binding to control popover visibility
    var markerForPopover: Binding<SongMarker?>? // Which marker the popover is for
    var bufferTimePopoverContent: ((SongMarker) -> AnyView)? // Content for the popover

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
                            let shouldShowPopover = Binding<Bool>(
                                get: { showBufferTimePopover?.wrappedValue == true && markerForPopover?.wrappedValue?.id == marker.id },
                                set: { newValue in
                                    showBufferTimePopover?.wrappedValue = newValue
                                    if !newValue {
                                        markerForPopover?.wrappedValue = nil
                                    }
                                }
                            )

                            if isActive {
                                CueMarkerVisualization(
                                    marker: marker,
                                    progress: progress,
                                    isActive: true,
                                    onTap: { onTap(marker) },
                                    onEdit: onMarkerEdit != nil ? { onMarkerEdit?(marker) } : nil,
                                    onDelete: onMarkerDelete != nil ? { onMarkerDelete?(marker) } : nil,
                                    meshColors: meshColors,
                                    showBufferTimePopover: shouldShowPopover,
                                    bufferTimePopoverContent: bufferTimePopoverContent.map { content in
                                        { content(marker) }
                                    }
                                )
                                .id(marker.id)
                            } else {
                                MarkerPill(
                                    marker: marker,
                                    onEdit: onMarkerEdit,
                                    onDelete: onMarkerDelete,
                                    showBufferTimePopover: shouldShowPopover,
                                    bufferTimePopoverContent: bufferTimePopoverContent.map { content in
                                        { content(marker) }
                                    }
                                )
                                .onTapGesture {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
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
