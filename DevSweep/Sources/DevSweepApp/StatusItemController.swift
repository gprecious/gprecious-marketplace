import AppKit
import SwiftUI
import DevSweepCore

/// Owns the `NSStatusItem` and its click-through popover. The button shows the reclaimable total;
/// its icon tint escalates with the gauge thresholds (grey `< low`, yellow `low–high`, red
/// `>= high`) while the title stays readable on dark menubars. Clicking toggles a transient
/// popover hosting the SwiftUI `MenuView`.
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
        popover.contentViewController = NSHostingController(
            rootView: MenuView(coordinator: coordinator, skinStore: coordinator.skinStore)
        )

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
        let style = StatusItemPresentation.style(
            forBytes: bytes,
            low: coordinator.config.gaugeLowBytes,
            high: coordinator.config.gaugeHighBytes
        )
        button.image = skinRenderer.image(forBytes: bytes, height: Self.iconHeight)
        button.imageScaling = .scaleProportionallyDown
        button.attributedTitle = StatusItemPresentation.attributedTitle(humanBytes(bytes), style: style)
        button.contentTintColor = style.imageTint
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            let anchor = StatusItemPresentation.popoverAnchorRect(in: button.bounds)
            popover.show(relativeTo: anchor, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            keepPopoverInsideVisibleScreen(relativeTo: button)
        }
    }

    private func keepPopoverInsideVisibleScreen(relativeTo button: NSStatusBarButton) {
        guard let window = popover.contentViewController?.view.window,
              let screen = button.window?.screen ?? NSScreen.main else { return }

        let visible = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        var frame = window.frame

        if frame.maxY > visible.maxY {
            frame.origin.y -= frame.maxY - visible.maxY
        }
        if frame.minY < visible.minY {
            frame.origin.y += visible.minY - frame.minY
        }
        if frame.minX < visible.minX {
            frame.origin.x += visible.minX - frame.minX
        }
        if frame.maxX > visible.maxX {
            frame.origin.x -= frame.maxX - visible.maxX
        }

        if frame != window.frame {
            window.setFrame(frame, display: true)
        }
    }
}
