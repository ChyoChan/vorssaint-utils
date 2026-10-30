// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PlainTranslate contributors
import Foundation

enum ReleaseUpdateChecks {
    @MainActor static func run(_ expect: @escaping (Bool, String) -> Void) async {
        let repo = "ChyoChan/vorssaint-utils"
        func release(_ tag: String, draft: Bool = false, preview: Bool = false, url: String? = nil) -> [String: Any] {
            ["tag_name": tag, "html_url": url ?? "https://github.com/\(repo)/releases/tag/\(tag)",
             "body": "Fixture release notes", "draft": draft, "prerelease": preview]
        }
        func payload(_ values: [[String: Any]]) -> Data { try! JSONSerialization.data(withJSONObject: values) }
        func response(_ request: URLRequest, status: Int = 200, url: URL? = nil) -> HTTPURLResponse {
            HTTPURLResponse(url: url ?? request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        }
        for invalid in ["", "main", "1.2", "01.2.3", "1.bad.3", "1.2.3\n", "1.2.3-01", "99999999999999999999999.0.0"] {
            expect(!GitHubReleaseClient.validVersion(invalid), "unusable version tags are rejected")
        }
        for (a, b) in [("1.9.0", "1.10.0"), ("1.2.3-beta.2", "1.2.3-beta.10"), ("1.2.3-rc.1", "1.2.3")] {
            expect(ReleaseVersion(raw: a)! < ReleaseVersion(raw: b)!, "versions use semantic numeric ordering")
        }
        var calls = 0
        let client = GitHubReleaseClient(repository: repo, transport: { request in
            calls += 1
            expect(request.url?.host == "api.github.com" && request.url?.path == "/repos/\(repo)/releases" &&
                   request.httpBody == nil && request.value(forHTTPHeaderField: "Authorization") == nil &&
                   request.value(forHTTPHeaderField: "X-Goog-Api-Key") == nil,
                   "release checks send no key, text, or authentication to the configured HTTPS repository")
            return (payload([release("v0.1.2"), release("v0.1.4", preview: true), release("v9.0.0", draft: true),
                             release("v99.0.0", url: "https://example.invalid/download")]), response(request))
        })
        let service = ReleaseUpdateService(currentVersion: "0.1.3", client: client)
        await service.check()
        expect(service.release?.tag == "v0.1.4" && service.release?.preview == true && service.hasNewerVersion &&
                   service.lastChecked != nil && !service.isChecking && service.error == nil && calls == 1,
               "preview updates are included and drafts or off-repository links are excluded")
        let same = ReleaseUpdateService(currentVersion: "0.1.4", client: client)
        await same.check()
        expect(!same.hasNewerVersion, "the published current version is not offered as an update")
        let newer = ReleaseUpdateService(currentVersion: "0.2.0", client: client)
        await newer.check()
        expect(!newer.hasNewerVersion, "older releases cannot downgrade an installed custom build")
        let empty = ReleaseUpdateService(currentVersion: "0.1.3", client:
            GitHubReleaseClient(repository: repo, transport: { (payload([]), response($0)) }))
        await empty.check()
        expect(empty.release == nil && empty.lastChecked != nil && empty.error == nil,
               "a repository with no releases is reported distinctly from network failure")
        for (code, error) in [(403, ReleaseCheckError.rateLimited), (429, .rateLimited), (404, .unavailable),
                              (503, .unavailable), (302, .invalidResponse)] {
            let failed = ReleaseUpdateService(currentVersion: "0.1.3", client:
                GitHubReleaseClient(repository: repo, transport: { (Data(), response($0, status: code)) }))
            await failed.check()
            expect(failed.error == error && failed.lastChecked == nil && !failed.hasNewerVersion,
                   "HTTP failure never implies that the installed app is current")
        }
        for data in [Data("{}".utf8), Data(repeating: 32, count: 3_000_001),
                     payload([release("v1.0.0", url: "https://github.com/other/project/releases/tag/v1.0.0")])] {
            let invalid = GitHubReleaseClient(repository: repo, transport: { (data, response($0)) })
            do { _ = try await invalid.latest(); expect(false, "invalid release data must throw") }
            catch { expect(error as? ReleaseCheckError == .invalidResponse, "malformed, oversized and untrusted data are rejected") }
        }
        let redirected = GitHubReleaseClient(repository: repo, transport: {
            (payload([]), response($0, url: URL(string: "https://example.invalid/releases")))
        })
        do { _ = try await redirected.latest(); expect(false, "redirected results must throw") }
        catch { expect(error as? ReleaseCheckError == .invalidResponse, "unexpected response endpoints are rejected") }
        var attempt = 0
        let flaky = ReleaseUpdateService(currentVersion: "0.1.3", client:
            GitHubReleaseClient(repository: repo, transport: { request in
                attempt += 1
                if attempt > 1 { throw URLError(.notConnectedToInternet) }
                return (payload([release("v0.1.4")]), response(request))
            }))
        await flaky.check()
        let checked = flaky.lastChecked
        await flaky.check()
        expect(flaky.error == .network && flaky.lastChecked == checked && flaky.release?.tag == "v0.1.4",
               "failed refresh preserves the last verified release and successful timestamp")
        var concurrentCalls = 0
        let single = ReleaseUpdateService(currentVersion: "0.1.3", client:
            GitHubReleaseClient(repository: repo, transport: { request in
                concurrentCalls += 1
                try await Task.sleep(nanoseconds: 20_000_000)
                return (payload([]), response(request))
            }))
        async let first: Void = single.check()
        async let second: Void = single.check()
        _ = await (first, second)
        expect(concurrentCalls == 1 && !single.isChecking, "concurrent checks share one in-flight request")
        let cancelled = Task { await single.check() }
        cancelled.cancel()
        await cancelled.value
        expect(single.error == nil && single.lastChecked != nil, "cancellation preserves verified state")
    }
}
