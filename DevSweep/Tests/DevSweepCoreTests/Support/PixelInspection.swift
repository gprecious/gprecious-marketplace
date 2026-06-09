import AppKit
import Foundation

/// Test-only helpers for inspecting the raw pixels of a rendered skin image.
/// Skins draw into an `NSBitmapImageRep` (see `SkinCanvas`), so the first bitmap rep holds the pixels.
enum PixelInspection {
    static func bitmapRep(_ image: NSImage) -> NSBitmapImageRep? {
        image.representations.compactMap { $0 as? NSBitmapImageRep }.first
    }

    /// Raw pixel-buffer bytes — used for determinism comparisons (identical inputs ⇒ identical bytes).
    static func rawPixels(_ image: NSImage) -> Data? {
        guard let rep = bitmapRep(image), let ptr = rep.bitmapData else { return nil }
        return Data(bytes: ptr, count: rep.bytesPerRow * rep.pixelsHigh)
    }

    /// `true` if any byte is non-zero — i.e. something was actually drawn (background is cleared to 0).
    static func isNonEmpty(_ image: NSImage) -> Bool {
        guard let data = rawPixels(image) else { return false }
        return data.contains { $0 != 0 }
    }

    /// `true` if any visible pixel is chromatic (R/G/B not all equal) — distinguishes colour from
    /// greyscale/template renders.
    static func hasChromaticPixel(_ image: NSImage) -> Bool {
        guard let rep = bitmapRep(image), let ptr = rep.bitmapData else { return false }
        let bytesPerRow = rep.bytesPerRow
        let spp = rep.samplesPerPixel
        guard spp >= 3 else { return false }
        for y in 0..<rep.pixelsHigh {
            let rowStart = y * bytesPerRow
            for x in 0..<rep.pixelsWide {
                let p = rowStart + x * spp
                let r = ptr[p], g = ptr[p + 1], b = ptr[p + 2]
                let a = spp >= 4 ? ptr[p + 3] : 255
                if a > 0 && (r != g || g != b) { return true }
            }
        }
        return false
    }

    /// Pixel dimensions of the backing rep (for @2x assertions).
    static func pixelSize(_ image: NSImage) -> (width: Int, height: Int)? {
        guard let rep = bitmapRep(image) else { return nil }
        return (rep.pixelsWide, rep.pixelsHigh)
    }
}
