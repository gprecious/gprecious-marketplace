import Foundation
import Testing
@testable import DevSweepCore

@Test func systemProtectedPrefixMatchesNestedPath() {
    let registry = ProtectedRegistry(
        userExcluded: [],
        systemProtected: ["/Users/x/.ssh", "/Users/x/Library/Keychains"]
    )
    #expect(registry.isProtected(path: "/Users/x/.ssh/id_rsa") == true)
    #expect(registry.isProtected(path: "/Users/x/Library/Keychains/login.keychain-db") == true)
    #expect(registry.isProtected(path: "/Users/x/.npm") == false)
}

@Test func userExcludedExactPathIsProtected() {
    let registry = ProtectedRegistry(userExcluded: ["/Users/x/work/keep-me"], systemProtected: [])
    #expect(registry.isProtected(path: "/Users/x/work/keep-me") == true)
    #expect(registry.isProtected(path: "/Users/x/work/keep-me-not") == false)
}

@Test func nilPathIsNotProtected() {
    let registry = ProtectedRegistry(userExcluded: [], systemProtected: [])
    #expect(registry.isProtected(path: nil) == false)
}

@Test func tildePrefixesAreExpanded() {
    // defaultSystemProtected uses ~-prefixed entries; they must expand before matching.
    let home = NSHomeDirectory()
    let registry = ProtectedRegistry()  // uses defaults
    #expect(registry.isProtected(path: "\(home)/.ssh/config") == true)
}
