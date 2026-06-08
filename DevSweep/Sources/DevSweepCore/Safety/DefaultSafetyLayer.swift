import Foundation

/// Factory that composes the production set of activity signals into a SafetyLayer.
/// External dependencies (command runner, LaunchAgents dir, clock) are injectable so
/// the same composition is exercised under test.
public enum DefaultSafetyLayer {
    public static func make(
        commandRunner: any CommandRunner = ProcessCommandRunner(),
        launchAgentsDir: String = (("~/Library/LaunchAgents") as NSString).expandingTildeInPath,
        registry: ProtectedRegistry = ProtectedRegistry(),
        thresholdDays: Int = 30,
        now: @escaping @Sendable () -> Date = Date.init
    ) -> SafetyLayer {
        let signals: [any ActivitySignal] = [
            ProcessReferenceSignal(runner: commandRunner),
            LaunchdReferenceSignal(launchAgentsDir: launchAgentsDir),
            CrontabReferenceSignal(runner: commandRunner),
            RecentUseSignal(thresholdDays: thresholdDays, now: now),
            ParentProjectActivitySignal(thresholdDays: thresholdDays, now: now)
        ]
        return SafetyLayer(signals: signals, registry: registry)
    }
}
