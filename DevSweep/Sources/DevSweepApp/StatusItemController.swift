import AppKit
import SwiftUI
import DevSweepCore

/// Owns the `NSStatusItem` and its click-through menu. The button shows the reclaimable total;
/// its icon tint escalates with the gauge thresholds (grey `< low`, yellow `low–high`, red
/// `>= high`) while the title stays readable on dark menubars. Clicking opens a system menu hosting
/// the SwiftUI `MenuView`.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    /// Menubar icon height in points (Apple's status item images are ~18pt tall).
    private static let iconHeight: CGFloat = 18

    private let coordinator: AppCoordinator
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let menuItem = NSMenuItem()
    private let hostingView: NSHostingView<MenuView>
    private let skinRenderer: SkinRenderer

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.skinRenderer = SkinRenderer(config: coordinator.config, skinId: coordinator.currentSkinId)
        self.hostingView = NSHostingView(
            rootView: MenuView(
                coordinator: coordinator,
                skinStore: coordinator.skinStore,
                settingsLauncher: SystemSettingsLauncher()
            )
        )
        super.init()

        hostingView.rootView = MenuView(
            coordinator: coordinator,
            skinStore: coordinator.skinStore,
            settingsLauncher: SystemSettingsLauncher(),
            onDismiss: { [weak self] in self?.menu.cancelTracking() }
        )
        menu.delegate = self
        menu.addItem(menuItem)
        menuItem.view = hostingView

        if let button = statusItem.button {
            button.imagePosition = .imageLeading
        }
        statusItem.menu = menu
        updateMenuSize()
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
        // FDA 상태 변화 → 아이콘 경고 tint 재렌더(render가 coordinator.hasFullDiskAccess를 읽음).
        coordinator.onFDAStateChange = { [weak self] _ in
            guard let self else { return }
            self.render(bytes: self.coordinator.reclaimableBytes)
        }
        // 첫 실행 1회 자동 메뉴 — refresh를 다시 부르지 않는 show 경로(재진입 방지).
        coordinator.requestAutoOpenPopover = { [weak self] in
            self?.showMenu()
        }
    }

    func render(bytes: Int64) {
        guard let button = statusItem.button else { return }
        let style = StatusItemPresentation.style(
            forBytes: bytes,
            low: coordinator.config.gaugeLowBytes,
            high: coordinator.config.gaugeHighBytes,
            hasFullDiskAccess: coordinator.hasFullDiskAccess
        )
        button.image = skinRenderer.image(forBytes: bytes, height: Self.iconHeight)
        button.imageScaling = .scaleProportionallyDown
        button.attributedTitle = StatusItemPresentation.attributedTitle(humanBytes(bytes), style: style)
        button.contentTintColor = style.imageTint
    }

    func menuWillOpen(_ menu: NSMenu) {
        // 사용자가 열 때마다 권한 재확인 → granted 전환 시 배너 즉시 제거 + 재스캔(spec §4.3).
        coordinator.refreshFDA()
        updateMenuSize()
    }

    /// 메뉴를 연다(재진입 방지를 위해 refresh는 호출하지 않음 — 자동 권한 안내 경로가 이 메서드를 직접 쓴다).
    private func showMenu() {
        guard let button = statusItem.button else { return }
        updateMenuSize()
        menu.popUp(positioning: nil, at: NSPoint(x: button.bounds.midX, y: button.bounds.minY), in: button)
    }

    private func updateMenuSize() {
        hostingView.layoutSubtreeIfNeeded()
        let fitting = hostingView.fittingSize
        hostingView.frame.size = NSSize(width: max(300, fitting.width), height: fitting.height)
    }
}
