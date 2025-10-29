//
//  ColorExtractor.swift
//  Droply
//
//  Created by Ahmed Khalaf on 10/29/25.
//

import UIKit
import CoreImage
import OSLog
import DominantColors

/// Utility for extracting dominant colors from images for dynamic backgrounds
struct ColorExtractor {
    private static let logger = Logger(subsystem: "com.droply.app", category: "ColorExtraction")

    /// Extract two dominant colors from an image and ensure they're dark enough for white text
    static func extractColors(from image: UIImage) async -> (color1: UIColor, color2: UIColor)? {
        logger.debug("Starting color extraction from image")

        return await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                guard let cgImage = image.cgImage ?? image.preparingForDisplay()?.cgImage else {
                    logger.error("Failed to get CGImage from UIImage")
                    continuation.resume(returning: nil)
                    return
                }

                logger.debug("CGImage obtained, dimensions: \(cgImage.width)x\(cgImage.height)")

                // Try DominantColors first (using .fair quality for good balance)
                logger.debug("Attempting DominantColors extraction with .fair quality")
                if let cgColors = try? DominantColors.dominantColors(image: cgImage, quality: .fair),
                   !cgColors.isEmpty {
                    logger.debug("DominantColors succeeded, extracted \(cgColors.count) colors")

                    // Convert to UIColors (ensure sRGB space)
                    let uiColors: [UIColor] = cgColors.compactMap { cg in
                        if let srgb = cg.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: CGColorRenderingIntent.defaultIntent, options: nil) {
                            return UIColor(cgColor: srgb)
                        } else {
                            return UIColor(cgColor: cg)
                        }
                    }

                    if let first = uiColors.first {
                        let second = uiColors.count > 1 ? uiColors[1] : first
                        let darkened1 = ensureDarkEnough(first)
                        let darkened2 = ensureDarkEnough(second)
                        logger.debug("DominantColors extraction successful")
                        continuation.resume(returning: (darkened1, darkened2))
                        return
                    }
                }

                // Fallback to k-means if DominantColors fails
                logger.debug("DominantColors failed, attempting k-means fallback")
                if let colors = kmeansTwoColors(from: cgImage) {
                    logger.debug("K-means extraction successful")
                    let darkened1 = ensureDarkEnough(colors.0)
                    let darkened2 = ensureDarkEnough(colors.1)
                    continuation.resume(returning: (darkened1, darkened2))
                    return
                }

                // Final fallback to Core Image
                logger.debug("K-means failed, using Core Image fallback")
                if let colors = coreImageTwoColors(from: cgImage) {
                    logger.debug("Core Image extraction successful")
                    let darkened1 = ensureDarkEnough(colors.0)
                    let darkened2 = ensureDarkEnough(colors.1 ?? colors.0)
                    continuation.resume(returning: (darkened1, darkened2))
                    return
                }

                logger.error("All color extraction methods failed")
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - K-Means Extraction

