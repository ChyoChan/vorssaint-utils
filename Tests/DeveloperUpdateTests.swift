// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum DeveloperUpdateTests {
    private static let revision = String(repeating: "a", count: 40)
    private static let upstream = String(repeating: "b", count: 40)
    private static let fingerprint = String(repeating: "c", count: 64)

    private static func record() -> [String: Any] {
        ["schemaVersion": 1, "runID": "B9F96CB6-435D-45AE-AD8F-5BE2913CE44B",
         "state": "passed", "scope": "full", "suites": [],
         "startedAt": 1_700_000_000, "finishedAt": 1_700_000_010,
         "revision": revision, "sourceFingerprint": fingerprint, "sourceChanged": false]
    }

    private static func metadata(test: Any? = nil) -> [String: Any] {
        ["schemaVersion": 1, "revision": revision, "dirty": true,
         "sourceFingerprint": fingerprint, "upstreamRevision": upstream,
         "test": test ?? NSNull()]
    }

    private static func decode(_ value: [String: Any]) -> DeveloperBuildSnapshot? {
        guard let data = try? JSONSerialization.data(withJSONObject: value) else { return nil }
        return DeveloperBuildSnapshot.decode(data)
    }

    static func run(_ suite: TestSuite) {
        let current = decode(metadata(test: record()))
        suite.expect(current?.revision == revision && current?.dirty == true &&
                     current?.upstreamRevision == upstream && current?.testMatchesBuild == true,
                     "developer metadata describes the installed dirty source and its matching tests")
        suite.expect(current?.test?.startedAt == Date(timeIntervalSince1970: 1_700_000_000),
                     "Python epoch timestamps decode as Unix time rather than the Apple reference date")
        var committed = metadata(test: record())
        committed["revision"] = String(repeating: "d", count: 40)
        committed["dirty"] = false
        suite.expect(decode(committed)?.testMatchesBuild == true,
                     "committing unchanged tested content does not invalidate its result")
        var different = metadata(test: record())
        different["sourceFingerprint"] = String(repeating: "d", count: 64)
        suite.expect(decode(different)?.testMatchesBuild == false,
                     "two builds from the same SHA-dirty cannot share a green result after source edits")
        var changed = record()
        changed["sourceChanged"] = true
        suite.expect(decode(metadata(test: changed))?.testMatchesBuild == false,
                     "source changes during a test run cannot verify the built source")
        var selected = record()
        selected["scope"] = "selected"
        selected["suites"] = ["translation", "repository"]
        suite.expect(decode(metadata(test: selected))?.test?.scope == .selected &&
                     decode(metadata(test: selected))?.test?.suites == ["translation", "repository"],
                     "a partial test result retains its explicit scope")
        for state in ["failed", "incomplete"] {
            var attempt = record()
            attempt["state"] = state
            if state == "incomplete" { attempt["finishedAt"] = NSNull() }
            suite.expect(decode(metadata(test: attempt))?.test?.state.rawValue == state,
                         "failed and unfinished attempts are not silently converted into success")
        }
        for (key, value) in [
            ("schemaVersion", 2 as Any), ("runID", "invalid"),
            ("state", "unknown"), ("scope", "unknown"),
            ("finishedAt", 1_699_999_999), ("sourceFingerprint", "bad"),
            ("revision", "main"), ("suites", ["unexpected-full-scope"]),
        ] {
            var invalid = record()
            invalid[key] = value
            let snapshot = decode(metadata(test: invalid))
            suite.expect(snapshot?.revision == revision && snapshot?.test == nil,
                         "malformed test data becomes unknown without losing installed build identity")
        }
        for key in ["revision", "upstreamRevision", "sourceFingerprint"] {
            var invalid = metadata()
            invalid[key] = "invalid/../value"
            suite.expect(decode(invalid) == nil, "invalid build hashes are rejected before making a request")
        }
        var unknown = metadata(test: record())
        unknown["sourceFingerprint"] = NSNull()
        suite.expect(decode(unknown)?.testMatchesBuild == false,
                     "unknown source identity never implies a current test pass")
        suite.expect(decode(metadata())?.test == nil &&
                     DeveloperBuildSnapshot.decode(Data("broken".utf8)) == nil &&
                     DeveloperBuildSnapshot.decode(Data(repeating: 32, count: 128_001)) == nil,
                     "missing, invalid and oversized metadata stays unknown")
        var future = metadata()
        future["schemaVersion"] = 2
        suite.expect(decode(future) == nil, "unrecognized build metadata versions are rejected")
        checkBundles(suite)
        for language in AppLanguage.allCases {
            let strings = DeveloperUpdateStrings(language: language)
            suite.expect(!strings.title.isEmpty && !strings.fullPassed.isEmpty &&
                         strings.fullPassed != strings.selectedPassed && !strings.sourceChanged.isEmpty &&
                         !strings.versionDetails.isEmpty && !strings.buildInfo.isEmpty && !strings.viewChanges.isEmpty,
                         "status labels retain explicit full and partial scope in every language")
            for error in [DeveloperUpdateError.missingBuildInfo, .network, .rateLimited,
                          .unavailable, .invalidResponse, .historyChanged] {
                suite.expect(!strings.error(error).isEmpty, "update failures have safe recovery text")
            }
        }

        let finished = DispatchSemaphore(value: 0)
        Task { @MainActor in
            await checkNetwork(suite)
            await checkService(suite)
            finished.signal()
        }
        let deadline = Date().addingTimeInterval(10)
        var completed = false
        while Date() < deadline {
            if finished.wait(timeout: .now()) == .success { completed = true; break }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        suite.expect(completed, "developer update fixtures finish within a bounded wait")
    }

    private static func checkBundles(_ suite: TestSuite) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        do {
            for identifier in ["com.vorssaint.fixture", "com.vorssaint.fixture.dev"] {
                let folder = root.appendingPathComponent(identifier + ".app")
                let contents = folder.appendingPathComponent("Contents")
                let resources = contents.appendingPathComponent("Resources")
                try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
                let info = try PropertyListSerialization.data(fromPropertyList:
                    ["CFBundleIdentifier": identifier, "CFBundlePackageType": "APPL"],
                    format: .xml, options: 0)
                try info.write(to: contents.appendingPathComponent("Info.plist"))
                try JSONSerialization.data(withJSONObject: metadata(test: record()))
                    .write(to: resources.appendingPathComponent("DeveloperBuildStatus.json"))
                let bundle = Bundle(url: folder)!
                suite.expect((DeveloperBuildSnapshot.load(from: bundle) != nil) == identifier.hasSuffix(".dev"),
                             "only Developer bundles expose build-status metadata")
            }
        } catch { suite.expect(false, "isolated bundle metadata fixtures can be read") }
    }

    private static func payload(status: String = "ahead", ahead: Int = 202, behind: Int = 0,
                                base: String = upstream) -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "status": status, "ahead_by": ahead, "behind_by": behind,
            "base_commit": ["sha": base], "commits": [["sha": revision]],
        ])
    }

    private static func response(_ request: URLRequest, status: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    private static func checkNetwork(_ suite: TestSuite) async {
        let changes = DeveloperUpstreamClient.changesURL(base: upstream)
        suite.expect(changes?.scheme == "https" && changes?.host == "github.com" &&
                     changes?.path == "/vorssaint/vorssaint-utils/compare/\(upstream)...main" &&
                     changes?.query == nil && changes?.fragment == nil,
                     "upstream changes open the official comparison from the installed upstream base")
        suite.expect(DeveloperUpstreamClient.changesURL(base: upstream.uppercased()) == changes,
                     "comparison links normalize valid uppercase commit IDs")
        for base in [nil, "", "main", "../main", String(repeating: "g", count: 40), upstream + "/main"] {
            suite.expect(DeveloperUpstreamClient.changesURL(base: base) == nil,
                         "missing or untrusted commit IDs cannot become comparison links")
        }
        do {
            let request = try DeveloperUpstreamClient.makeRequest(base: upstream)
            suite.expect(request.url?.scheme == "https" && request.url?.host == "api.github.com" &&
                         request.url?.path == "/repos/vorssaint/vorssaint-utils/compare/\(upstream)...main" &&
                         request.httpBody == nil && request.value(forHTTPHeaderField: "Authorization") == nil,
                         "upstream checks send only a public base SHA to the fixed HTTPS repository")
            suite.expect(request.url?.query == "per_page=1&page=2",
                         "the check omits expensive changed-file patches")
            let client = DeveloperUpstreamClient { request in (payload(), response(request)) }
            suite.expect(try await client.compare(base: upstream).ahead == 202,
                         "the upstream count uses ahead_by rather than the paginated commit array")
            let synced = DeveloperUpstreamClient { request in
                (payload(status: "identical", ahead: 0), response(request))
            }
            suite.expect(try await synced.compare(base: upstream).ahead == 0,
                         "an identical verified upstream explicitly reports zero")
        } catch { suite.expect(false, "valid upstream comparison fixtures succeed") }
        for (status, expected) in [(403, DeveloperUpdateError.rateLimited), (429, .rateLimited),
                                   (404, .unavailable), (503, .unavailable), (302, .invalidResponse)] {
            let client = DeveloperUpstreamClient { request in (Data(), response(request, status: status)) }
            do {
                _ = try await client.compare(base: upstream)
                suite.expect(false, "HTTP failures cannot imply synchronization")
            } catch { suite.expect(error as? DeveloperUpdateError == expected, "HTTP errors remain explicit and safe") }
        }
        for data in [Data("{}".utf8), Data(repeating: 32, count: 1_000_001),
                     payload(base: revision), payload(ahead: -1), payload(status: "identical", ahead: 1)] {
            let client = DeveloperUpstreamClient { request in (data, response(request)) }
            do {
                _ = try await client.compare(base: upstream)
                suite.expect(false, "malformed comparison data is rejected")
            } catch { suite.expect(error as? DeveloperUpdateError == .invalidResponse, "unverified counts never become zero") }
        }
        let divergent = DeveloperUpstreamClient { request in
            (payload(status: "diverged", ahead: 2, behind: 3), response(request))
        }
        do {
            _ = try await divergent.compare(base: upstream)
            suite.expect(false, "divergent history cannot verify a pending count")
        } catch { suite.expect(error as? DeveloperUpdateError == .historyChanged, "rewritten history requires review") }
        var calls = 0
        let never = DeveloperUpstreamClient { request in calls += 1; return (payload(), response(request)) }
        for base in ["", "main", "../main", String(repeating: "g", count: 40)] {
            do {
                _ = try await never.compare(base: base)
                suite.expect(false, "invalid SHA cannot reach transport")
            } catch { suite.expect(error as? DeveloperUpdateError == .missingBuildInfo && calls == 0,
                                   "invalid metadata never reaches the network") }
        }
        let offline = DeveloperUpstreamClient { _ in throw URLError(.notConnectedToInternet) }
        do {
            _ = try await offline.compare(base: upstream)
            suite.expect(false, "offline checks cannot succeed")
        } catch { suite.expect(error as? DeveloperUpdateError == .network, "connection failure remains unknown") }
    }

    @MainActor
    private static func checkService(_ suite: TestSuite) async {
        let missing = DeveloperUpdateService(snapshot: nil)
        await missing.refresh()
        suite.expect(missing.error == .missingBuildInfo && missing.comparison == nil && !missing.isChecking,
                     "missing installed metadata never silently checks the working tree")
        var calls = 0
        let client = DeveloperUpstreamClient { request in
            calls += 1
            if calls == 1 { return (payload(), response(request)) }
            throw URLError(.notConnectedToInternet)
        }
        let model = DeveloperUpdateService(snapshot: decode(metadata(test: record())), client: client)
        suite.expect(model.comparison == nil && calls == 0, "opening settings does not trigger background network checks")
        await model.refresh()
        let checked = model.lastChecked
        suite.expect(model.comparison?.ahead == 202 && checked != nil && model.error == nil && !model.isChecking,
                     "successful manual refresh records its count and check time")
        await model.refresh()
        suite.expect(model.comparison?.ahead == 202 && model.lastChecked == checked &&
                     model.error == .network && !model.isChecking,
                     "offline refresh retains a clearly stale prior count and its original timestamp")
        var slowCalls = 0
        let slow = DeveloperUpstreamClient { request in
            slowCalls += 1
            try await Task.sleep(nanoseconds: 20_000_000)
            return (payload(), response(request))
        }
        let single = DeveloperUpdateService(snapshot: decode(metadata()), client: slow)
        async let first: Void = single.refresh()
        async let second: Void = single.refresh()
        _ = await (first, second)
        suite.expect(slowCalls == 1 && single.comparison?.ahead == 202,
                     "duplicate clicks share one in-flight check")
    }
}
