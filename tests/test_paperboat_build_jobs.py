"""Real PaperBoat entrypoint with logged tools; no game/dependency/app build."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
STOP = 73
TOOL = r'''
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
# The scene-capable SDL pin check was added after this harness. Supply a clean
# synthetic SDL checkout; unexpected Git operations still fail below.
if name == "python3" and args[0] == "-c":
    print("locked-sdl" if "commit" in args[1] else "https://example.invalid/sdl")
    sys.exit(0)
if name == "git" and args[:1] == ["-C"] and args[1].endswith("/ref/SDL2"):
    if args[2:] == ["rev-parse", "HEAD"]:
        print("locked-sdl")
        sys.exit(0)
    if args[2:] == ["status", "--porcelain"]:
        sys.exit(0)
log_path = pathlib.Path(os.environ["TEST_LOG"])
prior = [json.loads(line) for line in log_path.read_text().splitlines()] if log_path.exists() else []
with log_path.open("a") as log:
    log.write(json.dumps([name] + args) + "\n")
if name == "git":
    sys.exit(74)
if name == "python3" and args[0].endswith("verify-paperboat.py"):
    ordinal = 1 + sum(c[0] == "python3" and c[1].endswith("verify-paperboat.py") for c in prior)
    if str(ordinal) == os.environ.get("REFUSE_VERIFIER"):
        sys.exit(74)
if name == "cmake" and "--build" in args:
    sys.exit(73)  # No actual compilation or later provenance/package writes.
'''


class PaperBoatBuildJobsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="paperboat-jobs-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "scripts").mkdir()
        shutil.copy2(ROOT / "scripts/build-paperboat.sh", self.root / "scripts/build-paperboat.sh")
        (self.root / "vendor/paperboat/.git").mkdir(parents=True)
        (self.root / "ref/SDL2").mkdir(parents=True)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("cmake", "python3", "git"):
            file = self.bin / name
            file.write_text("#!" + sys.executable + "\n" + TOOL)
            file.chmod(0o755)
        self.log = self.root / "calls.jsonl"
        self.env = os.environ.copy()
        for key in ("PAPERPAD_BUILD_JOBS", "CMAKE_BUILD_PARALLEL_LEVEL", "BASH_ENV"):
            self.env.pop(key, None)
        self.env.update(PATH=str(self.bin) + ":/usr/bin:/bin", TEST_LOG=str(self.log))

    def run_script(self, mode="device", **overrides):
        return subprocess.run(["/bin/bash", str(self.root / "scripts/build-paperboat.sh"), mode],
                              env=dict(self.env, **overrides), text=True,
                              capture_output=True, timeout=10)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] \
            if self.log.exists() else []

    def clear_log(self):
        if self.log.exists():
            self.log.unlink()

    def snapshot(self):
        return {str(p.relative_to(self.root)): p.read_bytes() if p.is_file() else None
                for p in self.root.rglob("*")}

    def assert_jobs(self, result, expected, mode="device"):
        self.assertEqual(result.returncode, STOP, result.stdout + result.stderr)
        calls = self.calls()
        self.assertEqual([c[0] for c in calls], ["python3", "python3", "cmake", "python3", "cmake"])
        self.assertEqual(calls[-1][-2:], ["--parallel", expected])
        profile = "ios" if mode == "device" else "simulator"
        self.assertEqual(calls[-1][1:3], ["--build", str(self.root / ("build-paperboat-" + profile))])
        self.assertIn("-DPLATFORM=" + ("OS64" if mode == "device" else "SIMULATORARM64"), calls[2])
        self.assertIn("-DIOS_SIGNING=OFF", calls[2])
        self.assertTrue(calls[0][1].endswith("verify-paperboat.py"))
        self.assertTrue(calls[1][1].endswith("prepare-paperboat-downloads.py"))
        self.assertIn("-DCMAKE_PROJECT_INCLUDE_BEFORE=" + str(self.root / "scripts/paperboat-offline-downloads.cmake"), calls[2])
        self.assertEqual(calls[3][2:], ["--build-dir", calls[-1][2]])

    def test_standard_limit_reaches_both_profiles(self):
        for mode in ("device", "simulator"):
            with self.subTest(mode=mode):
                self.clear_log()
                result = self.run_script(mode, CMAKE_BUILD_PARALLEL_LEVEL="2")
                self.assert_jobs(result, "2", mode)

    def test_manual_override_precedence(self):
        for standard in ("2", "invalid"):
            with self.subTest(standard=standard):
                self.clear_log()
                result = self.run_script(PAPERPAD_BUILD_JOBS="3", CMAKE_BUILD_PARALLEL_LEVEL=standard)
                self.assert_jobs(result, "3")

    def test_unset_and_empty_retain_eight_job_default(self):
        for settings in ({}, {"PAPERPAD_BUILD_JOBS": "", "CMAKE_BUILD_PARALLEL_LEVEL": ""}):
            with self.subTest(settings=settings):
                self.clear_log()
                self.assert_jobs(self.run_script(**settings), "8")

    def test_empty_manual_setting_uses_standard_limit(self):
        self.assert_jobs(self.run_script(PAPERPAD_BUILD_JOBS="", CMAKE_BUILD_PARALLEL_LEVEL="1"), "1")

    def test_invalid_settings_stop_before_submodules_or_tools(self):
        (self.root / "vendor/paperboat/.git").rmdir()
        for variable in ("PAPERPAD_BUILD_JOBS", "CMAKE_BUILD_PARALLEL_LEVEL"):
            for value in ("0", "-1", "+2", "02", " 2", "2 ", "2\n", "many"):
                with self.subTest(variable=variable, value=value):
                    before = self.snapshot()
                    result = self.run_script(**{variable: value})
                    self.assertEqual(result.returncode, 2, result.stderr)
                    self.assertIn("positive whole number", result.stderr)
                    self.assertEqual(self.calls(), [])
                    self.assertEqual(self.snapshot(), before)

    def test_invalid_manual_setting_does_not_fall_back(self):
        result = self.run_script(PAPERPAD_BUILD_JOBS="0", CMAKE_BUILD_PARALLEL_LEVEL="2")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.calls(), [])

    def test_both_pin_verifiers_remain_fail_closed(self):
        for ordinal in ("1", "2"):
            with self.subTest(ordinal=ordinal):
                self.clear_log()
                result = self.run_script(CMAKE_BUILD_PARALLEL_LEVEL="2", REFUSE_VERIFIER=ordinal)
                self.assertEqual(result.returncode, 74)
                self.assertFalse(any(c[:2] == ["cmake", "--build"] for c in self.calls()))
                self.assertEqual(self.calls()[-1][0], "python3")

    def test_invalid_mode_still_stops_before_tools(self):
        result = self.run_script("unknown", CMAKE_BUILD_PARALLEL_LEVEL="2")
        self.assertEqual(result.returncode, 2)
        self.assertIn("usage:", result.stderr)
        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main()
