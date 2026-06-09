import Foundation

/// Gate ③ of the Safety Layer: an absolute deny-list. A path that matches here is
/// `.protected` no matter what any other gate says. Holds user-chosen permanent
/// exclusions (exact paths) plus built-in system-protected prefixes.
public struct ProtectedRegistry: Sendable {
    private let userExcluded: Set<String>
    private let systemProtected: [String]

    public init(
        userExcluded: Set<String> = [],
        systemProtected: [String] = ProtectedRegistry.defaultSystemProtected
    ) {
        self.userExcluded = userExcluded
        self.systemProtected = systemProtected.map { ($0 as NSString).expandingTildeInPath }
    }

    /// True if the path is permanently protected. `nil` paths (CLI-based items) are never protected here.
    public func isProtected(path: String?) -> Bool {
        guard let path else { return false }
        if userExcluded.contains(path) { return true }
        for prefix in systemProtected where path == prefix || path.hasPrefix(prefix + "/") {
            return true
        }
        return false
    }

    /// Built-in protected prefixes. `~` is expanded at init time.
    public static let defaultSystemProtected: [String] = [
        "~/.ssh",
        "~/Library/Keychains",
        "~/.gnupg",
        "~/.config/gh/hosts.yml"
    ]
}
