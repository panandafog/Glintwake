"""Inspect installed devices and prepare local capture configs; never launch an app."""
import copy
import json
import pathlib
import plistlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEST = ROOT / "Build" / "FramePilot"
SCENES = ["gameplay", "planning", "difficulty", "victory"]


def command(*args):
    return json.loads(subprocess.check_output(args, text=True, timeout=180))


def choose_devices():
    types = command("xcrun", "simctl", "list", "devicetypes", "-j")["devicetypes"]
    eligible = {}
    # Current Apple screenshot slots; prefer large iPhone and 13-inch iPad.
    sizes = {"iPhone": {(1320, 2868), (1290, 2796), (1260, 2736), (1284, 2778), (1242, 2688)},
             "iPad": {(2064, 2752), (2048, 2732)}}
    for item in types:
        family = item.get("productFamily")
        if family not in sizes:
            continue
        path = pathlib.Path(item["bundlePath"]) / "Contents/Resources/capabilities.plist"
        try:
            screen = plistlib.loads(path.read_bytes())["capabilities"]["ScreenDimensionsCapability"]
            pixels = (screen["main-screen-width"], screen["main-screen-height"])
        except (OSError, KeyError, plistlib.InvalidFileException):
            continue
        if pixels in sizes[family]:
            eligible[item["identifier"]] = family
    inventory = command("xcrun", "simctl", "list", "devices", "available", "-j")["devices"]
    selected = {}
    for runtime in sorted(inventory, key=lambda value: tuple(map(int, re.findall(r"\d+", value))), reverse=True):
        for device in inventory[runtime]:
            family = eligible.get(device.get("deviceTypeIdentifier"))
            if not family or family in selected or device["name"].startswith("FramePilot "):
                continue
            selected[family] = dict(id=device["udid"], name=device["name"], family=family,
                                    runtime=runtime, deviceType=device["deviceTypeIdentifier"])
    if set(selected) != {"iPhone", "iPad"}:
        raise SystemExit("Install an available large iPhone and 13-inch iPad simulator in Xcode, then run prepare again.")
    return [selected["iPhone"], selected["iPad"]]


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 Scripts/prepare-framepilot.py /path/to/framepilot")
    base = command(sys.argv[1], "inspect", str(ROOT / "Glintwake.xcodeproj"), "Glintwake")
    base.update(mode="scenes", scenes=SCENES, devices=choose_devices(), languages=["en-US", "ru-RU"],
                appearance="dark", sceneArgumentPrefix="--screenshot-scene=", settlingSeconds=4,
                outputPath=str(DEST / "Runs"), onlyTesting="")
    desktop = copy.deepcopy(base)
    desktop.update(scheme="Glintwake Screenshots", mode="uiTests",
                   devices=[dict(id="local-mac", name="Mac", family="macOS", runtime="macOS", deviceType="mac")],
                   onlyTesting="\n".join(f"GlintwakeScreenshots/StoreScreenshots/test{i:02d}{scene.title()}"
                                         for i, scene in enumerate(SCENES, 1)))
    DEST.mkdir(parents=True, exist_ok=True)
    presets = [("ios", base), ("macos", desktop)]
    inventory = command("xcrun", "simctl", "list", "devices", "available", "-j")["devices"]
    candidates = [(runtime, device) for runtime, devices in inventory.items() for device in devices
                  if device.get("deviceTypeIdentifier") == "com.apple.CoreSimulator.SimDeviceType.iPhone-Duo"
                  and not device["name"].startswith("FramePilot ")]
    if candidates:
        runtime, device = max(candidates, key=lambda item: (
            tuple(map(int, re.findall(r"\d+", item[0]))), item[1]["name"] == "iPhone Duo"))
        duo = copy.deepcopy(base)
        # Duo can show only its system status area while the app is still opening.
        # Give scene launch more time before FramePilot's pixel-stability check.
        duo["settlingSeconds"] = 12
        duo["devices"] = [dict(id=device["udid"], name=device["name"], family="iPhone", runtime=runtime,
                               deviceType=device["deviceTypeIdentifier"], displays=["primary", "primary-1"])]
        presets.append(("ios-duo", duo))
    else:
        (DEST / "ios-duo.json").unlink(missing_ok=True)
        print("Duo preset unavailable: install the iPhone Duo simulator runtime to prepare it.")
    for name, config in presets:
        path = DEST / (name + ".json")
        path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n")
        print(path)
    print("Prepared configs only. No apps launched, no simulators booted, no captures run.")


if __name__ == "__main__":
    main()
