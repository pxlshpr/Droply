//
//  BufferTimeSelectionPopover.swift
//  Droply
//
//  Created for PXL-544: Per-action buffer time selection
//

import SwiftUI

struct BufferTimeSelectionPopover: View {
    let onSelect: (TimeInterval) -> Void
    let onEditDrop: () -> Void
    let backgroundColor1: Color
    let backgroundColor2: Color
    @Environment(\.dismiss) private var dismiss

    // Buffer time options in seconds
    private let bufferTimeOptions: [Double] = [0, 5, 10, 15, 30, 45, 60, 90, 120]

    // Grid layout configuration
    private let columns = [
        GridItem(.adaptive(minimum: 70, maximum: 90), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Buffer Time")
                .font(.headline)
                .foregroundStyle(.secondary)

            // Grid of buffer time options
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(bufferTimeOptions, id: \.self) { time in
                    Button {
                        handleSelection(time)
                    } label: {
                        formatCueTimeLabel(time)
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                }
            }

            Divider()
                .padding(.vertical, 4)

            // Edit Drop button (secondary action)
            Button {
                dismiss()
                onEditDrop()
            } label: {
                Label("Edit Drop", systemImage: "pencil")
                    .font(.body)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .buttonBorderShape(.roundedRectangle(radius: 16))
        }
        .padding(20)
        .frame(width: 320)
        .presentationCompactAdaptation(.popover)
        .background(
            LinearGradient(
                colors: [backgroundColor1, backgroundColor2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func handleSelection(_ time: TimeInterval) {
        // Haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()

        // Dismiss and perform action
        dismiss()
        onSelect(time)
    }

    @ViewBuilder
    private func formatCueTimeLabel(_ seconds: TimeInterval) -> some View {
        if seconds == 0 {
            Text("0s")
                .font(.title2)
                .fontWeight(.semibold)
        } else if seconds < 60 {
            Text("\(Int(seconds))s")
                .font(.title2)
                .fontWeight(.semibold)
        } else {
            let minutes = Int(seconds / 60)
            let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
            if remainingSeconds == 0 {
                Text("\(minutes)m")
                    .font(.title2)
                    .fontWeight(.semibold)
            } else {
                VStack(spacing: 0) {
                    Text("\(minutes)m")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("\(remainingSeconds)s")
                        .font(.callout)
                        .fontWeight(.medium)
                        .opacity(0.75)
                }
            }
        }
    }
}

#Preview {
    BufferTimeSelectionPopover(
        onSelect: { time in
            print("Selected: \(time)s")
        },
        onEditDrop: {
            print("Edit drop tapped")
        },
        backgroundColor1: .blue,
        backgroundColor2: .purple
    )
}
