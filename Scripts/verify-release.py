"""Check built Release app metadata, privacy declaration and capture-code isolation."""
import pathlib
import plistlib
import sys

if len(sys.argv) != 2:
    raise SystemExit("Usage: python3 Scripts/verify-release.py /path/to/Glintwake.app")
root = pathlib.Path(sys.argv[1])
if root.suffix != ".app" or not root.is_dir():
    raise SystemExit("Expected an existing app bundle")
mac = (root / "Contents").is_dir()
info = plistlib.loads((root / ("Contents/Info.plist" if mac else "Info.plist")).read_bytes())
assert info["CFBundleIdentifier"] == "com.panandafog.glintwake"
assert info.get("ITSAppUsesNonExemptEncryption") is False
resources = root / "Contents/Resources" if mac else root
manifest = plistlib.loads((resources / "PrivacyInfo.xcprivacy").read_bytes())
assert manifest["NSPrivacyTracking"] is False
assert manifest["NSPrivacyCollectedDataTypes"] == []
assert manifest["NSPrivacyAccessedAPITypes"] == [{"NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults", "NSPrivacyAccessedAPITypeReasons": ["CA92.1"]}]
for lang in ["en", "ru"]:
    assert (resources / f"{lang}.lproj/Localizable.strings").is_file()
for name in ["slide", "crystal", "undo", "failure", "win", "ambience"]:
    assert (resources / (name + ".wav")).is_file()
markers = [b"--screenshot-scene=", b"Unknown Glintwake screenshot scene", b"Glintwake.Screenshot.", b"--ui-testing", b"--keep-test-session"]
for path in root.rglob("*"):
    if path.is_file() and not path.is_symlink():
        data = path.read_bytes()
        assert not any(marker in data for marker in markers), f"Debug-only marker in {path}"
print("Release checks passed:", root)
print("Version:", info["CFBundleShortVersionString"], "build:", info["CFBundleVersion"])
print("Platforms:", info.get("CFBundleSupportedPlatforms"))
print("Signing/provisioning and App Store Connect validation still require a distribution archive.")
