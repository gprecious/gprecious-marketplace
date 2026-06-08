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

        return DetectorRegistry(modules: [docker, packageCache, nodeModules])
    }
}
