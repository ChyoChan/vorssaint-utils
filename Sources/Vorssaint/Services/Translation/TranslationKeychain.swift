// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import Security
import Combine
import LocalAuthentication

struct TranslationKeychain {
    let service: String
    init(service: String = (Bundle.main.bundleIdentifier ?? "com.vorssaint.utils") + ".translation.google") {
        self.service = service
    }
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "api-key", kSecAttrSynchronizable as String: false]
    }

    func contains() throws -> Bool {
        var query = query
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecItemNotFound { return false }
        guard status == errSecSuccess else { throw Failure() }
        return true
    }

    func load() throws -> String? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else { throw Failure() }
        return key
    }

    func save(_ value: String) throws {
        let key = try TranslationAPIKey.normalized(value)
        let data = Data(key.utf8)
        let updated = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updated == errSecSuccess { return }
        guard updated == errSecItemNotFound else { throw Failure() }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw Failure() }
    }

    func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure() }
    }

    struct Failure: Error {}
}

/// UI never reloads the saved secret into an editable field or UserDefaults.
@MainActor final class TranslationCredentials: ObservableObject {
    static let shared = TranslationCredentials()
    @Published private(set) var hasKey = false
    @Published private(set) var busy = false
    @Published private(set) var status: Status = .none
    enum Status { case none, saved, removed, failed, invalid }
    private let store = TranslationKeychain()

    func refresh() async {
        guard !busy else { return }
        busy = true
        let store = store
        let result = await Task.detached { Result { try store.contains() } }.value
        switch result {
        case .success(let found): hasKey = found; status = .none
        case .failure: status = .failed
        }
        busy = false
    }

    func save(_ draft: String) async -> Bool {
        guard !busy else { return false }
        guard let key = try? TranslationAPIKey.normalized(draft) else { status = .invalid; return false }
        busy = true
        let store = store
        let result = await Task.detached { Result { try store.save(key) } }.value
        busy = false
        switch result {
        case .success: hasKey = true; status = .saved; return true
        case .failure: status = .failed; return false
        }
    }

    func remove() async {
        guard !busy else { return }
        busy = true
        let store = store
        let result = await Task.detached { Result { try store.remove() } }.value
        busy = false
        switch result {
        case .success: hasKey = false; status = .removed
        case .failure: status = .failed
        }
    }
}
