// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct DeveloperTestRecord: Decodable {
    enum State: String, Decodable { case incomplete, passed, failed }
    enum Scope: String, Decodable { case full, selected }

    let schemaVersion: Int
    let runID: String
    let state: State
    let scope: Scope
    let suites: [String]
    let startedAt: Date
    let finishedAt: Date?
    let revision: String?
    let sourceFingerprint: String?
    let sourceChanged: Bool

    var isValid: Bool {
        guard schemaVersion == 1, UUID(uuidString: runID) != nil,
              startedAt.timeIntervalSince1970.isFinite,
              revision.map({ DeveloperBuildSnapshot.isHash($0, length: 40) }) ?? true,
              sourceFingerprint.map({ DeveloperBuildSnapshot.isHash($0, length: 64) }) ?? true,
              suites.count <= 128,
              suites.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 128 &&
                  $0.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) } }),
              (scope == .full ? suites.isEmpty : !suites.isEmpty) else { return false }
        if state == .incomplete { return finishedAt == nil }
        guard let finishedAt else { return false }
        return finishedAt.timeIntervalSince1970.isFinite && finishedAt >= startedAt
    }
}

/// Built source identity, independent of any later changes in the checkout.
struct DeveloperBuildSnapshot: Decodable {
    let schemaVersion: Int
    let revision: String?
    let dirty: Bool
    let sourceFingerprint: String?
    let upstreamRevision: String?
    let test: DeveloperTestRecord?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, revision, dirty, sourceFingerprint, upstreamRevision, test
    }

    init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try fields.decode(Int.self, forKey: .schemaVersion)
        revision = try fields.decodeIfPresent(String.self, forKey: .revision)
        dirty = try fields.decode(Bool.self, forKey: .dirty)
        sourceFingerprint = try fields.decodeIfPresent(String.self, forKey: .sourceFingerprint)
        upstreamRevision = try fields.decodeIfPresent(String.self, forKey: .upstreamRevision)
        let record = try? fields.decode(DeveloperTestRecord.self, forKey: .test)
        test = record?.isValid == true ? record : nil
        guard schemaVersion == 1,
              revision.map({ Self.isHash($0, length: 40) }) ?? true,
              upstreamRevision.map({ Self.isHash($0, length: 40) }) ?? true,
              sourceFingerprint.map({ Self.isHash($0, length: 64) }) ?? true else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Invalid developer build metadata"))
        }
    }

    var testMatchesBuild: Bool {
        guard let test, !test.sourceChanged,
              let fingerprint = sourceFingerprint, let tested = test.sourceFingerprint else { return false }
        return fingerprint == tested
    }

    static var bundled: Self? { load(from: .main) }

    static func load(from bundle: Bundle) -> Self? {
        guard bundle.bundleIdentifier?.hasSuffix(".dev") == true,
              let url = bundle.url(forResource: "DeveloperBuildStatus", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return decode(data)
    }

    static func decode(_ data: Data) -> Self? {
        guard data.count <= 128_000 else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(Self.self, from: data)
    }

    static func isHash(_ value: String, length: Int) -> Bool {
        value.utf8.count == length && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
        }
    }
}
