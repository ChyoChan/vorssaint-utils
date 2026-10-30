// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PlainTranslate contributors

import Combine
import Foundation

enum ReleaseCheckError: Error, Equatable { case network, rateLimited, unavailable, invalidResponse }

struct PublishedAppRelease: Equatable {
    let tag: String
    let notes: String
    let url: URL
    let preview: Bool
}

struct GitHubReleaseClient {
    typealias Transport = (URLRequest) async throws -> (Data, HTTPURLResponse)
    let repository: String
    private let transport: Transport
    var releasesURL: URL { URL(string: "https://github.com/\(repository)/releases")! }

    init(repository: String, transport: Transport? = nil) {
        // Repository is application configuration, never remote or user input.
        precondition(["ChyoChan/PlainTranslate", "ChyoChan/vorssaint-utils"].contains(repository))
        self.repository = repository
        self.transport = transport ?? { request in
            let config = URLSessionConfiguration.ephemeral
            config.urlCache = nil
            config.httpCookieStorage = nil
            config.urlCredentialStorage = nil
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 20
            let session = URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
            defer { session.finishTasksAndInvalidate() }
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw ReleaseCheckError.invalidResponse }
            return (data, response)
        }
    }

    func latest() async throws -> PublishedAppRelease? {
        // shortcut: inspect the 100 most recent releases; paginate if a project needs a longer feed.
        let endpoint = URL(string: "https://api.github.com/repos/\(repository)/releases?per_page=100")!
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("PlainTranslate-Vorssaint-ReleaseCheck", forHTTPHeaderField: "User-Agent")
        try Task.checkCancellation()
        let data: Data
        let response: HTTPURLResponse
        do { (data, response) = try await transport(request) }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch let error as ReleaseCheckError { throw error }
        catch { throw ReleaseCheckError.network }
        try Task.checkCancellation()
        guard response.url == endpoint else { throw ReleaseCheckError.invalidResponse }
        switch response.statusCode {
        case 200: break
        case 403, 429: throw ReleaseCheckError.rateLimited
        case 404, 500...599: throw ReleaseCheckError.unavailable
        default: throw ReleaseCheckError.invalidResponse
        }
        guard data.count <= 3_000_000,
              let releases = try? JSONDecoder().decode([Response].self, from: data) else {
            throw ReleaseCheckError.invalidResponse
        }
        let valid = releases.filter {
            !$0.draft && Self.validVersion($0.tag) &&
                $0.url.scheme == "https" && $0.url.host == "github.com" &&
                $0.url.user == nil && $0.url.password == nil && $0.url.port == nil &&
                $0.url.path == "/\(repository)/releases/tag/\($0.tag)"
        }
        guard let chosen = valid.max(by: {
            ReleaseVersion(raw: $0.tag)! < ReleaseVersion(raw: $1.tag)!
        }) else {
            // An empty feed is valid; a populated but unusable feed is not "up to date".
            if releases.contains(where: { !$0.draft }) { throw ReleaseCheckError.invalidResponse }
            return nil
        }
        return PublishedAppRelease(tag: chosen.tag, notes: String((chosen.body ?? "").prefix(12_000)),
                                   url: chosen.url, preview: chosen.preview)
    }

    static func validVersion(_ value: String) -> Bool {
        let pattern = #"^[vV]?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$"#
        guard value.count <= 128,
              value.range(of: pattern, options: .regularExpression) == value.startIndex..<value.endIndex else { return false }
        let clean = value.first == "v" || value.first == "V" ? String(value.dropFirst()) : value
        let version = clean.split(separator: "+", maxSplits: 1)[0]
        let parts = version.split(separator: "-", maxSplits: 1)
        guard parts[0].split(separator: ".").allSatisfy({ Int($0) != nil }) else { return false }
        if parts.count == 2 {
            for identifier in parts[1].split(separator: ".") where identifier.allSatisfy({ $0.isNumber }) {
                if identifier.count > 1 && identifier.first == "0" { return false }
            }
        }
        return ReleaseVersion(raw: value) != nil
    }

    private struct Response: Decodable {
        let tag: String
        let url: URL
        let body: String?
        let draft: Bool
        let preview: Bool
        enum CodingKeys: String, CodingKey {
            case tag = "tag_name", url = "html_url", body, draft, preview = "prerelease"
        }
    }
    private final class NoRedirects: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    }
}

@MainActor
final class ReleaseUpdateService: ObservableObject {
    static let shared = ReleaseUpdateService(
        currentVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? AppInfo.version,
        client: GitHubReleaseClient(repository: "ChyoChan/vorssaint-utils"))
    let currentVersion: String
    let client: GitHubReleaseClient
    @Published private(set) var release: PublishedAppRelease?
    @Published private(set) var isChecking = false
    @Published private(set) var lastChecked: Date?
    @Published private(set) var error: ReleaseCheckError?
    var hasNewerVersion: Bool {
        guard let release, let installed = ReleaseVersion(raw: currentVersion),
              let latest = ReleaseVersion(raw: release.tag) else { return false }
        return installed < latest
    }

    init(currentVersion: String, client: GitHubReleaseClient) {
        self.currentVersion = currentVersion
        self.client = client
    }

    func check() async {
        guard !isChecking else { return }
        isChecking = true
        error = nil
        defer { isChecking = false }
        do {
            let result = try await client.latest()
            try Task.checkCancellation()
            release = result
            lastChecked = Date()
        } catch is CancellationError {
            // Cancellation never replaces a verified result or check time.
        } catch { self.error = error as? ReleaseCheckError ?? .network }
    }
}

// Reuse the existing application update version comparator.
typealias ReleaseVersion = UpdateServiceSupport.SemanticVersion
