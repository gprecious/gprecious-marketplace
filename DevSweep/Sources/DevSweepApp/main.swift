import AppKit

// Menubar-only (accessory) app: no Dock icon, no main window, no Info.plist required.
// The status item and all live wiring are created by the delegate / Phase 3.
let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
