import Foundation

/// Cross-module de-dup: when item A's path is an ancestor directory of item B's path, B is
/// removed (A subsumes it). Used so a `git-worktrees` item absorbs `node_modules` items
/// inside it — preventing the same bytes being counted by two modules. Items with no path
/// (CLI-based, e.g. docker) are always kept.
public enum NestedItemSuppressor {
    public static func suppressNested(_ items: [CleanupItem]) -> [CleanupItem] {
        let parents = items.compactMap { $0.path.map(normalize) }
        return items.filter { item in
            guard let p = item.path.map(normalize) else { return true }
            return !parents.contains { parent in parent != p && p.hasPrefix(parent + "/") }
        }
    }

    private static func normalize(_ path: String) -> String { (path as NSString).standardizingPath }
}