    private static func kmeansTwoColors(from cgImage: CGImage) -> (UIColor, UIColor)? {
        // Downscale for performance
        let targetSize = 64
        guard let resized = resizeCGImage(cgImage, to: CGSize(width: targetSize, height: targetSize)) else {
            return nil
        }

        guard let data = rgba8Data(from: resized) else {
            return nil
        }

        let pixelCount = data.count / 4
        if pixelCount == 0 { return nil }

        // Prepare samples (RGB only)
        var samples = [Float](repeating: 0, count: pixelCount * 3)
        for i in 0..<pixelCount {
            let r = Float(data[i*4 + 0]) / 255.0
            let g = Float(data[i*4 + 1]) / 255.0
            let b = Float(data[i*4 + 2]) / 255.0
            samples[i*3 + 0] = r
            samples[i*3 + 1] = g
            samples[i*3 + 2] = b
        }

        // Initialize two centroids
        var c1 = SIMD3<Float>(samples[0], samples[1], samples[2])
        var c2 = SIMD3<Float>(samples[pixelCount*3/2], samples[pixelCount*3/2 + 1], samples[pixelCount*3/2 + 2])

        // K-means iterations
        let maxIterations = 10
        for _ in 0..<maxIterations {
            var sum1 = SIMD3<Float>(0, 0, 0)
            var sum2 = SIMD3<Float>(0, 0, 0)
            var count1: Int = 0
            var count2: Int = 0

            for i in 0..<pixelCount {
                let p = SIMD3<Float>(samples[i*3 + 0], samples[i*3 + 1], samples[i*3 + 2])
                let d1 = distanceSquared(p, c1)
                let d2 = distanceSquared(p, c2)
                if d1 <= d2 {
                    sum1 += p
                    count1 += 1
                } else {
                    sum2 += p
                    count2 += 1
                }
            }

            // Avoid empty clusters
            if count1 == 0 || count2 == 0 {
                c1 = SIMD3<Float>(samples[0], samples[1], samples[2])
                c2 = SIMD3<Float>(samples[(pixelCount-1)*3], samples[(pixelCount-1)*3 + 1], samples[(pixelCount-1)*3 + 2])
                continue
            }

            let newC1 = sum1 / Float(count1)
            let newC2 = sum2 / Float(count2)

            // Check convergence
            if (distanceSquared(newC1, c1) + distanceSquared(newC2, c2)) < 1e-6 {
                c1 = newC1
                c2 = newC2
                break
            }
            c1 = newC1
            c2 = newC2
        }

        let color1 = UIColor(red: CGFloat(clamp01(c1.x)), green: CGFloat(clamp01(c1.y)), blue: CGFloat(clamp01(c1.z)), alpha: 1)
        let color2 = UIColor(red: CGFloat(clamp01(c2.x)), green: CGFloat(clamp01(c2.y)), blue: CGFloat(clamp01(c2.z)), alpha: 1)
        return (color1, color2)
    }

    private static func distanceSquared(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let d = a - b
        return d.x*d.x + d.y*d.y + d.z*d.z
    }

    private static func clamp01(_ v: Float) -> Float {
        max(0, min(1, v))
    }

    // MARK: - Core Image Fallback

    private static func coreImageTwoColors(from cgImage: CGImage) -> (UIColor, UIColor?)? {
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: [.useSoftwareRenderer: false])

        guard let avgColor = areaAverageColor(ciImage: ciImage, context: context) else {
            return nil
        }

