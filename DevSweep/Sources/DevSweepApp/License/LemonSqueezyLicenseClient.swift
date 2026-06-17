import Foundation
import DevSweepCore

/// Production `LicenseActivating` — form-encoded POSTs to the keyless LemonSqueezy License API.
/// No API key (the license key authorizes). Returns decoded results for 2xx and JSON-bearing 4xx
/// (a server rejection is `valid:false`, NOT an error); throws `LicenseClientError` only for
/// transport failures, 429, and 5xx so the store applies offline grace only when truly offline.
struct LemonSqueezyLicenseClient: LicenseActivating {
    let baseURL: URL
    let session: URLSession
    init(baseURL: URL, session: URLSession = .shared) { self.baseURL = baseURL; self.session = session }

    func activate(key: String, instanceName: String) async throws -> ActivationResult {
        try LemonSqueezyDecoder.activation(from: try await post("activate", ["license_key": key, "instance_name": instanceName]))
    }
    func validate(key: String, instanceId: String) async throws -> LicenseStatus {
        try LemonSqueezyDecoder.validation(from: try await post("validate", ["license_key": key, "instance_id": instanceId]))
    }
    func deactivate(key: String, instanceId: String) async throws {
        _ = try await post("deactivate", ["license_key": key, "instance_id": instanceId])
    }

    private func post(_ path: String, _ fields: [String: String]) async throws -> Data {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = Self.formBody(fields)
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw LicenseClientError.transport }
            switch http.statusCode {
            case 200...299, 400, 404, 422:
                // 2xx and the documented license-verdict 4xx codes carry a JSON body the decoder
                // turns into valid:false → the store re-locks. NOT treated as a transient error.
                return data
            case 429:
                throw LicenseClientError.rateLimited
            default:
                throw LicenseClientError.server(http.statusCode)   // 5xx / unexpected
            }
        } catch let e as LicenseClientError {
            throw e
        } catch {
            throw LicenseClientError.transport                      // URLError etc. → grace
        }
    }

    private static func formBody(_ fields: [String: String]) -> Data {
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&="))
        return Data(fields.map { k, v in
            "\(k.addingPercentEncoding(withAllowedCharacters: allowed) ?? k)=\(v.addingPercentEncoding(withAllowedCharacters: allowed) ?? v)"
        }.joined(separator: "&").utf8)
    }
}
