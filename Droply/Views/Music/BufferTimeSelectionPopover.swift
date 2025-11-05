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
                .foregroundStyle(.white.opacity(0.7))

            // Grid of buffer time options
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(bufferTimeOptions, id: \.self) { time in
                    Button {
                        handleSelection(time)
                    } label: {
                        formatCueTimeLabel(time)
//                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
                    }
                    .buttonStyle(.glass)
//                    .glassEffect(.regular.interactive().tint(Color.accentColor), in: RoundedRectangle(cornerRadius: 10))
//                    .buttonStyle(.glassProminent)
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
                    .frame(height: 44)
            }
            .buttonStyle(.glass)
        }
        .padding(20)
        .frame(width: 320)
        .presentationCompactAdaptation(.popover)
    }

    private func handleSelection(_ time: TimeInterval) {
        // Immediate rigid haptic feedback - fires before any other code
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        // Small delay to ensure haptic completes before dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Dismiss and perform action
            dismiss()
            onSelect(time)
        }
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
                VStack(spacing: 1) {
                    Text("\(minutes)m")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                    Text("\(remainingSeconds)s")
                        .font(.callout)
                        .fontWeight(.medium)
                        .opacity(0.75)
                }
                .frame(maxWidth: .infinity)
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
