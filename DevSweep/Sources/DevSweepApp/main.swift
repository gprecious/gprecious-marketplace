import AppKit
import DevSweepCore

// `DevSweepApp --render-samples <dir>`: render every skin to PNG (no GUI) and exit immediately.
// A headless visual-check that never touches the window server / Dock / status bar.
let arguments = CommandLine.arguments
if let flagIndex = arguments.firstIndex(of: "--render-samples") {
    let outputDir = flagIndex + 1 < arguments.count ? arguments[flagIndex + 1] : "/tmp/devsweep-skins"
    exit(SkinSampleRenderer.run(outputDir: outputDir))
}

// Menubar-only (accessory) app: no Dock icon, no main window, no Info.plist required.
// The status item and all live wiring are created by the delegate / Phase 3.
let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
