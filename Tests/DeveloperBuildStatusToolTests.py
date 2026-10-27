#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

"""Developer metadata tests use disposable Git repos, never the active checkout."""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.dont_write_bytecode = True
REPOSITORY = Path(__file__).resolve().parents[1]
TOOL = REPOSITORY / "Tools/developer_build_status.py"
spec = importlib.util.spec_from_file_location("developer_build_status", TOOL)
status = importlib.util.module_from_spec(spec)
spec.loader.exec_module(status)


class DeveloperBuildStatusToolTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="vorssaint-status-tests-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / "Sources").mkdir()
        (self.root / "Tools").mkdir()
        (self.root / "Sources/Fixture.swift").write_text("let number = 1\n")
        (self.root / ".gitignore").write_text("build/\n")
        shutil.copyfile(TOOL, self.root / "Tools/developer_build_status.py")
        self.git("init", "-q")
        self.commit()
        self.git("update-ref", "refs/remotes/upstream/main", "HEAD")

    def git(self, *arguments):
        return subprocess.check_output(
            ["git", "-c", "core.hooksPath=/dev/null", "-c", "commit.gpgSign=false",
             "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", *arguments],
            cwd=self.root, stderr=subprocess.DEVNULL,
        )

    def commit(self):
        self.git("add", ".")
        self.git("commit", "-qm", "Fixture")

    def completed(self, suites=None, code=0):
        run_id = status.begin(self.root, suites or [])
        self.assertTrue(status.finish(self.root, run_id, code))
        return status.read_record(self.root)

    def test_full_pass_and_bundle_identity(self):
        record = self.completed()
        bundle = status.snapshot(self.root)
        self.assertEqual(record["state"], "passed")
        self.assertEqual(record["scope"], "full")
        self.assertEqual(record["suites"], [])
        self.assertGreaterEqual(record["finishedAt"], record["startedAt"])
        self.assertEqual(bundle["sourceFingerprint"], record["sourceFingerprint"])
        self.assertEqual(bundle["revision"], bundle["upstreamRevision"])
        self.assertFalse(bundle["dirty"])

    def test_new_run_replaces_previous_pass_with_incomplete(self):
        first = self.completed()
        status.begin(self.root, ["translation"])
        record = status.read_record(self.root)
        self.assertNotEqual(record["runID"], first["runID"])
        self.assertEqual(record["state"], "incomplete")
        self.assertIsNone(record["finishedAt"])
        self.assertEqual(record["scope"], "selected")
        self.assertEqual(record["suites"], ["translation"])

    def test_partial_failure_and_duplicate_suites(self):
        record = self.completed(["translation", "settings", "translation"], code=17)
        self.assertEqual(record["state"], "failed")
        self.assertEqual(record["scope"], "selected")
        self.assertEqual(record["suites"], ["settings", "translation"])

    def test_dirty_snapshots_differ_and_committing_does_not_invalidate(self):
        source = self.root / "Sources/Fixture.swift"
        source.write_text("let number = 2\n")
        record = self.completed()
        tested = record["sourceFingerprint"]
        self.assertTrue(status.snapshot(self.root)["dirty"])
        source.write_text("let number = 3\n")
        self.assertNotEqual(status.source_fingerprint(self.root), tested)
        source.write_text("let number = 2\n")
        self.commit()
        bundle = status.snapshot(self.root)
        self.assertFalse(bundle["dirty"])
        self.assertNotEqual(bundle["revision"], record["revision"])
        self.assertEqual(bundle["sourceFingerprint"], tested)

    def test_changed_sources_during_run_keep_the_outcome_but_mark_changed(self):
        run_id = status.begin(self.root, [])
        (self.root / "Sources/Fixture.swift").write_text("let changed = true\n")
        status.finish(self.root, run_id, 0)
        record = status.read_record(self.root)
        self.assertEqual(record["state"], "passed")
        self.assertTrue(record["sourceChanged"])
        self.assertNotEqual(record["sourceFingerprint"], status.source_fingerprint(self.root))

    def test_input_scope_includes_docs_and_untracked_files_but_excludes_build(self):
        original = status.source_fingerprint(self.root)
        (self.root / "build").mkdir()
        (self.root / "build/output.swift").write_text("generated")
        (self.root / "docs").mkdir()
        (self.root / "docs/note.md").write_text("unrelated")
        self.assertNotEqual(status.source_fingerprint(self.root), original)
        (self.root / "docs/note.md").unlink()
        self.assertEqual(status.source_fingerprint(self.root), original)
        for name in ("Sources/Extra.swift", "Tests/Test.py", "Tools/tool.py", "Resources/Info.plist",
                     "build.sh", "README.md", "CONTRIBUTING.md", "docs/guide.md"):
            path = self.root / name
            path.parent.mkdir(exist_ok=True)
            path.write_text("new input")
            self.assertNotEqual(status.source_fingerprint(self.root), original)
            path.unlink()
        self.assertEqual(status.source_fingerprint(self.root), original)

    def test_deleted_file_and_its_committed_deletion_match(self):
        (self.root / "Sources/Fixture.swift").unlink()
        before = status.source_fingerprint(self.root)
        self.commit()
        self.assertEqual(status.source_fingerprint(self.root), before)

    def test_non_file_input_is_unknown_instead_of_blocking(self):
        os.symlink(self.root, self.root / "Sources/FolderLink")
        self.assertIsNone(status.source_fingerprint(self.root))

    def test_old_run_cannot_overwrite_newer_or_completed_run(self):
        first = status.begin(self.root, [])
        second = status.begin(self.root, ["settings"])
        self.assertFalse(status.finish(self.root, first, 0))
        self.assertEqual(status.read_record(self.root)["runID"], second)
        self.assertTrue(status.finish(self.root, second, 1))
        self.assertFalse(status.finish(self.root, second, 0))
        self.assertEqual(status.read_record(self.root)["state"], "failed")

    def test_missing_invalid_and_oversized_records_remain_unknown(self):
        self.assertIsNone(status.snapshot(self.root)["test"])
        path = self.root / status.RECORD_NAME
        path.parent.mkdir(exist_ok=True)
        for content in ("not JSON", "[]", '{"schemaVersion": 99}', " " * (64 * 1024 + 1)):
            path.write_text(content)
            self.assertIsNone(status.snapshot(self.root)["test"])
        record = self.completed()
        for key, value in (("startedAt", float("nan")), ("startedAt", 10 ** 1000), ("sourceFingerprint", "wrong"),
                           ("revision", "a" * 64),
                           ("sourceChanged", 1), ("finishedAt", None)):
            broken = dict(record, **{key: value})
            path.write_text(json.dumps(broken))
            self.assertIsNone(status.read_record(self.root))

    def test_extra_fields_are_not_bundled(self):
        record = self.completed()
        record["output"] = "private test output"
        record["repositoryPath"] = str(self.root)
        status.write_json(self.root / status.RECORD_NAME, record)
        bundle = status.snapshot(self.root)
        self.assertNotIn("output", bundle["test"])
        self.assertNotIn("repositoryPath", bundle["test"])
        self.assertNotIn(str(self.root), json.dumps(bundle))

    def test_no_git_metadata_is_unknown(self):
        shutil.rmtree(self.root / ".git")
        bundle = status.snapshot(self.root)
        self.assertIsNone(bundle["revision"])
        self.assertIsNone(bundle["upstreamRevision"])
        self.assertIsNone(bundle["sourceFingerprint"])
        self.assertTrue(bundle["dirty"])

    def initial_snapshot(self):
        path = self.root / "build/initial.json"
        captured = status.snapshot(self.root)
        status.write_json(path, captured)
        return path, captured

    def test_packaging_unchanged_sources_retains_captured_identity(self):
        self.completed()
        initial, captured = self.initial_snapshot()
        packaged = status.snapshot(self.root, initial)
        self.assertEqual(packaged, captured)
        self.assertEqual(status.commit_label(packaged), captured["revision"][:8])

    def test_capture_keeps_its_revision_anchor_when_head_changes_while_hashing(self):
        captured_revision = status.revision(self.root, "rev-parse", "HEAD")
        fingerprint = status.source_fingerprint

        def changed_during_fingerprint(root):
            (root / "Sources/Fixture.swift").write_text("let changedWhileHashing = true\n")
            value = fingerprint(root)
            self.git("commit", "--allow-empty", "-qm", "Metadata only")
            self.git("update-ref", "refs/remotes/upstream/main", "HEAD")
            return value

        with mock.patch.object(status, "source_fingerprint", side_effect=changed_during_fingerprint):
            captured = status.snapshot(self.root)
        self.assertNotEqual(captured_revision, status.revision(self.root, "rev-parse", "HEAD"))
        self.assertEqual(captured["revision"], captured_revision)
        self.assertEqual(captured["upstreamRevision"], captured_revision)
        self.assertEqual(captured["sourceFingerprint"], fingerprint(self.root))
        self.assertTrue(captured["dirty"])

    def test_source_change_during_build_clears_verified_fingerprint_and_keeps_start_identity(self):
        self.completed()
        initial, captured = self.initial_snapshot()
        (self.root / "Sources/Fixture.swift").write_text("let changedWhileCompiling = true\n")
        self.commit()
        self.git("update-ref", "refs/remotes/upstream/main", "HEAD")
        self.assertNotEqual(status.snapshot(self.root)["revision"], captured["revision"])
        packaged = status.snapshot(self.root, initial)
        self.assertIsNone(packaged["sourceFingerprint"])
        self.assertTrue(packaged["dirty"])
        self.assertEqual(packaged["revision"], captured["revision"])
        self.assertEqual(packaged["upstreamRevision"], captured["upstreamRevision"])
        self.assertEqual(packaged["test"], captured["test"])
        self.assertEqual(status.commit_label(packaged), captured["revision"][:8] + "-dirty")

    def test_commit_during_build_keeps_matching_content_and_captured_revision(self):
        (self.root / "Sources/Fixture.swift").write_text("let testedDirtyInput = true\n")
        self.completed()
        initial, captured = self.initial_snapshot()
        self.assertTrue(captured["dirty"])
        self.commit()
        packaged = status.snapshot(self.root, initial)
        self.assertNotEqual(packaged["revision"], status.snapshot(self.root)["revision"])
        self.assertEqual(packaged["revision"], captured["revision"])
        self.assertEqual(packaged["sourceFingerprint"], captured["sourceFingerprint"])
        self.assertEqual(packaged["sourceFingerprint"], packaged["test"]["sourceFingerprint"])
        self.assertTrue(packaged["dirty"])

    def test_missing_or_corrupt_initial_snapshot_never_uses_end_checkout_identity(self):
        initial, captured = self.initial_snapshot()
        invalid = [None, "not JSON", {"schemaVersion": 99}, dict(captured, revision="a" * 64),
                   dict(captured, dirty="false"), dict(captured, test={"state": "passed"})]
        for value in invalid:
            if value is None:
                initial.unlink(missing_ok=True)
            elif isinstance(value, str):
                initial.write_text(value)
            else:
                status.write_json(initial, value)
            packaged = status.snapshot(self.root, initial)
            self.assertIsNone(packaged["revision"])
            self.assertIsNone(packaged["upstreamRevision"])
            self.assertIsNone(packaged["sourceFingerprint"])
            self.assertIsNone(packaged["test"])
            self.assertTrue(packaged["dirty"])
            self.assertEqual(status.commit_label(packaged), "unknown-dirty")

    def test_unknown_source_at_either_build_endpoint_cannot_be_verified(self):
        initial, captured = self.initial_snapshot()
        folder_link = self.root / "Sources/FolderLink"
        os.symlink(self.root, folder_link)
        self.assertIsNone(status.snapshot(self.root, initial)["sourceFingerprint"])
        self.assertTrue(status.snapshot(self.root, initial)["dirty"])
        unknown = status.snapshot(self.root)
        status.write_json(initial, unknown)
        folder_link.unlink()
        self.assertEqual(status.source_fingerprint(self.root), captured["sourceFingerprint"])
        self.assertIsNone(status.snapshot(self.root, initial)["sourceFingerprint"])

    def test_snapshot_cli_prints_the_same_captured_commit_as_the_bundle(self):
        initial, captured = self.initial_snapshot()
        (self.root / "Sources/Fixture.swift").write_text("let changedWhileCompiling = true\n")
        output = self.root / "build/bundled.json"
        label = subprocess.check_output([
            sys.executable, str(self.root / "Tools/developer_build_status.py"), "snapshot",
            "--output", str(output), "--initial", str(initial), "--print-commit",
        ], cwd=self.root, text=True).strip()
        packaged = json.loads(output.read_text())
        self.assertEqual(label, status.commit_label(packaged))
        self.assertEqual(label, captured["revision"][:8] + "-dirty")

    def test_real_exit_cleanup_records_success_and_failure_without_changing_exit(self):
        prefix = (REPOSITORY / "build.sh").read_text().split("# Flags:", 1)[0]
        (self.root / "build.sh").write_text(prefix + '\nTEST_STATUS_RUN_ID="$1"\nDEV_STATUS_TMP="$3"\nexit "$2"\n')
        for code, expected in ((0, "passed"), (17, "failed")):
            run_id = status.begin(self.root, [])
            temporary_snapshot = self.root / "build/temporary-snapshot.json"
            temporary_snapshot.write_text("temporary")
            process = subprocess.run(["/bin/zsh", str(self.root / "build.sh"), run_id, str(code), str(temporary_snapshot)],
                                     cwd=self.root, capture_output=True)
            self.assertEqual(process.returncode, code, process.stderr.decode())
            record = status.read_record(self.root)
            self.assertEqual(record["state"], expected)
            self.assertFalse(record["sourceChanged"])
            self.assertFalse(temporary_snapshot.exists())

    def test_list_only_does_not_replace_record(self):
        prefix = (REPOSITORY / "build.sh").read_text().split("if (( DEV )); then", 1)[0]
        (self.root / "build.sh").write_text(prefix)
        self.completed()
        before = (self.root / status.RECORD_NAME).read_bytes()
        subprocess.run(["/bin/zsh", str(self.root / "build.sh"), "--list-tests"],
                       cwd=self.root, check=True, capture_output=True)
        self.assertEqual((self.root / status.RECORD_NAME).read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
