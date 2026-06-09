import AppKit
import SwiftUI
import DevSweepCore

/// Owns the `NSStatusItem` and its click-through popover. The button shows the reclaimable total;
/// its tint escalates with the gauge thresholds (grey `< low`, yellow `low–high`, red + bold
/// `>= high`). Clicking toggles a transient popover hosting the SwiftUI `MenuView`.
@MainActor
final class StatusItemController: NSObject {
    /// Menubar icon height in points (Apple's status item images are ~18pt tall).
    private static let iconHeight: CGFloat = 18

    private let coordinator: AppCoordinator
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let skinRenderer: SkinRenderer

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.skinRenderer = SkinRenderer(config: coordinator.config, skinId: coordinator.currentSkinId)
        super.init()

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuView(coordinator: coordinator))

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.imagePosition = .imageLeading
        }
        render(bytes: coordinator.reclaimableBytes)

        // The status item isn't a SwiftUI view, so the coordinator pushes byte updates here.
        coordinator.onStateChange = { [weak self] bytes in
            self?.render(bytes: bytes)
        }
        // …and skin changes, so the rendered icon swaps to the newly selected skin.
        coordinator.onSkinChange = { [weak self] id in
            guard let self else { return }
            self.skinRenderer.select(id: id)
            self.render(bytes: self.coordinator.reclaimableBytes)
        }
    }

    func render(bytes: Int64) {
        guard let button = statusItem.button else { return }
        button.image = skinRenderer.image(forBytes: bytes, height: Self.iconHeight)
        button.title = humanBytes(bytes)
        button.contentTintColor = StatusIndicator.tint(
            forBytes: bytes,
            low: coordinator.config.gaugeLowBytes,
            high: coordinator.config.gaugeHighBytes
        )
        button.font = bytes >= coordinator.config.gaugeHighBytes
            ? .boldSystemFont(ofSize: NSFont.systemFontSize)
            : .systemFont(ofSize: NSFont.systemFontSize)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

/// Pure mapping from a reclaimable-byte total to the status item's tint colour. `nil`-safe edges:
/// `>= high` red, `>= low` yellow, otherwise the muted secondary label colour.
enum StatusIndicator {
    static func tint(forBytes bytes: Int64, low: Int64, high: Int64) -> NSColor? {
        if bytes >= high { return .systemRed }
        if bytes >= low { return .systemYellow }
        return .secondaryLabelColor
    }
}
