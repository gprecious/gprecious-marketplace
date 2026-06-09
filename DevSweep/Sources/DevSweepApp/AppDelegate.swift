import AppKit

/// Minimal status-bar app delegate. Phase 1 only installs a static status item so the
/// app launches and survives in the menubar; the live `StatusItemController`, menu, and
/// `AppCoordinator` wiring land in Phase 3.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Retained so the status item is not deallocated immediately after launch.
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "◌"
        statusItem = item
    }
}
