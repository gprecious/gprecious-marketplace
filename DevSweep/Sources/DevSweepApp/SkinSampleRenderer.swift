import AppKit
import DevSweepCore

/// Headless visual-check: renders every bundled skin × representative reclaimable level to PNG, then
/// the process exits — no `NSApplication`, no menubar, no Dock icon. Invoked from `main.swift` via
/// `DevSweepApp --render-samples <outDir>`. Lets us eyeball the skins without capturing the menubar.
enum SkinSampleRenderer {
    /// One level per band plus an empty case (matches the rendering tests' fixtures).
    private static let levels: [(label: String, bytes: Int64)] = [
        ("0", 0),
        ("2gb", 2_000_000_000),
        ("12gb", 12_000_000_000),
        ("30gb", 30_000_000_000),
    ]

    /// Render to `<outputDir>/<skin>-<level>.png` (@2x pixels, `height` pt tall).
    /// - Returns: a process exit code — `0` on success, `1` on any I/O or encoding failure.
    static func run(outputDir: String, height: CGFloat = 18) -> Int32 {
        let config = AppConfig.default
        let fileManager = FileManager.default
        let directory = URL(fileURLWithPath: outputDir, isDirectory: true)

        // Refuse a pre-placed symlink at the output path (attributesOfItem uses lstat — it does not
        // follow the final symlink), so the export can't be redirected elsewhere.
        if let type = (try? fileManager.attributesOfItem(atPath: directory.path))?[.type] as? FileAttributeType,
           type == .typeSymbolicLink {
            reportError("refusing to write into a symlinked path: \(outputDir)")
            return 1
        }

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            reportError("cannot create \(outputDir): \(error)")
            return 1
        }

        var written = 0
        for skin in SkinCatalog.all {
            for level in levels {
                let state = ReclaimVisualState(reclaimableBytes: level.bytes, config: config)
                let image = skin.image(for: state, height: height)
                guard let png = pngData(image) else {
                    reportError("failed to encode \(skin.id)-\(level.label)")
                    return 1
                }
                let outputURL = directory.appendingPathComponent("\(skin.id)-\(level.label).png")
                do {
                    try png.write(to: outputURL)
                    written += 1
                } catch {
                    reportError("cannot write \(outputURL.path): \(error)")
                    return 1
                }
            }
        }
        print("render-samples: wrote \(written) PNG(s) to \(directory.path)")
        return 0
    }

    private static func pngData(_ image: NSImage) -> Data? {
        guard let rep = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private static func reportError(_ message: String) {
        FileHandle.standardError.write(Data("render-samples: \(message)\n".utf8))
    }
}
