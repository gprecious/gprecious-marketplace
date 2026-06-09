import AppKit
import DevSweepCore

// `DevSweepApp --render-samples <dir>`: render every skin to PNG (no GUI) and exit immediately.
// A headless visual-check that never touches the window server / Dock / status bar.
// The output dir is required (no default to a shared world-writable path), and a symlinked dir is
// refused — keeps this dev diagnostic from being steered into an attacker-chosen location.
let arguments = CommandLine.arguments
if let flagIndex = arguments.firstIndex(of: "--render-samples") {
    guard flagIndex + 1 < arguments.count else {
        FileHandle.standardError.write(Data("usage: DevSweepApp --render-samples <output-dir>\n".utf8))
        exit(2)
    }
    exit(SkinSampleRenderer.run(outputDir: arguments[flagIndex + 1]))
}

// Menubar-only (accessory) app: no Dock icon, no main window, no Info.plist required.
// The status item and all live wiring are created by the delegate / Phase 3.
let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
