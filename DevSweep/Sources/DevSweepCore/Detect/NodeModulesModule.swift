import Foundation

/// Detects project dependency dirs (`node_modules`, `.venv`, `venv`) under configured dev
/// roots. Emits `.reviewNeeded` candidates only; it never decides dormancy itself —
/// reclaim delegates to the M1 Reclaimer, whose ParentProjectActivitySignal auto-protects
/// projects with recent source (the pyiri lesson, reused).
///
/// The walk is hardened for real dev trees: it never follows symbolic links (a link to an
/// ancestor would cycle forever — real trees have thousands of `.build/**` symlinks), prunes
/// build/cache/VCS dirs (`.build`, `target`, `Pods`, …) which are huge and never hold a
/// project's own deps, and is bounded by `maxDepth` as a final safety net. Without these the
/// initial scan of `~/Documents/dev` never finishes.
public struct NodeModulesModule: CleanupModule, @unchecked Sendable {
    public let id = "node-modules"
    public let displayName = "Project dependencies (node_modules, venv)"
    public static let defaultScanSizeDescendantLimit = DirectorySizer.defaultScanDescendantLimit

    private let roots: [String]
    private let excludedProjectNames: Set<String>
    private let targetDirNames: Set<String>
    private let prunedDirNames: Set<String>
    private let maxDepth: Int
    private let sizer: DirectorySizer
    private let scanSizeDescendantLimit: Int?
    private let fileManager: FileManager
    private let reclaimer: Reclaimer

    public init(
        roots: [String],
        reclaimer: Reclaimer,
        excludedProjectNames: Set<String> = ["gprecious-marketplace", "research-engine"],
        targetDirNames: Set<String> = ["node_modules", ".venv", "venv"],
        prunedDirNames: Set<String> = [
            ".git", ".build", "build", "dist", "target", "DerivedData",
            ".next", ".nuxt", ".gradle", "Pods", ".turbo", ".cache", "out", ".swiftpm"
        ],
        maxDepth: Int = 8,
        sizer: DirectorySizer = DirectorySizer(),
        scanSizeDescendantLimit: Int? = Self.defaultScanSizeDescendantLimit,
        fileManager: FileManager = .default
    ) {
        self.roots = roots
        self.reclaimer = reclaimer
        self.excludedProjectNames = excludedProjectNames
        self.targetDirNames = targetDirNames
        self.prunedDirNames = prunedDirNames
        self.maxDepth = maxDepth
        self.sizer = sizer
        self.scanSizeDescendantLimit = scanSizeDescendantLimit
        self.fileManager = fileManager
    }

    public func isAvailable() async -> Bool {
        roots.contains { fileManager.fileExists(atPath: $0) }
    }

    public func scan() async -> [CleanupItem] {
        var items: [CleanupItem] = []
        for root in roots { collect(root, depth: 0, into: &items) }
        return items
    }

    /// Recurse `dir` (at `depth` from a root), emitting target dirs and descending into plain
    /// subdirs. Three guards keep a real dev tree finite: symlinks are never followed, build/cache
    /// dirs are pruned, and recursion stops past `maxDepth`.
    private func collect(_ dir: String, depth: Int, into items: inout [CleanupItem]) {
        guard depth <= maxDepth else { return }
        guard let entries = try? fileManager.contentsOfDirectory(atPath: dir) else { return }
        for entry in entries {
            let full = (dir as NSString).appendingPathComponent(entry)

            // Never follow symbolic links: `attributesOfItem` uses lstat (classifies the link
            // itself, not its target), so a link pointing at an ancestor can't cycle the walk.
            // This MUST precede `fileExists(isDirectory:)`, which resolves the link and would
            // report the target's type.
            let attrs = try? fileManager.attributesOfItem(atPath: full)
            if (attrs?[.type] as? FileAttributeType) == .typeSymbolicLink { continue }

            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue else { continue }

            if targetDirNames.contains(entry) {
                // Skip when the owning project (immediate parent dir) is excluded.
                let projectName = (dir as NSString).lastPathComponent
                if excludedProjectNames.contains(projectName) { continue }
                items.append(CleanupItem(
                    id: full,
                    path: full,
                    sizeBytes: sizer.size(of: full, maxDescendantEntries: scanSizeDescendantLimit),
                    lastUsed: nil,
                    safety: .reviewNeeded,
                    reclaimMethod: .deletePath(toTrash: false)
                ))
                // Do NOT descend into a target dir.
            } else if prunedDirNames.contains(entry) {
                // Build/cache/VCS dir — never a project's own deps, and huge; skip entirely.
                continue
            } else {
                collect(full, depth: depth + 1, into: &items)
            }
        }
    }

    public func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] {
        await reclaimer.reclaim(items, dryRun: dryRun)
    }
}
