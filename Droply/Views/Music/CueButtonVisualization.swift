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
    var meshColors: [Color]? // Optional mesh gradient colors from artwork
    var loopEnabled: Bool = false
    var loopDuration: Double = 0

    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Label
                Text("Drop in")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Spacer()

                // Buffer time with icon
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption)
                    Text(formatCueTime(cueTime))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white)

                // Loop indicator
                if loopEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "repeat")
                            .font(.caption)
                        Text(formatCueTime(loopDuration))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
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
                        if isActive {
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
                                            .pink.opacity(0.8),
                                            .purple.opacity(0.8),
                                            .blue.opacity(0.8),
                                            .cyan.opacity(0.8)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                }

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
                            .frame(width: max(1, geometry.size.width * CGFloat(progress)))
                            .animation(.linear, value: progress)
                            .shadow(color: .purple.opacity(0.5), radius: 8)
                            .onAppear {
                                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                                    shimmerOffset = 2
                                }
                            }
                        }
                    }
                    .mask(Capsule())
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
