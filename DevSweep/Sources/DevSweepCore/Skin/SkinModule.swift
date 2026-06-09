import AppKit

/// A menubar indicator "skin" — turns a `ReclaimVisualState` into a status-item `NSImage`.
///
/// Conformers are stateless value types (so they are trivially `Sendable`); each `image(for:height:)`
/// call returns a freshly drawn image. Free skins are monochrome **template** images (`isTemplate = true`)
/// so AppKit recolors them for light/dark menubars; paid skins may render in colour. Skins are the
/// monetization surface for M6 (the "store" sells paid skins); the `isFree` flag gates selection.
public protocol SkinModule: Sendable {
    /// Stable identifier, persisted as the user's selection and used in `--render-samples` filenames.
    var id: String { get }
    /// Human-facing name shown in the menu picker.
    var displayName: String { get }
    /// `true` for the bundled free skins (selectable now); `false` for paid skins (locked until M6).
    var isFree: Bool { get }
    /// Render the indicator for `state` at `height` points. Free skins set `image.isTemplate = true`.
    func image(for state: ReclaimVisualState, height: CGFloat) -> NSImage
}

/// The bundled skin set, split into free (selectable) and paid (locked) lines. The array grows as
/// skins land (M5 Tasks 3–4); `--render-samples` and the menu picker both iterate `all`.
public enum SkinCatalog {
    /// Every bundled skin, in display order (free first, then paid).
    public static let all: [any SkinModule] = [
        GaugeSkin(),
        BatterySkin(),
        DotMatrixSkin(),
        SynthwaveGaugeSkin(),
    ]

    /// Skins the user can select today.
    public static var free: [any SkinModule] { all.filter(\.isFree) }

    /// Skins shown locked in the menu (real unlock lands in M6).
    public static var paid: [any SkinModule] { all.filter { !$0.isFree } }

    /// Default selection id — the first free skin (the gauge).
    public static let defaultSkinId = "gauge"

    /// Look up a skin by id, or `nil` if unknown.
    public static func skin(id: String) -> (any SkinModule)? {
        all.first { $0.id == id }
    }
}
