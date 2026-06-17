import Foundation

public enum ByteFormat {
    /// Decimal (1000-based) human-readable byte string. Matches `AppConfig`'s decimal-GB
    /// thresholds and how macOS reports disk sizes. A true zero is shown as "0 GB" instead of
    /// ByteCountFormatter's prose-style "zero bytes".
    public static func humanBytes(_ bytes: Int64) -> String {
        guard bytes != 0 else { return "0 GB" }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .decimal
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        return formatter.string(fromByteCount: bytes)
    }
}
