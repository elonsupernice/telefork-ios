import Foundation
import Security

struct IdentityKeychainError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? { String(localized: "service.session.expired") }
}

/// Serial off-main Keychain access. Only a genuine missing item is absence;
/// locked/unavailable Keychain never authorizes a replacement identity.
actor IdentityKeychain {
    static let shared = IdentityKeychain()
    private let service: String

    init(service: String = "com.talefork.storypaths.identity") { self.service = service }

    func read(_ account: String) throws -> Data? {
        var query = identity(account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw IdentityKeychainError(status: status == errSecSuccess ? errSecDecode : status)
        }
        return data
    }

    func write(_ data: Data, account: String) throws {
        let query = identity(account)
        var add = query
        add[kSecValueData] = data
        add[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
            guard update == errSecSuccess else { throw IdentityKeychainError(status: update) }
        } else if status != errSecSuccess {
            throw IdentityKeychainError(status: status)
        }
    }

    func delete(_ account: String) throws {
        let status = SecItemDelete(identity(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw IdentityKeychainError(status: status)
        }
    }

    private func identity(_ account: String) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
    }
}

@MainActor
final class InstallIdentityStore {
    static let shared = InstallIdentityStore()
    private let keychain = IdentityKeychain.shared
    private let defaultsKey = "talefork.install-id.v2"
    private let legacyDefaultsKey = "talefork.service-device-id"
    private var cachedID: String?
    private var installationTask: Task<String, Error>?

    var hasHistoricalInstallation: Bool {
        UserDefaults.standard.string(forKey: defaultsKey) != nil
            || UserDefaults.standard.string(forKey: legacyDefaultsKey) != nil
    }

    func installationID() async throws -> String {
        if let cachedID { return cachedID }
        if let installationTask { return try await installationTask.value }
        let task = Task { @MainActor in try await self.loadInstallationID() }
        installationTask = task
        defer { installationTask = nil }
        return try await task.value
    }

    private func loadInstallationID() async throws -> String {
        if let data = try await keychain.read("install-id"), let value = String(data: data, encoding: .utf8), !value.isEmpty {
            cachedID = value
            UserDefaults.standard.set(value, forKey: defaultsKey)
            return value
        }
        let value = UserDefaults.standard.string(forKey: defaultsKey)
            ?? UserDefaults.standard.string(forKey: legacyDefaultsKey)
            ?? UUID().uuidString.lowercased()
        try await keychain.write(Data(value.utf8), account: "install-id")
        cachedID = value
        UserDefaults.standard.set(value, forKey: defaultsKey)
        return value
    }
}

struct StoredSessionIdentity: Codable, Sendable {
    let accessPass: String
    let audienceKey: String
}

actor SessionIdentityStore {
    static let shared = SessionIdentityStore()
    private let keychain = IdentityKeychain.shared

    func load() async throws -> StoredSessionIdentity? {
        if let data = try await keychain.read("session-v3") {
            return try JSONDecoder().decode(StoredSessionIdentity.self, from: data)
        }
        let pass = try await keychain.read("access-pass")
        let audience = try await keychain.read("audience-key")
        guard let audience, let key = String(data: audience, encoding: .utf8), !key.isEmpty else { return nil }
        return StoredSessionIdentity(accessPass: pass.flatMap { String(data: $0, encoding: .utf8) } ?? "", audienceKey: key)
    }

    func save(accessPass: String, audienceKey: String) async throws {
        let identity = StoredSessionIdentity(accessPass: accessPass, audienceKey: audienceKey)
        try await keychain.write(JSONEncoder().encode(identity), account: "session-v3")
    }

    func clear() async throws {
        try await keychain.delete("access-pass")
        try await keychain.delete("audience-key")
        try await keychain.delete("session-v3")
    }
}
