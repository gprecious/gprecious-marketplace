import Foundation

/// Composes the production DetectorRegistry. Caches and projects get DIFFERENT safety
/// compositions on purpose:
///   • cacheLayer  — reference signals only (process/launchd/crontab). NO recency:
///                   caches are *expected* to be recently used; recency must not protect them.
///   • projectLayer — full DefaultSafetyLayer (recency-aware) so ACTIVE projects with
///                    recent source are protected (the pyiri/node_modules lesson).
public enum DefaultDetectorRegistry {
    public static func make(
        home: String = NSHomeDirectory(),
        devRoots: [String] = [(("~/Documents/dev") as NSString).expandingTildeInPath],
        commandRunner: any CommandRunner = ProcessCommandRunner(),
        deleter: any FileSystemDeleter,
        registry: ProtectedRegistry = ProtectedRegistry()
    ) -> DetectorRegistry {
        DetectorRegistry(modules: makeModules(
            home: home,
            devRoots: devRoots,
            commandRunner: commandRunner,
            deleter: deleter,
            registry: registry
        ))
    }

    /// The composed module instances, exposed so the App layer can build BOTH a
    /// `DetectorRegistry` (for scanning) and a `ReclaimRouter` (for routing approved reclaims)
    /// from one shared module set — identical safety compositions, no duplication, no divergence.
    /// `make` is implemented on top of this; existing callers see no behavior change.
    public static func makeModules(
        home: String = NSHomeDirectory(),
        devRoots: [String] = [(("~/Documents/dev") as NSString).expandingTildeInPath],
        commandRunner: any CommandRunner = ProcessCommandRunner(),
        deleter: any FileSystemDeleter,
        registry: ProtectedRegistry = ProtectedRegistry()
    ) -> [any CleanupModule] {
        let sizer = DirectorySizer()

        let cacheLayer = SafetyLayer(
            signals: [
                ProcessReferenceSignal(runner: commandRunner),
                LaunchdReferenceSignal(),
                CrontabReferenceSignal(runner: commandRunner)
            ],
            registry: registry
        )
        let projectLayer = DefaultSafetyLayer.make(commandRunner: commandRunner, registry: registry)

        let cacheReclaimer = Reclaimer(safety: cacheLayer, deleter: deleter)
        let projectReclaimer = Reclaimer(safety: projectLayer, deleter: deleter)

        let docker = DockerModule(runner: commandRunner)
        let packageCache = PackageCacheModule(
            tools: PackageCacheModule.defaultTools(home: home),
            runner: commandRunner,
            reclaimer: cacheReclaimer,
            sizer: sizer
        )
        let nodeModules = NodeModulesModule(
            roots: devRoots,
            reclaimer: projectReclaimer,
            sizer: sizer
        )
        let worktrees = WorktreeModule(roots: devRoots, runner: commandRunner, sizer: sizer)

        return [docker, packageCache, nodeModules, worktrees]
    }
}
