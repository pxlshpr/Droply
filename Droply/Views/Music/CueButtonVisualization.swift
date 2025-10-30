//
//  CueButtonVisualization.swift
//  Droply
//
//  Created by Claude Code on 10/30/25.
//

import SwiftUI

struct CueButtonVisualization: View {
    let progress: Double // 0.0 to 1.0
    let cueTime: Double
    let isActive: Bool
    let onTap: () -> Void

    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        Button(action: onTap) {
            HStack {
                // Label
                Text("Cue Time")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Spacer()

                // Value with icon
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                    Text(formatCueTime(cueTime))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.15))

                        // Progress fill with sparkly gradient
                        if isActive && progress > 0 {
                            ZStack {
                                // Main gradient fill
                                LinearGradient(
                                    colors: [
                                        .pink.opacity(0.8),
                                        .purple.opacity(0.8),
                                        .blue.opacity(0.8),
                                        .cyan.opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )

                                // Shimmer effect overlay
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

                                // Sparkle particles
                                Canvas { context, size in
                                    let particleCount = 8
                                    for i in 0..<particleCount {
                                        let x = (CGFloat(i) / CGFloat(particleCount)) * size.width * CGFloat(progress)
                                        let y = size.height / 2 + sin(shimmerOffset * 10 + CGFloat(i)) * 5
                                        let opacity = (sin(shimmerOffset * 5 + CGFloat(i)) + 1) / 2

                                        context.opacity = opacity * 0.6
                                        context.fill(
                                            Circle().path(in: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)),
                                            with: .color(.white)
                                        )
                                    }
                                }
                            }
                            .frame(width: geometry.size.width * CGFloat(progress))
                            .animation(.linear, value: progress)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .purple.opacity(0.5), radius: 8)
                            .onAppear {
                                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                                    shimmerOffset = 2
                                }
                            }
                        }
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    private func formatCueTime(_ seconds: Double) -> String {
        if seconds == 0 {
            return "0s"
        } else if seconds < 60 {
            return "\(Int(seconds))s"
        } else {
            let minutes = Int(seconds / 60)
            return "\(minutes)m"
        }
    }
}

#Preview("Inactive") {
    CueButtonVisualization(
        progress: 0,
        cueTime: 5.0,
        isActive: false,
        onTap: {}
    )
    .padding()
    .background(Color.black)
}

#Preview("25% Progress") {
    CueButtonVisualization(
        progress: 0.25,
        cueTime: 5.0,
        isActive: true,
        onTap: {}
    )
    .padding()
    .background(Color.black)
}

#Preview("75% Progress") {
    CueButtonVisualization(
        progress: 0.75,
        cueTime: 10.0,
        isActive: true,
        onTap: {}
    )
    .padding()
    .background(Color.black)
}
