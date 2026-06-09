import AppKit

/// App entry delegate. Builds the live `AppCoordinator`, hooks it to the `StatusItemController`,
/// and starts the watcher + initial scan. The accessory activation policy (set in `main.swift`)
/// keeps the app menubar-only — no Dock icon, no main window.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?
    private var statusController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let coordinator = AppCoordinator()
        statusController = StatusItemController(coordinator: coordinator)
        self.coordinator = coordinator
        coordinator.start()
    }
}
