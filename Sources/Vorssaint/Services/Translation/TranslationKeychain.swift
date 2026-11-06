// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import Security
import Combine
import LocalAuthentication

struct TranslationKeychain {
    let service: String
    private let keychain: SecKeychain?
    init(service: String = (Bundle.main.bundleIdentifier ?? "com.vorssaint.utils") + ".translation.google",
         keychain: SecKeychain? = nil) {
        self.service = service
        self.keychain = keychain
    }
    private var query: [String: Any] {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                  kSecAttrAccount as String: "api-key", kSecAttrSynchronizable as String: false]
        if let keychain { query[kSecMatchSearchList as String] = [keychain] }
        return query
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
        // Updating an existing item can retain another app’s read access.
        var item = query
        item.removeValue(forKey: kSecMatchSearchList as String)
        if let keychain { item[kSecUseKeychain as String] = keychain }
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        if status == errSecDuplicateItem { throw ExistingItem() }
        guard status == errSecSuccess else { throw Failure() }
    }

    func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure() }
    }

    struct ExistingItem: Error {}
    struct Failure: Error {}
}

/// UI never reloads the saved secret into an editable field or UserDefaults.
@MainActor final class TranslationCredentials: ObservableObject {
    static let shared = TranslationCredentials()
    @Published private(set) var hasKey = false
    @Published private(set) var busy = false
    @Published private(set) var status: Status = .none
    enum Status { case none, saved, removed, failed, invalid, exists }
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
        case .success:
            NotificationCenter.default.post(name: .translationCredentialsDidChange, object: nil)
            hasKey = true; status = .saved; return true
        case .failure(is TranslationKeychain.ExistingItem):
            hasKey = true; status = .exists; return false
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
        case .success:
            NotificationCenter.default.post(name: .translationCredentialsDidChange, object: nil)
            hasKey = false; status = .removed
        case .failure: status = .failed
        }
    }
}
