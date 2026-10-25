import hashlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import urllib.error
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('paperboat_downloads', ROOT / 'scripts/prepare-paperboat-downloads.py')
downloads = importlib.util.module_from_spec(spec)
spec.loader.exec_module(downloads)


class DownloadsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='paperboat downloads ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.name = '_deps/stb/header.h'
        self.target = self.root / self.name
        self.data = b'locked public header\n'
        self.digest = hashlib.sha256(self.data).hexdigest()
        self.lock = {'fetchedFiles': {self.name: self.digest},
                     'fetchedFileUrls': {self.name: 'https://example.invalid/pinned/header.h'}}
        pause = patch.object(downloads.time, 'sleep')
        pause.start()
        self.addCleanup(pause.stop)

    def prepare(self):
        downloads.prepare(self.root, self.lock)

    def test_verified_cache_needs_no_network_and_keeps_mtime(self):
        self.target.parent.mkdir(parents=True)
        self.target.write_bytes(self.data)
        before = self.target.stat().st_mtime_ns
        with patch.object(downloads.urllib.request, 'urlopen') as get:
            self.prepare()
        get.assert_not_called()
        self.assertEqual(self.target.stat().st_mtime_ns, before)

    def test_transient_http_failure_retries_then_commits_verified_bytes(self):
        failure = urllib.error.HTTPError('url', 503, 'unavailable', {}, None)
        with patch.object(downloads.urllib.request, 'urlopen', side_effect=[failure, io.BytesIO(self.data)]) as get:
            self.prepare()
        self.assertEqual(get.call_count, 2)
        self.assertEqual(self.target.read_bytes(), self.data)
        self.assertEqual(list(self.target.parent.iterdir()), [self.target])

    def test_wrong_content_never_replaces_prior_file_and_leaves_no_partials(self):
        self.target.parent.mkdir(parents=True)
        self.target.write_bytes(b'preserved existing content')
        with patch.object(downloads.urllib.request, 'urlopen', side_effect=lambda *a, **k: io.BytesIO(b'HTTP error page')) as get:
            with self.assertRaisesRegex(ValueError, 'hash mismatch'):
                self.prepare()
        self.assertEqual(get.call_count, 3)
        self.assertEqual(self.target.read_bytes(), b'preserved existing content')
        self.assertEqual(list(self.target.parent.iterdir()), [self.target])

    def test_stale_download_is_repaired_only_with_verified_content(self):
        self.target.parent.mkdir(parents=True)
        self.target.write_bytes(b'')
        with patch.object(downloads.urllib.request, 'urlopen', return_value=io.BytesIO(self.data)):
            self.prepare()
        self.assertEqual(self.target.read_bytes(), self.data)

    def test_missing_url_stops_before_network_or_writes(self):
        self.lock['fetchedFileUrls'].clear()
        with patch.object(downloads.urllib.request, 'urlopen') as get:
            with self.assertRaisesRegex(ValueError, 'pinned URL'):
                self.prepare()
        get.assert_not_called()
        self.assertEqual(list(self.root.iterdir()), [])

    def test_all_real_sources_are_commit_pinned_and_match_hash_inventory(self):
        lock = json.loads((ROOT / 'paperboat.lock.json').read_text())
        self.assertEqual(set(lock['fetchedFiles']), set(lock['fetchedFileUrls']))
        for url in lock['fetchedFileUrls'].values():
            self.assertRegex(url, r'^https://raw\.githubusercontent\.com/[^/]+/[^/]+/[0-9a-f]{40}/')

    @unittest.skipUnless(shutil.which('cmake'), 'CMake required for actual offline download interception')
    def test_cmake_keeps_prepared_files_and_refuses_missing_or_changed_input(self):
        self.target.parent.mkdir(parents=True)
        self.target.write_bytes(self.data)
        script = self.root / 'probe.cmake'
        adapter = (ROOT / 'scripts/paperboat-offline-downloads.cmake').as_posix()
        script.write_text('include([=[' + adapter + ']=])\n'
                          'file(DOWNLOAD https://example.invalid/unreachable [=[' + self.target.as_posix() + ']=] '
                          'EXPECTED_HASH SHA256=' + self.digest + ' STATUS result)\n'
                          'if(NOT result MATCHES "^0;")\nmessage(FATAL_ERROR "missing status")\nendif()\n')
        def run():
            return subprocess.run(['cmake', '-P', str(script)], text=True, capture_output=True, timeout=15)
        result = run()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.target.read_bytes(), self.data)
        self.target.write_bytes(b'changed')
        self.assertNotEqual(run().returncode, 0)
        self.target.unlink()
        self.assertNotEqual(run().returncode, 0)


if __name__ == '__main__':
    unittest.main()
