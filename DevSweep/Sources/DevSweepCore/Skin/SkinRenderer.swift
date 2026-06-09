import AppKit

/// Holds the user's current skin and renders the menubar image for a reclaimable-byte total.
///
/// Owned by the status item (main actor) and used by `--render-samples`; not `Sendable` (it holds a
/// mutable selection) so it's confined to a single actor/thread. The byte→visual mapping uses the
/// supplied `AppConfig` gauge thresholds, so the renderer and the textual indicator stay in lockstep.
public final class SkinRenderer {
    public private(set) var currentSkinId: String
    private let config: AppConfig

    public init(config: AppConfig, skinId: String = SkinCatalog.defaultSkinId) {
        self.config = config
        self.currentSkinId = SkinCatalog.skin(id: skinId) != nil ? skinId : SkinCatalog.defaultSkinId
    }

    /// The currently selected skin (falls back to the gauge if the id ever goes stale).
    public var currentSkin: any SkinModule {
        SkinCatalog.skin(id: currentSkinId) ?? GaugeSkin()
    }

    /// Switch skins by id. Returns `false` (and keeps the current selection) for an unknown id.
    @discardableResult
    public func select(id: String) -> Bool {
        guard SkinCatalog.skin(id: id) != nil else { return false }
        currentSkinId = id
        return true
    }

    /// Render the current skin for `bytes` at `height` points.
    public func image(forBytes bytes: Int64, height: CGFloat) -> NSImage {
        let state = ReclaimVisualState(reclaimableBytes: bytes, config: config)
        return currentSkin.image(for: state, height: height)
    }
}
