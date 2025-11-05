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
                        Text(formatCueTime(time))
                            .font(.callout)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    .font(.callout)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(20)
        .frame(width: 320)
        .presentationCompactAdaptation(.popover)
    }

    private func handleSelection(_ time: TimeInterval) {
        // Haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()

        // Dismiss and perform action
        dismiss()
        onSelect(time)
    }

    private func formatCueTime(_ seconds: TimeInterval) -> String {
        if seconds == 0 {
            return "0s"
        } else if seconds < 60 {
            return "\(Int(seconds))s"
        } else {
            let minutes = Int(seconds / 60)
            let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
            if remainingSeconds == 0 {
                return "\(minutes)m"
            } else {
                return "\(minutes)m \(remainingSeconds)s"
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
        }
    )
}
