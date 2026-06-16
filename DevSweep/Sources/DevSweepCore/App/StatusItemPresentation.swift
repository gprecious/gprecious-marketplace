import AppKit

/// Presentation rules for the AppKit status item. Kept pure so the menubar contrast and popover
/// anchor math can be tested without launching the accessory app.
public enum StatusItemPresentation {
    /// Extra gap below the menubar button so the popover clears dark/notched menu bars.
    public static let popoverVerticalOffset: CGFloat = 8

    public struct Style {
        public let imageTint: NSColor
        public let titleColor: NSColor
        public let titleFont: NSFont
    }

    public static func style(forBytes bytes: Int64, low: Int64, high: Int64, hasFullDiskAccess: Bool = true) -> Style {
        Style(
            imageTint: hasFullDiskAccess
                ? imageTint(forBytes: bytes, low: low, high: high)
                : .systemOrange, // FDA 경고가 게이지 tint보다 우선
            titleColor: .labelColor,
            titleFont: bytes >= high
                ? .boldSystemFont(ofSize: NSFont.systemFontSize)
                : .systemFont(ofSize: NSFont.systemFontSize)
        )
    }

    public static func attributedTitle(_ title: String, style: Style) -> NSAttributedString {
        NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: style.titleColor,
                .font: style.titleFont,
            ]
        )
    }

    public static func popoverAnchorRect(in buttonBounds: CGRect) -> CGRect {
        CGRect(
            x: buttonBounds.midX - 0.5,
            y: buttonBounds.minY - popoverVerticalOffset,
            width: 1,
            height: 1
        )
    }

    private static func imageTint(forBytes bytes: Int64, low: Int64, high: Int64) -> NSColor {
        if bytes >= high { return .systemRed }
        if bytes >= low { return .systemYellow }
        return .secondaryLabelColor
    }
}
