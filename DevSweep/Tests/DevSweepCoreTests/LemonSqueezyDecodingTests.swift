import Testing
import Foundation
@testable import DevSweepCore

@Suite struct LemonSqueezyDecodingTests {
    private let validateJSON = """
    { "valid": true, "error": null,
      "license_key": { "id": 1, "status": "active", "key": "ABCD-1234", "activation_limit": 3, "activation_usage": 1, "expires_at": null },
      "instance": { "id": "inst-abc", "name": "Test Mac" },
      "meta": { "store_id": 42, "order_id": 5, "product_id": 7, "variant_id": 9 } }
    """.data(using: .utf8)!

    private let activateJSON = """
    { "activated": true, "error": null,
      "license_key": { "id": 1, "status": "active", "key": "ABCD-1234", "activation_limit": 3, "activation_usage": 2, "expires_at": "2030-01-02T03:04:05.000000Z" },
      "instance": { "id": "inst-xyz", "name": "Test Mac" },
      "meta": { "store_id": 42, "order_id": 5, "product_id": 7, "variant_id": 9 } }
    """.data(using: .utf8)!

    @Test func decodesValidateResponse() throws {
        let s = try LemonSqueezyDecoder.validation(from: validateJSON)
        #expect(s.valid); #expect(s.status == "active"); #expect(s.storeId == 42)
        #expect(s.productId == 7); #expect(s.expiresAt == nil); #expect(s.activationLimit == 3)
    }
    @Test func decodesActivateResponseWithMicrosecondExpiry() throws {
        let r = try LemonSqueezyDecoder.activation(from: activateJSON)
        #expect(r.activated); #expect(r.instanceId == "inst-xyz"); #expect(r.status.productId == 7)
        #expect(r.status.expiresAt != nil)          // 6-digit fractional seconds parsed (rev #3)
    }
    @Test func decodesPlainSecondTimestamp() throws {
        let json = """
        { "valid": true, "license_key": { "status": "active", "expires_at": "2030-01-02T03:04:05Z" }, "meta": { "store_id": 42, "product_id": 7 } }
        """.data(using: .utf8)!
        #expect(try LemonSqueezyDecoder.validation(from: json).expiresAt != nil)
    }
    @Test func decodesInvalidResponseRetainingErrorMessage() throws {
        let json = """
        { "valid": false, "error": "license_key not found", "license_key": null, "instance": null, "meta": null }
        """.data(using: .utf8)!
        let s = try LemonSqueezyDecoder.validation(from: json)
        #expect(!s.valid); #expect(s.status == "inactive"); #expect(s.storeId == nil)
        #expect(s.serverMessage == "license_key not found")   // retained for UX (rev #10)
    }
}
