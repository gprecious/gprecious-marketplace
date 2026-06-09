import Foundation

/// Detects package-manager caches. CLI-first: tools with a real prune command use it
/// (state-aware). Tools without one (gradle) fall back to deleting the cache directory
/// via the M1 Reclaimer. All entries are `.autoSafe` (pure regenerable cache).
public struct PackageCacheModule: CleanupModule, @unchecked Sendable {
    public let id = "package-cache"
    public let displayName = "Package manager caches"

    /// How a tool's presence is detected.
    public enum ProbeMethod: Sendable {
        /// Tool is available if `executable args` exits 0 (e.g. `pnpm --version`).
        case cli(executable: String, arguments: [String])
        /// Tool is available if its cache directory exists (e.g. gradle).
        case pathExists
    }

    public struct Tool: Sendable {
        public let id: String
        public let probe: ProbeMethod
        public let cachePath: String
        public let reclaim: ReclaimMethod
        public init(id: String, probe: ProbeMethod, cachePath: String, reclaim: ReclaimMethod) {
            self.id = id; self.probe = probe; self.cachePath = cachePath; self.reclaim = reclaim
        }
    }

    private let tools: [Tool]
    private let runner: any CommandRunner
    private let reclaimer: Reclaimer
    private let sizer: DirectorySizer
    private let fileManager: FileManager

    public init(
        tools: [Tool],
        runner: any CommandRunner,
        reclaimer: Reclaimer,
        sizer: DirectorySizer = DirectorySizer(),
        fileManager: FileManager = .default
    ) {
        self.tools = tools
        self.runner = runner
        self.reclaimer = reclaimer
        self.sizer = sizer
        self.fileManager = fileManager
    }

    public func isAvailable() async -> Bool {
        for tool in tools where await isToolAvailable(tool) { return true }
        return false
    }

    public func scan() async -> [CleanupItem] {
        var items: [CleanupItem] = []
        for tool in tools where await isToolAvailable(tool) {
            let path: String? = { if case .deletePath = tool.reclaim { return tool.cachePath } else { return nil } }()
            items.append(CleanupItem(
                id: "package-cache:\(tool.id)",
                path: path,
                sizeBytes: sizer.size(of: tool.cachePath),
                lastUsed: nil,
                safety: .autoSafe,
                reclaimMethod: tool.reclaim
            ))
        }
        return items
    }

    public func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] {
        var outcomes: [ReclaimOutcome] = []
        for item in items {
            switch item.reclaimMethod {
            case .deletePath:
                // Path delete → M1 Reclaimer (dry-run + safety + accounting inherited).
                outcomes.append(contentsOf: await reclaimer.reclaim([item], dryRun: dryRun))
            case .cliCommand(let exe, let args):
                if dryRun {
                    outcomes.append(ReclaimOutcome(item: item, status: .dryRun(plannedBytes: item.sizeBytes)))
                    continue
                }
                let cachePath = tool(for: item)?.cachePath
                let before = cachePath.map { sizer.size(of: $0) } ?? 0
                let result = try? await runner.runResult(exe, args)
                guard let result, result.exitCode == 0 else {
                    let message = result.map { "\(item.id) exited \($0.exitCode)" } ?? "\(item.id) failed to launch"
                    outcomes.append(ReclaimOutcome(item: item, status: .failed(message: message)))
                    continue
                }
                let after = cachePath.map { sizer.size(of: $0) } ?? 0
                outcomes.append(ReclaimOutcome(item: item, status: .deleted(bytes: max(0, before - after))))
            }
        }
        return outcomes
    }

    private func tool(for item: CleanupItem) -> Tool? {
        tools.first { "package-cache:\($0.id)" == item.id }
    }

    private func isToolAvailable(_ tool: Tool) async -> Bool {
        switch tool.probe {
        case .cli(let exe, let args):
            guard let result = try? await runner.runResult(exe, args) else { return false }
            return result.exitCode == 0
        case .pathExists:
            return fileManager.fileExists(atPath: tool.cachePath)
        }
    }

    /// Production tool table. Cache paths are best-effort macOS defaults under `home`.
    public static func defaultTools(home: String = NSHomeDirectory()) -> [Tool] {
        func p(_ relative: String) -> String { (home as NSString).appendingPathComponent(relative) }
        return [
            Tool(id: "pnpm",
                 probe: .cli(executable: "/usr/bin/env", arguments: ["pnpm", "--version"]),
                 cachePath: p("Library/pnpm/store"),
                 reclaim: .cliCommand(executable: "/usr/bin/env", arguments: ["pnpm", "store", "prune"])),
            Tool(id: "npm",
                 probe: .cli(executable: "/usr/bin/env", arguments: ["npm", "--version"]),
                 cachePath: p(".npm"),
                 reclaim: .cliCommand(executable: "/usr/bin/env", arguments: ["npm", "cache", "clean", "--force"])),
            Tool(id: "uv",
                 probe: .cli(executable: "/usr/bin/env", arguments: ["uv", "--version"]),
                 cachePath: p(".cache/uv"),
                 reclaim: .cliCommand(executable: "/usr/bin/env", arguments: ["uv", "cache", "clean"])),
            Tool(id: "bun",
                 probe: .cli(executable: "/usr/bin/env", arguments: ["bun", "--version"]),
                 cachePath: p(".bun/install/cache"),
                 reclaim: .cliCommand(executable: "/usr/bin/env", arguments: ["bun", "pm", "cache", "rm"])),
            Tool(id: "gradle",
                 probe: .pathExists,
                 cachePath: p(".gradle/caches"),
                 reclaim: .deletePath(toTrash: false)),
        ]
    }
}
