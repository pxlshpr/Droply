//
//  MarqueeText.swift
//  Droply
//
//  Created by Ahmed Khalaf on 11/2/25.
//

import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    let spacing: CGFloat = 30

    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var shouldAnimate = false

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: spacing) {
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize()
                    .background(
                        GeometryReader { textGeometry in
                            Color.clear
                                .onAppear {
                                    textWidth = textGeometry.size.width
                                    containerWidth = geometry.size.width
                                    shouldAnimate = textWidth > containerWidth
                                }
                                .onChange(of: geometry.size.width) { _, newWidth in
                                    containerWidth = newWidth
                                    shouldAnimate = textWidth > containerWidth
                                }
                        }
                    )

                if shouldAnimate {
                    Text(text)
                        .font(font)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .offset(x: shouldAnimate ? offset : 0)
            .onAppear {
                if shouldAnimate {
                    startAnimation()
                }
            }
            .onChange(of: shouldAnimate) { _, newValue in
                if newValue {
                    startAnimation()
                } else {
                    offset = 0
                }
            }
            .onChange(of: text) { _, _ in
                offset = 0
                if shouldAnimate {
                    startAnimation()
                }
            }
        }
    }

    private func startAnimation() {
        let totalWidth = textWidth + spacing

        withAnimation(
            .linear(duration: Double(totalWidth / 30))
            .repeatForever(autoreverses: false)
        ) {
            offset = -totalWidth
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        MarqueeText(
            text: "This is a very long song title that should scroll across the screen",
            font: .headline
        )
        .frame(width: 200)
        .padding()
        .background(.ultraThinMaterial)

        MarqueeText(
            text: "Short Title",
            font: .headline
        )
        .frame(width: 200)
        .padding()
        .background(.ultraThinMaterial)
    }
}
