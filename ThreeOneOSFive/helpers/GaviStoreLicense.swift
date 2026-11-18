import Combine
import Foundation
import Security

struct GaviLicenseResponse: Decodable {
    let valid: Bool
    let expiresAt: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case valid
        case expiresAt = "expires_at"
        case message
    }
}

enum GaviLicenseStatus: Equatable {
    case checking
    case needsKey
    case active(expiresAt: Date?)
    case locked(message: String, expiresAt: Date?)
    case unavailable
}

@MainActor
final class GaviStoreLicense: ObservableObject {
    @Published private(set) var status: GaviLicenseStatus = .checking

    private enum Constants {
        static let service = "com.gbao.gavistore.license"
        static let keyAccount = "license-key"
        static let deviceAccount = "device-id"
        static let endpoint = URL(
            string: "https://gbaodz.infinityfreeapp.com/ipa/jerry/api.php"
        )!
        static let blockedMessage = "Không làm mà đòi có ăn thì…"
    }

    var isUnlocked: Bool {
        if case .active = status { return true }
        return false
    }

    var currentExpiry: Date? {
        switch status {
        case .active(let date), .locked(_, let date): return date
        default: return nil
        }
    }

    var maskedKey: String {
        guard let key = readSecret(account: Constants.keyAccount), !key.isEmpty else {
            return "Gbao - ••••••••"
        }
        let prefix = String(key.prefix(2))
        return "Gbao - \(prefix)••••••"
    }

    func checkSavedKey() async {
        guard let key = readSecret(account: Constants.keyAccount), !key.isEmpty else {
            status = .needsKey
            return
        }
        await verify(key: key, saveWhenValid: false)
    }

    func submitKey(_ rawKey: String) async {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            status = .needsKey
            return
        }
        await verify(key: key, saveWhenValid: true)
    }

    func changeKey() {
        deleteSecret(account: Constants.keyAccount)
        status = .needsKey
    }

    private func verify(key: String, saveWhenValid: Bool) async {
        status = .checking
        do {
            var request = URLRequest(url: Constants.endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

            let payload: [String: String] = [
                "key": key,
                "device_id": deviceIdentifier()
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let result = try JSONDecoder().decode(GaviLicenseResponse.self, from: data)
            let expiry = parseDate(result.expiresAt)
            let notExpired = expiry.map { $0 > Date() } ?? true

            guard result.valid, notExpired else {
                status = .locked(
                    message: result.message ?? Constants.blockedMessage,
                    expiresAt: expiry
                )
                return
            }

            if saveWhenValid || readSecret(account: Constants.keyAccount) == nil {
                saveSecret(key, account: Constants.keyAccount)
            }
            status = .active(expiresAt: expiry)
            log("license: server verified GaviStore key")
        } catch {
            status = .unavailable
            log("license: verification request failed")
        }
    }

    private func parseDate(_ rawValue: String?) -> Date? {
        guard let rawValue else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: rawValue) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: rawValue)
    }

    private func deviceIdentifier() -> String {
        if let existing = readSecret(account: Constants.deviceAccount), !existing.isEmpty {
            return existing
        }
        let identifier = UUID().uuidString.lowercased()
        saveSecret(identifier, account: Constants.deviceAccount)
        return identifier
    }

    private func readSecret(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func saveSecret(_ value: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard updateStatus == errSecItemNotFound else { return }
        var newItem = query
        attributes.forEach { newItem[$0.key] = $0.value }
        _ = SecItemAdd(newItem as CFDictionary, nil)
    }

    private func deleteSecret(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.service,
            kSecAttrAccount as String: account
        ]
        _ = SecItemDelete(query as CFDictionary)
    }
}
