"""Boot iPhone and iPad simulators, launch demo/login UI, and save screenshots.

No real credentials or network login are used. Requires the cloud Debug simulator build.
"""
from pathlib import Path
import json
import os
import subprocess
import time
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "dist" / "simulator-smoke"
APP = ROOT / "DerivedData/Build/Products/Debug-iphonesimulator/SUSTech.app"
BUNDLE = "cn.sustech.community.daily"

def run(*args):
    return subprocess.check_output(["xcrun", "simctl", *map(str, args)], text=True)

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    devices = json.loads(run("list", "devices", "available", "--json"))["devices"]
    runtimes = sorted(((runtime, group) for runtime, group in devices.items() if ".iOS-" in runtime), key=lambda row: tuple(int(n) for n in re.findall(r"[0-9]+", row[0])), reverse=True)
    available = [(runtime, device) for runtime, group in runtimes for device in group]
    for family in ("iPhone", "iPad"):
        runtime, device = next((runtime, device) for runtime, device in available if device["name"].startswith(family))
        uid = device["udid"]
        print(f"Smoke test: {device['name']} on {runtime}", flush=True)
        if device["state"] != "Booted":
            run("boot", uid)
        run("bootstatus", uid, "-b")
        try:
            run("install", uid, APP)
            if family == "iPhone":
                subprocess.run(["xcodebuild", "-project", "SUSTech.xcodeproj", "-scheme", "SUSTech", "-configuration", "Debug", "-destination", f"platform=iOS Simulator,id={uid}", "-derivedDataPath", "DerivedData", "-parallel-testing-enabled", "NO", "CODE_SIGNING_ALLOWED=NO", "test", "-only-testing:SUSTechUITests"], check=True, timeout=360)
            scenes = (
                ("today", ["--smoke-demo"]),
                ("today-agenda", ["--smoke-demo", "--smoke-home-agenda"]),
                ("today-weather", ["--smoke-demo", "--smoke-home-weather"]),
                ("navigation-glass", ["--smoke-demo", "--smoke-tab-cycle"]),
                ("navigation-material", ["--smoke-demo", "--smoke-tab-cycle", "--smoke-force-material"]),
                ("learning-home", ["--smoke-demo", "--smoke-study"]),
                ("bus-timetable", ["--smoke-demo", "--smoke-bus", "--smoke-bus-drawer"]),
                ("bus-stop", ["--smoke-demo", "--smoke-bus", "--smoke-bus-stop"]),
                ("bus-vehicle", ["--smoke-demo", "--smoke-bus", "--smoke-bus-vehicle"]),
                ("bus-map", ["--smoke-demo", "--smoke-bus"]),
                ("bus-map-dark", ["--smoke-demo", "--smoke-bus", "--smoke-dark"]),
                ("faculty-detail", ["--smoke-demo", "--smoke-faculty-detail"]),
                ("study-large", ["--smoke-demo", "--smoke-study", "--smoke-large"]),
                ("today-dark", ["--smoke-demo", "--smoke-dark"]),
                ("services-dark", ["--smoke-demo", "--smoke-services", "--smoke-dark"]),
                ("faculty", ["--smoke-demo", "--smoke-faculty"]),
                ("faculty-filtered", ["--smoke-demo", "--smoke-faculty", "--smoke-faculty-filtered"]),
                ("calendar", ["--smoke-demo", "--smoke-calendar"]),
                ("code", ["--smoke-demo", "--smoke-code"]),
                ("exchange", ["--smoke-demo", "--smoke-exchange"]),
                ("widgets", ["--smoke-demo", "--smoke-widgets"]),
                ("timetable", ["--smoke-demo", "--smoke-study", "--smoke-timetable"]),
                ("exams", ["--smoke-demo", "--smoke-study", "--smoke-exams"]),
                ("grades", ["--smoke-demo", "--smoke-study", "--smoke-grades"]),
                ("blackboard", ["--smoke-demo", "--smoke-study", "--smoke-blackboard"]),
                ("services", ["--smoke-demo", "--smoke-services"]),
                ("account", ["--smoke-demo", "--smoke-account"]),
                ("settings", ["--smoke-demo", "--smoke-settings"]),
                ("my-reservations", ["--smoke-demo", "--smoke-my-reservations"]),
                ("native-login", ["--smoke-login"]),
                ("printing-login", ["--smoke-demo", "--smoke-printing-login"]),
                ("leave", ["--smoke-demo", "--smoke-leave"]),
                ("activities", ["--smoke-demo", "--smoke-activities"]),
                ("card", ["--smoke-demo", "--smoke-card"]),
                ("recharge", ["--smoke-demo", "--smoke-recharge"]),
                ("agenda", ["--smoke-demo", "--smoke-agenda"]),
                ("reviews", ["--smoke-demo", "--smoke-reviews"]),
                ("degree", ["--smoke-demo", "--smoke-degree"]),
                ("classrooms", ["--smoke-demo", "--smoke-classrooms"]),
                ("print-stations", ["--smoke-demo", "--smoke-print-stations"]),
                ("college", ["--smoke-demo", "--smoke-college"]),
                ("printing", ["--smoke-demo", "--smoke-printing"]),
                ("reservations", ["--smoke-demo", "--smoke-reservations"]),
                ("ic", ["--smoke-demo", "--smoke-ic"]),
                ("cle", ["--smoke-demo", "--smoke-cle"]),
                ("blackboard-folded", ["--smoke-demo", "--smoke-study", "--smoke-blackboard", "--smoke-folded"]),
                ("today-folded", ["--smoke-demo", "--smoke-folded"]),
            )
            selected = {item.strip() for item in os.environ.get("SMOKE_SCENES", "").split(",") if item.strip()}
            if selected - {name for name, _ in scenes}:
                raise ValueError("Unknown smoke scenes: " + str(selected - {name for name, _ in scenes}))
            for scene, arguments in scenes:
                if selected and scene not in selected:
                    continue
                print(f"Capture: {family} {scene}", flush=True)
                launched_at = time.time()
                run("launch", "--terminate-running-process", uid, BUNDLE, *arguments)
                time.sleep(15 if "--smoke-degree" in arguments else 6 if "--smoke-tab-cycle" in arguments else 3)
                if "--smoke-tab-cycle" in arguments:
                    container = Path(run("get_app_container", uid, BUNDLE, "data").strip())
                    check = json.loads((container / "Documents/smoke-navigation.json").read_text())
                    assert check["instances"] == 1 and check["updates"] >= 5, check
                    if "--smoke-force-material" not in arguments:
                        assert check["material"] == "native-glass", "Native glass requires an iOS 26+ simulator: " + str(check)
                    print("Navigation continuity: " + json.dumps(check), flush=True)
                if "--smoke-bus" in arguments:
                    container = Path(run("get_app_container", uid, BUNDLE, "data").strip())
                    check = json.loads((container / "Documents/smoke-bus-map.json").read_text())
                    assert check["at"] >= launched_at - 1 and all(check[key] > 0 for key in ("routes", "points", "stops", "vehicles")), check
                    print("Bus map populated: " + json.dumps(check), flush=True)
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
