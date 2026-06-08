import Foundation

/// Detects reclaimable Docker space via the docker CLI. Emits one item per prune action
/// with a differentiated safety class. NEVER touches volumes (DB data protection — the
/// 2026-06-06 user policy): no command contains `--volumes`, and reclaim refuses any item
/// whose command does.
public struct DockerModule: CleanupModule {
    public let id = "docker"
    public let displayName = "Docker"

    private let runner: any CommandRunner
    private let executable: String
    private let argPrefix: [String]

    public init(
        runner: any CommandRunner,
        executable: String = "/usr/bin/env",
        argPrefix: [String] = ["docker"]
    ) {
        self.runner = runner
        self.executable = executable
        self.argPrefix = argPrefix
    }

    private func docker(_ args: [String]) -> (String, [String]) {
        (executable, argPrefix + args)
    }

    public func isAvailable() async -> Bool {
        let (exe, args) = docker(["system", "df"])
        guard let result = try? await runner.runResult(exe, args) else { return false }
        return result.exitCode == 0
    }

    public func scan() async -> [CleanupItem] {
        let (exe, args) = docker(["system", "df", "--format", "{{json .}}"])
        let reclaimable = (try? await runner.runResult(exe, args))
            .map { Self.parseReclaimable($0.stdout) } ?? [:]
        return [
            CleanupItem(
                id: "docker:build-cache", path: nil,
                sizeBytes: reclaimable["Build Cache"] ?? 0, lastUsed: nil,
                safety: .autoSafe,
                reclaimMethod: .cliCommand(executable: executable, arguments: argPrefix + ["builder", "prune", "-f"])
            ),
            CleanupItem(
                id: "docker:dangling-images", path: nil,
                sizeBytes: 0, lastUsed: nil,  // df can't isolate dangling subset; measured at reclaim
                safety: .autoSafe,
                reclaimMethod: .cliCommand(executable: executable, arguments: argPrefix + ["image", "prune", "-f"])
            ),
            CleanupItem(
                id: "docker:unused-images", path: nil,
                sizeBytes: reclaimable["Images"] ?? 0, lastUsed: nil,
                safety: .reviewNeeded,
                reclaimMethod: .cliCommand(executable: executable, arguments: argPrefix + ["image", "prune", "-a", "-f"])
            )
        ]
    }

    public func reclaim(_ items: [CleanupItem], dryRun: Bool) async -> [ReclaimOutcome] {
        var outcomes: [ReclaimOutcome] = []
        for item in items {
            guard case let .cliCommand(exe, args) = item.reclaimMethod else {
                outcomes.append(ReclaimOutcome(item: item, status: .failed(message: "DockerModule expects cliCommand items")))
                continue
            }
            if args.contains("--volumes") {
                outcomes.append(ReclaimOutcome(item: item, status: .failed(message: "refusing docker command with --volumes")))
                continue
            }
            if dryRun {
                outcomes.append(ReclaimOutcome(item: item, status: .dryRun(plannedBytes: item.sizeBytes)))
                continue
            }
            let before = await totalSizeBytes()
            let result = try? await runner.runResult(exe, args)
            guard let result, result.exitCode == 0 else {
                let message = result.map { "docker exited \($0.exitCode)" } ?? "docker command failed to launch"
                outcomes.append(ReclaimOutcome(item: item, status: .failed(message: message)))
                continue
            }
            let after = await totalSizeBytes()
            outcomes.append(ReclaimOutcome(item: item, status: .deleted(bytes: max(0, before - after))))
        }
        return outcomes
    }

    private func totalSizeBytes() async -> Int64 {
        let (exe, args) = docker(["system", "df", "--format", "{{json .}}"])
        guard let result = try? await runner.runResult(exe, args) else { return 0 }
        return Self.parseTotalSize(result.stdout)
    }

    /// Maps each df row Type → reclaimable bytes (from the "Reclaimable" column).
    static func parseReclaimable(_ stdout: String) -> [String: Int64] {
        var result: [String: Int64] = [:]
        for line in stdout.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = obj["Type"] as? String,
                  let reclaimable = obj["Reclaimable"] as? String else { continue }
            result[type] = parseSize(reclaimable)
        }
        return result
    }

    /// Sums the "Size" column across all df rows (for before/after delta).
    static func parseTotalSize(_ stdout: String) -> Int64 {
        var total: Int64 = 0
        for line in stdout.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let size = obj["Size"] as? String else { continue }
            total += parseSize(size)
        }
        return total
    }

    /// Parses a docker human size ("3GB", "2GB (40%)", "100MB", "0B") to bytes (base 1000).
    static func parseSize(_ raw: String) -> Int64 {
        let head = raw.split(separator: "(").first.map(String.init) ?? raw
        let trimmed = head.trimmingCharacters(in: .whitespaces)
        let units: [(String, Double)] = [("TB", 1e12), ("GB", 1e9), ("MB", 1e6), ("kB", 1e3), ("KB", 1e3), ("B", 1)]
        for (suffix, multiplier) in units where trimmed.hasSuffix(suffix) {
            let numberPart = trimmed.dropLast(suffix.count).trimmingCharacters(in: .whitespaces)
            return Double(numberPart).map { Int64($0 * multiplier) } ?? 0
        }
        return Int64(trimmed) ?? 0
    }
}
