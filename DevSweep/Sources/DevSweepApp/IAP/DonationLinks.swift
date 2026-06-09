import AppKit

/// Voluntary, **reward-free** support links — Apple Guideline 3.2.1(vii). These open in the browser;
/// the app contains **no purchase logic** for donations and offers **no in-app reward** (no exclusive
/// skins, no perks) for donating. Any supporter perks are advertised only outside the app
/// (GitHub/web). Keeping reward language out of these buttons is what keeps skins (IAP-only) and
/// donations (external) cleanly separated for review.
enum DonationLinks {
    /// One-off "buy me a coffee" — shallow, wide funnel; no account required of the donor.
    static let buyMeACoffee = URL(string: "https://www.buymeacoffee.com/devsweep")!
    /// Recurring monthly support — deep, narrow funnel.
    static let githubSponsors = URL(string: "https://github.com/sponsors/gprecious")!

    /// Open a support link in the user's default browser.
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
