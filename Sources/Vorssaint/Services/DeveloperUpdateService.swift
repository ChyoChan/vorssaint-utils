// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

enum DeveloperUpdateError: Error, Equatable {
    case missingBuildInfo, network, rateLimited, unavailable, invalidResponse, historyChanged
}

struct DeveloperUpstreamComparison: Equatable {
    let ahead: Int
}

struct DeveloperUpstreamClient {
    typealias Transport = (URLRequest) async throws -> (Data, HTTPURLResponse)
    private let transport: Transport

    init(transport: Transport? = nil) {
        self.transport = transport ?? { request in
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            configuration.urlCredentialStorage = nil
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 20
            let session = URLSession(configuration: configuration)
            defer { session.finishTasksAndInvalidate() }
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw DeveloperUpdateError.invalidResponse
            }
            return (data, response)
        }
    }

    static func makeRequest(base: String) throws -> URLRequest {
        guard DeveloperBuildSnapshot.isHash(base, length: 40) else {
            throw DeveloperUpdateError.missingBuildInfo
        }
        // Page two omits changed-file patches; ahead_by still counts the whole comparison.
        let endpoint = "https://api.github.com/repos/vorssaint/vorssaint-utils/compare/" +
            base.lowercased() + "...main?per_page=1&page=2"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Vorssaint-Developer", forHTTPHeaderField: "User-Agent")
        return request
    }

    func compare(base: String) async throws -> DeveloperUpstreamComparison {
        let request = try Self.makeRequest(base: base)
        try Task.checkCancellation()
        let data: Data
        let response: HTTPURLResponse
        do { (data, response) = try await transport(request) }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch let error as DeveloperUpdateError { throw error }
        catch { throw DeveloperUpdateError.network }
        try Task.checkCancellation()
        guard response.url?.scheme == "https", response.url?.host == "api.github.com" else {
            throw DeveloperUpdateError.invalidResponse
        }
        switch response.statusCode {
        case 200: break
        case 403, 429: throw DeveloperUpdateError.rateLimited
        case 404, 500...599: throw DeveloperUpdateError.unavailable
        default: throw DeveloperUpdateError.invalidResponse
        }
        guard data.count <= 1_000_000,
              let result = try? JSONDecoder().decode(Response.self, from: data),
              result.baseCommit.sha.caseInsensitiveCompare(base) == .orderedSame,
              result.ahead >= 0, result.behind >= 0 else {
            throw DeveloperUpdateError.invalidResponse
        }
        guard result.behind == 0,
              result.status == "ahead" || result.status == "identical" else {
            throw DeveloperUpdateError.historyChanged
        }
        guard (result.status == "identical" && result.ahead == 0) ||
              (result.status == "ahead" && result.ahead > 0) else {
            throw DeveloperUpdateError.invalidResponse
        }
        return DeveloperUpstreamComparison(ahead: result.ahead)
    }

    private struct Response: Decodable {
        let status: String
        let ahead: Int
        let behind: Int
        let baseCommit: Commit
        struct Commit: Decodable { let sha: String }
        enum CodingKeys: String, CodingKey {
            case status
            case ahead = "ahead_by", behind = "behind_by", baseCommit = "base_commit"
        }
    }
}

@MainActor
final class DeveloperUpdateService: ObservableObject {
    static let shared = DeveloperUpdateService()
    let snapshot: DeveloperBuildSnapshot?
    @Published private(set) var comparison: DeveloperUpstreamComparison?
    @Published private(set) var lastChecked: Date?
    @Published private(set) var isChecking = false
    @Published private(set) var error: DeveloperUpdateError?
    private let client: DeveloperUpstreamClient

    init(snapshot: DeveloperBuildSnapshot? = .bundled, client: DeveloperUpstreamClient = .init()) {
        self.snapshot = snapshot
        self.client = client
    }

    func refresh() async {
        guard !isChecking else { return }
        guard let base = snapshot?.upstreamRevision else {
            error = .missingBuildInfo
            return
        }
        isChecking = true
        error = nil
        defer { isChecking = false }
        do {
            comparison = try await client.compare(base: base)
            lastChecked = Date()
        } catch is CancellationError {
            // Keep the last successful value; an interrupted refresh cannot verify it.
            error = .network
        } catch {
            self.error = error as? DeveloperUpdateError ?? .network
        }
    }
}
