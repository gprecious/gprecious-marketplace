import Foundation

/// Decimal (1000-based) human-readable byte string. Matches `AppConfig`'s decimal-GB thresholds
/// and how macOS reports disk sizes to users (e.g. 21_000_000_000 → "21 GB").
func humanBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .decimal
    formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
    return formatter.string(fromByteCount: bytes)
}
