// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Deliberately contains no server messages, URLs, original text or credentials.
enum GoogleTranslationError: Error, Equatable {
    case missingKey, invalidKey, denied, quota, network, invalidResponse, unavailable, invalidRequest, requestTooLarge
}

enum TranslationAPIKey {
    static func normalized(_ value: String) throws -> String {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw GoogleTranslationError.missingKey }
        guard key.count <= 256, key.utf8.allSatisfy({
            (65...90).contains($0) || (97...122).contains($0) ||
                (48...57).contains($0) || $0 == 45 || $0 == 95
        }) else { throw GoogleTranslationError.invalidKey }
        return key
    }
}

final class GoogleTranslationClient {
    typealias Transport = (URLRequest) async throws -> (Data, HTTPURLResponse)
    static let endpoint = URL(string: "https://translation.googleapis.com/language/translate/v2")!
    private let transport: Transport
    private let session: URLSession?
    private let recordUsage: (Int) -> Void

    init(recordUsage: @escaping (Int) -> Void = { GoogleTranslationUsageStore.shared.record(characterCount: $0) },
         transport: Transport? = nil) {
        self.recordUsage = recordUsage
        if let transport {
            self.transport = transport
            self.session = nil
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            configuration.urlCredentialStorage = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 60
            let session = URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
            self.session = session
            self.transport = { request in
                do {
                    let (data, response) = try await session.data(for: request)
                    guard let response = response as? HTTPURLResponse else {
                        throw GoogleTranslationError.invalidResponse
                    }
                    return (data, response)
                } catch let error as URLError {
                    if error.code == .cancelled { throw CancellationError() }
                    throw GoogleTranslationError.network
                }
            }
        }
    }

    deinit { session?.invalidateAndCancel() }

    static func languageCode(_ identifier: String) -> String { identifier == "zh-Hant" ? "zh-TW" : identifier }

    static func makeRequest(texts: [String], source: String?, target: String, key: String) throws -> URLRequest {
        let key = try TranslationAPIKey.normalized(key)
        guard texts.count == 1 else {
            throw GoogleTranslationError.invalidRequest
        }
        var body: [String: Any] = ["q": texts, "target": languageCode(target), "format": "text", "model": "nmt"]
        if let source { body["source"] = languageCode(source) }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        let payload = try JSONSerialization.data(withJSONObject: body)
        // Basic v2 accepts at most 100K bytes. Never split an oversized selection.
        guard payload.count <= 100_000 else { throw GoogleTranslationError.requestTooLarge }
        request.httpBody = payload
        return request
    }

    func translate(_ request: TranslationRequest, key: String) async throws -> String {
        _ = try TranslationTextPlan.validate(request.text)
        // Google's billable characters are code points, not Swift graphemes.
        guard request.text.unicodeScalars.count <= TranslationTextPlan.maximumCharacters else {
            throw TranslationInputError.tooLong
        }
        let key = try TranslationAPIKey.normalized(key)
        func translateWholeSelection() async throws -> String {
            try Task.checkCancellation()
            let http = try Self.makeRequest(texts: [request.text], source: request.source,
                                            target: request.target, key: key)
            let data: Data
            let response: HTTPURLResponse
            try Task.checkCancellation()
            recordUsage(request.text.unicodeScalars.count)
            do { (data, response) = try await transport(http) }
            catch let error as URLError {
                if error.code == .cancelled { throw CancellationError() }
                throw GoogleTranslationError.network
            }
            try Task.checkCancellation()
            switch response.statusCode {
            case 200: break
            case 400: throw GoogleTranslationError.invalidRequest
            case 401: throw GoogleTranslationError.invalidKey
            case 403: throw GoogleTranslationError.denied
            case 429: throw GoogleTranslationError.quota
            case 500...599: throw GoogleTranslationError.unavailable
            default: throw GoogleTranslationError.invalidResponse
            }
            guard data.count <= 2_000_000,
                  let decoded = try? JSONDecoder().decode(Response.self, from: data),
                  decoded.data.translations.count == 1 else {
                throw GoogleTranslationError.invalidResponse
            }
            return Self.decodeEntities(decoded.data.translations[0].translatedText)
        }
        let result = try await translateWholeSelection()
        try Task.checkCancellation()
        return result
    }

    /// Decode once, without rendering HTML or following external resources.
    static func decodeEntities(_ value: String) -> String {
        let named = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00a0}"]
        var result = ""
        var cursor = value.startIndex
        while cursor < value.endIndex {
            if value[cursor] == "&",
               let end = value[cursor...].prefix(16).firstIndex(of: ";") {
                let token = String(value[value.index(after: cursor)..<end])
                var replacement = named[token]
                if token.hasPrefix("#") {
                    let hex = token.hasPrefix("#x") || token.hasPrefix("#X")
                    let number = UInt32(token.dropFirst(hex ? 2 : 1), radix: hex ? 16 : 10)
                    if let number, let scalar = UnicodeScalar(number) { replacement = String(scalar) }
                }
                if let replacement {
                    result += replacement
                    cursor = value.index(after: end)
                    continue
                }
            }
            result.append(value[cursor]); cursor = value.index(after: cursor)
        }
        return result
    }

    private struct Response: Decodable {
        let data: Payload
        struct Payload: Decodable { let translations: [Item] }
        struct Item: Decodable { let translatedText: String }
    }

    private final class NoRedirects: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }
}