        let second = secondDominantQuantized(ciImage: ciImage, context: context, distinctFrom: avgColor)
        return (avgColor, second)
    }

    private static func areaAverageColor(ciImage: CIImage, context: CIContext) -> UIColor? {
        let extent = ciImage.extent
        guard let filter = CIFilter(name: "CIAreaAverage") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)

        guard let output = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        context.render(output, toBitmap: &bitmap, rowBytes: 4, bounds: rect, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        let r = CGFloat(bitmap[0]) / 255.0
        let g = CGFloat(bitmap[1]) / 255.0
        let b = CGFloat(bitmap[2]) / 255.0
        let a = CGFloat(bitmap[3]) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }

    private static func secondDominantQuantized(ciImage: CIImage, context: CIContext, distinctFrom primary: UIColor) -> UIColor? {
        let targetW = 32
        let targetH = 32
        let resized = ciImage.transformed(by: CGAffineTransform(scaleX: CGFloat(targetW) / ciImage.extent.width,
                                                                y: CGFloat(targetH) / ciImage.extent.height))
        var bitmap = [UInt8](repeating: 0, count: targetW * targetH * 4)
        context.render(resized, toBitmap: &bitmap, rowBytes: targetW * 4, bounds: CGRect(x: 0, y: 0, width: targetW, height: targetH), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        func quantize(_ v: UInt8) -> UInt8 { (v & 0b11111000) }

        var histogram: [UInt32: Int] = [:]
        histogram.reserveCapacity(1024)

        for i in stride(from: 0, to: bitmap.count, by: 4) {
            let a = bitmap[i+3]
            if a < 16 { continue }
            let rq = quantize(bitmap[i+0])
            let gq = quantize(bitmap[i+1])
            let bq = quantize(bitmap[i+2])
            let key = (UInt32(rq) << 16) | (UInt32(gq) << 8) | UInt32(bq)
            histogram[key, default: 0] += 1
        }

        if histogram.isEmpty { return nil }

        var pr: CGFloat = 0, pg: CGFloat = 0, pb: CGFloat = 0, pa: CGFloat = 0
        primary.getRed(&pr, green: &pg, blue: &pb, alpha: &pa)
        let primaryKey: UInt32 = {
            let rq = UInt8(pr * 255.0)
            let gq = UInt8(pg * 255.0)
            let bq = UInt8(pb * 255.0)
            return (UInt32(rq & 0b11111000) << 16) | (UInt32(gq & 0b11111000) << 8) | UInt32(bq & 0b11111000)
        }()

        let sorted = histogram.sorted { $0.value > $1.value }
        var secondKey: UInt32? = nil
        for (key, _) in sorted {
            if key != primaryKey {
                secondKey = key
                break
            }
        }
        guard let secondKey else { return nil }

        let rq = CGFloat((secondKey >> 16) & 0xFF) / 255.0
        let gq = CGFloat((secondKey >> 8) & 0xFF) / 255.0
        let bq = CGFloat(secondKey & 0xFF) / 255.0
        return UIColor(red: rq, green: gq, blue: bq, alpha: 1.0)
    }

    // MARK: - Image Processing Utilities

    private static func resizeCGImage(_ image: CGImage, to size: CGSize) -> CGImage? {
        let width = max(1, Int(size.width))
        let height = max(1, Int(size.height))

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func rgba8Data(from image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var data = [UInt8](repeating: 0, count: Int(bytesPerRow * height))

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return data
    }

    // MARK: - Color Darkening for Legibility

    /// Ensure color is dark enough for white text (target luminance <= 0.20)
    private static func ensureDarkEnough(_ color: UIColor, targetMaxLuminance: CGFloat = 0.20) -> UIColor {
        var current = color
        var lum = relativeLuminance(current)
        if lum <= targetMaxLuminance { return current }

        // Binary search darkening
        var low: CGFloat = 0.0
        var high: CGFloat = 1.0
        var factor: CGFloat = 0.75
        for _ in 0..<10 {
            current = darken(color, factor: factor)
            lum = relativeLuminance(current)
            if lum > targetMaxLuminance {
                high = factor
                factor = (low + factor) / 2.0
            } else {
                low = factor
                factor = (factor + high) / 2.0
            }
        }
        return current
    }

    /// WCAG relative luminance for sRGB
    private static func relativeLuminance(_ color: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        let sRGB = color.cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil) ?? color.cgColor
        let comps = sRGB.components ?? [0, 0, 0, 1]
        r = comps.count > 0 ? comps[0] : 0
        g = comps.count > 1 ? comps[1] : r
        b = comps.count > 2 ? comps[2] : r

        func toLinear(_ v: CGFloat) -> CGFloat {
            if v <= 0.04045 { return v / 12.92 }
            return pow((v + 0.055) / 1.055, 2.4)
        }
        let R = toLinear(r)
        let G = toLinear(g)
        let B = toLinear(b)
        return 0.2126 * R + 0.7152 * G + 0.0722 * B
    }

    /// Darken color by scaling toward black
    private static func darken(_ color: UIColor, factor: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        let sRGB = color.cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil) ?? color.cgColor
        let comps = sRGB.components ?? [0, 0, 0, 1]
        r = comps.count > 0 ? comps[0] : 0
        g = comps.count > 1 ? comps[1] : r
        b = comps.count > 2 ? comps[2] : r
        return UIColor(red: r * factor, green: g * factor, blue: b * factor, alpha: 1.0)
    }
}
