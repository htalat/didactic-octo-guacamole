import Foundation
import Security

/// Builds the list of sources that the app uses.
public enum TodoSourceFactory {
    /// - Parameter existing: Sources to reuse. The local source is always reused, so that only one
    ///   connection to the database is open.
    public static func makeSources(reusing existing: [any TodoSource] = []) -> [any TodoSource] {
        let local = existing.first { $0.id == LocalTodoSource.sourceID } ?? LocalTodoSource(storage: makeLocalStorage())
        var sources: [any TodoSource] = [local]
        if let timmu = TimmuSettings.makeSource() {
            sources.append(timmu)
        }
        return sources
    }

    private static func makeLocalStorage() -> TodoStorage {
        do {
            return try SQLiteStorage()
        } catch {
            print("Failed to initialize SQLite storage, falling back to UserDefaults: \(error)")
            return UserDefaultsStorage()
        }
    }
}

/// The Timmu server URL (in UserDefaults) and the account token (in the Keychain).
public enum TimmuSettings {
    public static let defaultBaseURL = URL(string: "http://localhost:3000")!

    private static let baseURLKey = "timmu.baseURL"
    private static let keychainService = "com.htalat.todo.timmu"
    private static let keychainAccount = "token"

    public static var baseURL: URL {
        UserDefaults.standard.string(forKey: baseURLKey).flatMap(URL.init(string:)) ?? defaultBaseURL
    }

    public static var isConnected: Bool {
        Keychain.read(service: keychainService, account: keychainAccount) != nil
    }

    static func makeSource() -> TimmuTodoSource? {
        guard let token = Keychain.read(service: keychainService, account: keychainAccount) else { return nil }
        return TimmuTodoSource(baseURL: baseURL, token: token)
    }

    /// Signs in and keeps the token. The password is not stored.
    public static func connect(baseURL: URL, email: String, password: String) async throws {
        let token = try await TimmuTodoSource.logIn(baseURL: baseURL, email: email, password: password)
        UserDefaults.standard.set(baseURL.absoluteString, forKey: baseURLKey)
        try Keychain.save(token, service: keychainService, account: keychainAccount)
    }

    public static func disconnect() {
        Keychain.delete(service: keychainService, account: keychainAccount)
    }
}

enum Keychain {
    struct Failure: LocalizedError {
        let status: OSStatus
        var errorDescription: String? {
            "Keychain error: \(SecCopyErrorMessageString(status, nil) as String? ?? String(status))"
        }
    }

    static func read(service: String, account: String) -> String? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ value: String, service: String, account: String) throws {
        delete(service: service, account: account)
        var query = baseQuery(service: service, account: account)
        query[kSecValueData as String] = Data(value.utf8)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw Failure(status: status) }
    }

    static func delete(service: String, account: String) {
        SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
    }

    private static func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
