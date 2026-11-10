"""Copy successful FramePilot exports into the tracked store folder; validate PNGs.

Usage: python3 Scripts/export-store-screenshots.py Build/FramePilot/Runs/<run> [...]
Original run folders and diagnostics stay under ignored Build/.
"""
import json
import pathlib
import re
import shutil
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEST = ROOT / "AppStore/screenshots"
SCENES = ["gameplay", "planning", "difficulty", "victory"]
ACCEPTED = {"iPhone": {(1320, 2868), (1290, 2796), (1260, 2736), (1284, 2778), (1242, 2688)},
            "iPad": {(2064, 2752), (2048, 2732)}, "macOS": {(1280, 800), (2560, 1600), (1440, 900), (2880, 1800)}}


def png_info(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG: {path}")
    width, height, depth, color = struct.unpack(">IIBB", data[16:26])
    if color not in (0, 2):
        # FramePilot exports opaque RGB. Reject alpha and indexed ambiguity.
        raise ValueError(f"Expected opaque grayscale/RGB PNG: {path}")
    return width, height


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    staged = []
    identities = set()
    for run_arg in sys.argv[1:]:
        run = pathlib.Path(run_arg).resolve()
        manifest = json.loads((run / "run.json").read_text())
        if not manifest.get("finishedAt") or manifest.get("cancelled") or manifest.get("errors"):
            raise SystemExit(f"Run is unfinished, cancelled or has errors: {run}")
        config = manifest["configuration"]
        devices = {device["name"]: device["family"] for device in config["devices"]}
        expected = {(family, language, scene) for family in devices.values()
                    for language in config["languages"] for scene in SCENES}
        actual = set()
        for artifact in manifest["artifacts"]:
            family = devices.get(artifact["device"])
            name = artifact["name"]
            # xcresulttool adds an occurrence/UUID suffix to macOS attachment names.
            scene = next((item for item in SCENES if name == item or
                          (family == "macOS" and re.fullmatch(re.escape(item) + r"_\d+_[0-9A-Fa-f-]+\.png", name))), None)
            if scene is None or family not in ACCEPTED:
                raise SystemExit(f"Unexpected artifact: {artifact}")
            language = artifact["language"]
            identity = (family, language, scene)
            if identity in identities:
                raise SystemExit(f"Duplicate artifact: {identity}")
            source = pathlib.Path(artifact["filePath"])
            width, height = png_info(source)
            if (width, height) not in ACCEPTED[family] or artifact.get("validation"):
                raise SystemExit(f"Invalid store dimensions/validation: {source}: {width}×{height}")
            target = DEST / family / language / f"{SCENES.index(scene)+1:02d}-{scene}.png"
            staged.append((source, target, width, height, str(run)))
            identities.add(identity)
            actual.add(identity)
        if actual != expected:
            raise SystemExit(f"Incomplete capture matrix in {run}: missing {expected - actual}")
    for source, target, width, height, run in staged:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        print(f"{target.relative_to(ROOT)}: {width}×{height}")
    print(f"Exported {len(staged)} screenshots. Inspect them visually before submission.")


if __name__ == "__main__":
    main()
