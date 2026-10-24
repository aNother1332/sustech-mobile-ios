"""Boot iPhone and iPad simulators, launch demo/login UI, and save screenshots.

No real credentials or network login are used. Requires the cloud Debug simulator build.
"""
from pathlib import Path
import json
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "dist" / "simulator-smoke"
APP = ROOT / "DerivedData/Build/Products/Debug-iphonesimulator/SUSTech.app"
BUNDLE = "cn.sustech.community.daily"

def run(*args):
    return subprocess.check_output(["xcrun", "simctl", *map(str, args)], text=True)

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    devices = json.loads(run("list", "devices", "available", "--json"))["devices"]
    available = [device for group in devices.values() for device in group]
    for family in ("iPhone", "iPad"):
        device = next(device for device in available if device["name"].startswith(family))
        uid = device["udid"]
        print(f"Smoke test: {device['name']}", flush=True)
        if device["state"] != "Booted":
            run("boot", uid)
        run("bootstatus", uid, "-b")
        try:
            run("install", uid, APP)
            for scene, argument in (("today", "--smoke-demo"), ("native-login", "--smoke-login")):
                run("launch", "--terminate-running-process", uid, BUNDLE, argument)
                time.sleep(3)
                run("io", uid, "screenshot", OUT / f"{family}-{scene}.png")
                # Terminate must succeed: a process that already crashed fails here.
                run("terminate", uid, BUNDLE)
            time.sleep(2)
            run("io", uid, "screenshot", OUT / f"{family}-home.png")
        finally:
            run("shutdown", uid)
    print("PASS: iPhone/iPad demo and native-login launch/capture completed.", flush=True)

if __name__ == "__main__":
    main()
