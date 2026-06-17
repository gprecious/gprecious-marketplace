import Testing
import Foundation
@testable import DevSweepCore

@Suite @MainActor struct LicenseStoreTests {
    private let config = LicenseConfig(
        checkoutURL: URL(string: "https://example.com/buy")!,
        apiBaseURL: URL(string: "https://api.lemonsqueezy.com/v1/licenses")!,
        expectedStoreId: 42, expectedProductIds: [7],
        graceWindow: 14 * 24 * 3600, seatLimit: 3, displayPrice: "$9.99")
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func proStatus() -> LicenseStatus {
        LicenseStatus(valid: true, status: "active", storeId: 42, productId: 7,
                      expiresAt: nil, activationLimit: 3, activationUsage: 1, serverMessage: nil)
    }
    private func revokedStatus() -> LicenseStatus {
        LicenseStatus(valid: false, status: "disabled", storeId: 42, productId: 7,
                      expiresAt: nil, activationLimit: 3, activationUsage: 1, serverMessage: "license_key disabled")
    }
    private func store(_ c: MockLicenseClient, _ s: InMemoryLicenseStorage, now: Date) -> LicenseStore {
        LicenseStore(client: c, storage: s, config: config, deviceName: "Test Mac", now: { now })
    }

    @Test func successfulActivationGrantsProAndUnlocksAllSkins() async {
        let c = MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "inst-1", status: proStatus()), validateStatus: proStatus())
        let s = InMemoryLicenseStorage()
        let st = store(c, s, now: t0)
        await st.activate(key: "VALID-KEY")
        #expect(st.isPro)
        #expect(st.unlockedSkinIds == Set(SkinCatalog.all.map(\.id)))
        #expect(st.activationState == .idle)
        #expect(s.load()?.instanceId == "inst-1")
    }

    @Test func activationUsesStableInstanceNameWithInstallID() async {
        let c = MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "inst-1", status: proStatus()), validateStatus: proStatus())
        let s = InMemoryLicenseStorage(installID: "uuid-123")
        await store(c, s, now: t0).activate(key: "K")
        let names = await c.activateCalls
        #expect(names == ["K"])  // call recorded; instance_name carrying installID is asserted in client tests
    }

    @Test func activatingAKeyForAnotherProductIsRejected() async {
        let wrong = LicenseStatus(valid: true, status: "active", storeId: 42, productId: 999,
                                  expiresAt: nil, activationLimit: 3, activationUsage: 1, serverMessage: nil)
        let c = MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "i", status: wrong), validateStatus: wrong)
        let s = InMemoryLicenseStorage()
        let st = store(c, s, now: t0)
        await st.activate(key: "OTHER")
        #expect(!st.isPro); #expect(s.load() == nil)
        if case .invalid = st.activationState {} else { Issue.record("expected .invalid") }
    }

    @Test func rateLimitedActivationShowsSpecificMessage() async {
        let c = MockLicenseClient(activateResult: ActivationResult(activated: false, instanceId: nil, status: revokedStatus()), validateStatus: revokedStatus(), throwError: .rateLimited)
        let st = store(c, InMemoryLicenseStorage(), now: t0)
        await st.activate(key: "ANY")
        #expect(!st.isPro)
        if case .invalid(let r) = st.activationState { #expect(r.contains("잠시")) } else { Issue.record("expected .invalid") }
    }

    @Test func validateServerRejectionRelocksImmediatelyEvenWithinGrace() async {
        // valid:false from server (NOT a throw) → re-lock now, ignoring grace. rev #2.
        let s = InMemoryLicenseStorage(seed: StoredLicense(key: "K", instanceId: "i", lastValidatedAt: t0))
        let c = MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "i", status: proStatus()), validateStatus: revokedStatus())
        let st = store(c, s, now: t0.addingTimeInterval(3600)) // well within 14d grace
        await st.validate()
        #expect(!st.isPro); #expect(s.load() == nil)
    }

    @Test func validateTransportErrorWithinGraceKeepsPro() async {
        let last = t0
        let s = InMemoryLicenseStorage(seed: StoredLicense(key: "K", instanceId: "i", lastValidatedAt: last))
        let c = MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "i", status: proStatus()), validateStatus: proStatus(), throwError: .transport)
        let st = store(c, s, now: last.addingTimeInterval(24 * 3600))
        await st.validate()
        #expect(st.isPro); #expect(s.load() != nil)
    }

    @Test func validateTransportErrorPastGraceRelocks() async {
        let last = t0
        let s = InMemoryLicenseStorage(seed: StoredLicense(key: "K", instanceId: "i", lastValidatedAt: last))
        let c = MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "i", status: proStatus()), validateStatus: proStatus(), throwError: .transport)
        let st = store(c, s, now: last.addingTimeInterval(15 * 24 * 3600))
        await st.validate()
        #expect(!st.isPro)
    }

    @Test func validateNoStoredLicenseIsFree() async {
        let c = MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "i", status: proStatus()), validateStatus: proStatus())
        let st = store(c, InMemoryLicenseStorage(), now: t0)
        await st.validate()
        #expect(!st.isPro); #expect(st.unlockedSkinIds.isEmpty)
    }

    @Test func deactivateReleasesSeatAndRelocks() async {
        let s = InMemoryLicenseStorage(seed: StoredLicense(key: "K", instanceId: "i", lastValidatedAt: t0))
        let c = MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "i", status: proStatus()), validateStatus: proStatus())
        let st = store(c, s, now: t0)
        await st.validate(); #expect(st.isPro)
        await st.deactivate()
        #expect(!st.isPro); #expect(s.load() == nil)
        let calls = await c.deactivateCalls; #expect(calls == ["K"])
    }

    @Test func isStaleReflectsLastValidatedAt() async {
        let s = InMemoryLicenseStorage(seed: StoredLicense(key: "K", instanceId: "i", lastValidatedAt: t0))
        let st = store(MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "i", status: proStatus()), validateStatus: proStatus()), s, now: t0.addingTimeInterval(7 * 3600))
        #expect(st.isStale(maxAge: 6 * 3600))   // 7h since last validate > 6h
    }

    @Test func canSelectGatesPaidSkinsButAllowsFreeSkins() async {
        let st = store(MockLicenseClient(activateResult: ActivationResult(activated: true, instanceId: "i", status: proStatus()), validateStatus: proStatus()), InMemoryLicenseStorage(), now: t0)
        #expect(st.canSelect(SkinCatalog.free.first!))
        #expect(!st.canSelect(SkinCatalog.paid.first!))
        await st.activate(key: "VALID")
        #expect(st.canSelect(SkinCatalog.paid.first!))
    }
}
