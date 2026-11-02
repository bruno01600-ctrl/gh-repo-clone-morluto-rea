"""scripts/stayawake.sh against a pretend Chromecast with Google TV: the sleep and CEC
standby settings are switched off, and --undo puts back exactly what was there.

Run: python3 -m unittest discover -s tests -v
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
AWAKE = {
    "system/screen_off_timeout": "2147483647",
    "secure/sleep_timeout": "-1",
    "secure/attentive_timeout": "-1",
    "global/stay_on_while_plugged_in": "7",
    "global/hdmi_control_auto_device_off_enabled": "0",
}
BEFORE = {
    "system/screen_off_timeout": "900000",
    "secure/sleep_timeout": "1800000",
    "global/hdmi_control_auto_device_off_enabled": "1",
}


class StayAwakeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        tmp = Path(self.tmp.name)
        self.state = tmp / "state.json"
        self.log = tmp / "commands.log"
        self.log.touch()
        self.write({"packages": {}, "settings": dict(BEFORE), "sdk": 31,
                    "props": {"ro.product.manufacturer": "Google"}})

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, data):
        self.state.write_text(json.dumps(data))

    def run_script(self, *flags):
        env = dict(os.environ, ADB=str(ROOT / "tests" / "fake_tv.py"), ADB_SERIAL="test-tv",
                   FAKE_TV_STATE=str(self.state), FAKE_TV_LOG=str(self.log))
        result = subprocess.run(["bash", str(ROOT / "scripts" / "stayawake.sh"), *flags],
                                env=env, capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return json.loads(self.state.read_text())["settings"]

    def awake(self, settings):
        return {k: settings.get(k) for k in AWAKE}

    def test_keeps_the_device_awake(self):
        self.assertEqual(self.awake(self.run_script("-y")), AWAKE)

    def test_undo_puts_back_what_was_there(self):
        self.run_script("-y")
        self.assertEqual(self.run_script("--undo"), BEFORE)

    def test_a_second_run_still_undoes_to_the_original(self):
        self.run_script("-y")
        self.run_script("-y")
        self.assertEqual(self.run_script("--undo"), BEFORE)

    def test_dry_run_changes_nothing(self):
        self.assertEqual(self.run_script("-y", "--dry-run"), BEFORE)

    def test_refuses_a_fire_tv(self):
        data = json.loads(self.state.read_text())
        data["props"] = {}
        self.write(data)
        env = dict(os.environ, ADB=str(ROOT / "tests" / "fake_tv.py"), ADB_SERIAL="test-tv",
                   FAKE_TV_STATE=str(self.state), FAKE_TV_LOG=str(self.log))
        result = subprocess.run(["bash", str(ROOT / "scripts" / "stayawake.sh"), "-y"],
                                env=env, capture_output=True, text=True, timeout=60)
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
