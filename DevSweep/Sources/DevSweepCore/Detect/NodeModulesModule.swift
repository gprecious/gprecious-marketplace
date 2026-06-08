import Foundation

/// Detects project dependency dirs (`node_modules`, `.venv`, `venv`) under configured dev
/// roots. Emits `.reviewNeeded` candidates only; it never decides dormancy itself —
/// reclaim delegates to the M1 Reclaimer, whose ParentProjectActivitySignal auto-protects
/// projects with recent source (the pyiri lesson, reused).
public struct NodeModulesModule: CleanupModule, @unchecked Sendable {
    public let id = "node-modules"
    public let displayName = "Project dependencies (node_modules, venv)"

    private let roots: [String]
    private let excludedProjectNames: Set<String>
    private let targetDirNames: Set<String>
    private let sizer: DirectorySizer
    private let fileManager: FileManager
    private let reclaimer: Reclaimer

    public init(
        roots: [String],
        reclaimer: Reclaimer,
        excludedProjectNames: Set<String> = ["gprecious-marketplace", "research-engine"],
        targetDirNames: Set<String> = ["node_modules", ".venv", "venv"],
        sizer: DirectorySizer = DirectorySizer(),
        fileManager: FileManager = .default
    ) {
        self.roots = roots
        self.reclaimer = reclaimer
        self.excludedProjectNames = excludedProjectNames
        self.targetDirNames = targetDirNames
        self.sizer = sizer
        self.fileManager = fileManager
    }

    public func isAvailable() async -> Bool {
        roots.contains { fileManager.fileExists(atPath: $0) }
    }

    public func scan() async -> [CleanupItem] {
        var items: [CleanupItem] = []
        for root in roots { collect(root, into: &items) }
        return items
    }

    private func collect(_ dir: String, into items: inout [CleanupItem]) {
        guard let entries = try? fileManager.contentsOfDirectory(atPath: dir) else { return }
        for entry in entries {
            let full = (dir as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue else { continue }

            if targetDirNames.contains(entry) {
                // Skip when the owning project (immediate parent dir) is excluded.
                let projectName = (dir as NSString).lastPathComponent
                if excludedProjectNames.contains(projectName) { continue }
                items.append(CleanupItem(
                    id: full,
                    path: full,
                    sizeBytes: sizer.size(of: full),
                    lastUsed: nil,
                    safety: .reviewNeeded,
                    reclaimMethod: .deletePath(toTrash: false)
                ))
                // Do NOT descend into a target dir.
            } else if entry == ".git" {
                continue
            } else {
                collect(full, into: &items)
            }
        }
    }

    public func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] {
        await reclaimer.reclaim(items, dryRun: dryRun)
    }
}
