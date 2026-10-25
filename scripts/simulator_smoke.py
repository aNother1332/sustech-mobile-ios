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
            scenes = (
                ("today", ["--smoke-demo"]),
                ("timetable", ["--smoke-demo", "--smoke-study"]),
                ("exams", ["--smoke-demo", "--smoke-study", "--smoke-exams"]),
                ("grades", ["--smoke-demo", "--smoke-study", "--smoke-grades"]),
                ("blackboard", ["--smoke-demo", "--smoke-study", "--smoke-blackboard"]),
                ("services", ["--smoke-demo", "--smoke-services"]),
                ("account", ["--smoke-demo", "--smoke-account"]),
                ("native-login", ["--smoke-login"]),
                ("card", ["--smoke-demo", "--smoke-card"]),
                ("recharge", ["--smoke-demo", "--smoke-recharge"]),
                ("library", ["--smoke-demo", "--smoke-library"]),
                ("agenda", ["--smoke-demo", "--smoke-agenda"]),
                ("planner", ["--smoke-demo", "--smoke-planner"]),
                ("reviews", ["--smoke-demo", "--smoke-reviews"]),
                ("degree", ["--smoke-demo", "--smoke-degree"]),
                ("classrooms", ["--smoke-demo", "--smoke-classrooms"]),
                ("printing", ["--smoke-demo", "--smoke-printing"]),
                ("reservations", ["--smoke-demo", "--smoke-reservations"]),
                ("ic", ["--smoke-demo", "--smoke-ic"]),
                ("cle", ["--smoke-demo", "--smoke-cle"]),
                ("court", ["--smoke-demo", "--smoke-court"]),
                ("blackboard-folded", ["--smoke-demo", "--smoke-study", "--smoke-blackboard", "--smoke-folded"]),
                ("today-folded", ["--smoke-demo", "--smoke-folded"]),
            )
            for scene, arguments in scenes:
                run("launch", "--terminate-running-process", uid, BUNDLE, *arguments)
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
