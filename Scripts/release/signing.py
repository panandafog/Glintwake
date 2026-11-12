"""Manual App Store signing in a disposable CI keychain; no account login."""
import base64
import datetime
import hashlib
import json
import os
import pathlib
import plistlib
import re
import secrets
import shutil
import subprocess
import tempfile
import zipfile

from .asc import sanitized
from .metadata import NeedsAction, ReleaseError, ROOT


def run(args, env=None, timeout=120):
    # No shell interpolation and no command echo: passwords are command arguments
    # to Apple's security utility and must never appear in a CI log.
    try:
        result = subprocess.run(args, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                timeout=timeout, text=True)
    except subprocess.TimeoutExpired:
        raise ReleaseError(f"{pathlib.Path(args[0]).name} timed out; inspect the current stage and rerun.") from None
    if result.returncode:
        # Keep raw tool output out of artifacts and exception tracebacks.
        diagnostic = sanitized(result.stdout + "\n" + result.stderr)[-6000:]
        raise ReleaseError(f"{pathlib.Path(args[0]).name} exited {result.returncode}: " + diagnostic)
    return result.stdout


def require(name):
    if not os.environ.get(name):
        raise NeedsAction(f"Configure GitHub Secret {name}.")
    return os.environ[name]


def decode_secret(name, path):
    try:
        data = base64.b64decode(require(name), validate=True)
    except ValueError:
        raise NeedsAction(f"GitHub Secret {name} must be a single-line base64 value.") from None
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    path.chmod(0o600)
    return path


def check_profile(profile, identity):
    expiry = profile.get("ExpirationDate")
    if not expiry or expiry.replace(tzinfo=datetime.timezone.utc) <= datetime.datetime.now(datetime.timezone.utc):
        raise NeedsAction("Provisioning profile is expired or lacks its expiry date.")
    entitlements = profile.get("Entitlements", {})
    expected = identity["teamId"] + "." + identity["bundleId"]
    app_id = entitlements.get("application-identifier", entitlements.get("com.apple.application-identifier"))
    platform = "iOS" if identity["platform"] == "IOS" else "OSX"
    if app_id != expected or identity["teamId"] not in profile.get("TeamIdentifier", []) or platform not in profile.get("Platform", []):
        raise NeedsAction("Provisioning profile does not match this platform, team and exact Bundle ID.")
    if profile.get("ProvisionedDevices") or profile.get("ProvisionsAllDevices") or entitlements.get("get-task-allow") or entitlements.get("com.apple.security.get-task-allow"):
        raise NeedsAction("Use an App Store distribution profile, not development, Ad Hoc, enterprise or Developer ID.")


def setup(identity, state_dir):
    work = pathlib.Path(tempfile.mkdtemp(prefix="glintwake-signing-", dir=os.environ.get("RUNNER_TEMP", tempfile.gettempdir())))
    work.chmod(0o700)
    keychain = work / "release.keychain-db"
    old = re.findall(r'"([^"\n]+)"', run(["security", "list-keychains", "-d", "user"]))
    state = dict(work=str(work), keychain=str(keychain), oldKeychains=old, profilePath=None)
    state_path = state_dir / "signing-state.json"
    state_path.write_text(json.dumps(state)); state_path.chmod(0o600)
    password = secrets.token_urlsafe(32)
    run(["security", "create-keychain", "-p", password, str(keychain)])
    run(["security", "set-keychain-settings", "-lut", "21600", str(keychain)])
    run(["security", "unlock-keychain", "-p", password, str(keychain)])
    run(["security", "list-keychains", "-d", "user", "-s", str(keychain), *old])
    prefix = "IOS" if identity["platform"] == "IOS" else "MAC_APP"
    p12 = decode_secret(prefix + "_DISTRIBUTION_P12_BASE64", work / "app.p12")
    run(["security", "import", str(p12), "-P", require(prefix + "_DISTRIBUTION_P12_PASSWORD"), "-k", str(keychain),
         "-T", "/usr/bin/codesign", "-T", "/usr/bin/security"])
    if identity["platform"] == "MAC_OS":
        p12 = decode_secret("MAC_INSTALLER_P12_BASE64", work / "installer.p12")
        run(["security", "import", str(p12), "-P", require("MAC_INSTALLER_P12_PASSWORD"), "-k", str(keychain), "-T", "/usr/bin/productbuild"])
    run(["security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-k", password, str(keychain)])
    profile_file = decode_secret("IOS_PROVISION_PROFILE_BASE64" if identity["platform"] == "IOS" else "MAC_PROVISION_PROFILE_BASE64", work / "profile")
    profile = plistlib.loads(run(["security", "cms", "-D", "-i", str(profile_file)]).encode())
    check_profile(profile, identity)
    profile_dir = pathlib.Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles"
    profile_dir.mkdir(parents=True, exist_ok=True)
    installed = profile_dir / (profile["UUID"] + (".mobileprovision" if identity["platform"] == "IOS" else ".provisionprofile"))
    # Never clobber an existing runner-owned profile with the same UUID.
    if installed.exists():
        if installed.read_bytes() != profile_file.read_bytes():
            raise ReleaseError("Conflicting provisioning profile already installed.")
    else:
        installed.write_bytes(profile_file.read_bytes())
        state["profilePath"] = str(installed)
    state_path.write_text(json.dumps(state))
    identities = re.findall(r'([0-9A-Fa-f]{40}) "([^"\n]+)"', run(["security", "find-identity", "-v", str(keychain)]))
    hashes = {hashlib.sha1(cert).hexdigest().upper() for cert in profile.get("DeveloperCertificates", [])}
    matches = [(sha, name) for sha, name in identities if sha.upper() in hashes and name.endswith("(" + identity["teamId"] + ")")]
    if len(matches) != 1:
        raise NeedsAction("No unique imported distribution identity matches the profile's developer certificate and team.")
    sha, name = matches[0]
    prefixes = ("Apple Distribution:", "iPhone Distribution:") if identity["platform"] == "IOS" else ("3rd Party Mac Developer Application:", "Apple Distribution:")
    if not name.startswith(prefixes):
        raise NeedsAction("Certificate is not an App Store distribution signing identity.")
    installer = None
    if identity["platform"] == "MAC_OS":
        matches = [(sha, name) for sha, name in identities if name.startswith("3rd Party Mac Developer Installer:") and name.endswith("(" + identity["teamId"] + ")")]
        if len(matches) != 1:
            raise NeedsAction("Import exactly one matching Mac App Store installer identity, not Developer ID Installer.")
        installer = matches[0][1]
    return dict(work=work, keychain=keychain, appIdentity=sha, installerIdentity=installer, profileName=profile["Name"])


def cleanup(state_dir):
    state_path = state_dir / "signing-state.json"
    if not state_path.exists():
        return
    state = json.loads(state_path.read_text())
    run(["security", "list-keychains", "-d", "user", "-s", *state["oldKeychains"]])
    if pathlib.Path(state["keychain"]).exists():
        run(["security", "delete-keychain", state["keychain"]])
    if state.get("profilePath"):
        pathlib.Path(state["profilePath"]).unlink(missing_ok=True)
    shutil.rmtree(state["work"], ignore_errors=True)
    state_path.unlink()


def verify_app(app, identity):
    mac = identity["platform"] == "MAC_OS"
    info = plistlib.loads((app / ("Contents/Info.plist" if mac else "Info.plist")).read_bytes())
    for field, value in [("CFBundleIdentifier", identity["bundleId"]), ("CFBundleShortVersionString", identity["version"]), ("CFBundleVersion", identity["build"])]:
        if str(info.get(field)) != value:
            raise ReleaseError(f"Artifact {field} does not match requested identity.")
    if info.get("CFBundleSupportedPlatforms") != (["MacOSX"] if mac else ["iPhoneOS"]):
        raise ReleaseError("Artifact SDK/platform is not the expected native App Store platform.")
    run(["codesign", "--verify", "--deep", "--strict", str(app)])
    entitlements = plistlib.loads(run(["codesign", "-d", "--entitlements", ":-", str(app)]).encode())
    if entitlements.get("get-task-allow") or entitlements.get("com.apple.security.get-task-allow"):
        raise ReleaseError("Distribution app has debugging entitlement.")
    if mac and entitlements.get("com.apple.security.app-sandbox") is not True:
        raise ReleaseError("Mac App Store app lacks sandbox entitlement.")
    profile_path = app / ("Contents/embedded.provisionprofile" if mac else "embedded.mobileprovision")
    check_profile(plistlib.loads(run(["security", "cms", "-D", "-i", str(profile_path)]).encode()), identity)
    run(["python3", "Scripts/verify-release.py", str(app)], timeout=180)


def build(identity, state_dir):
    signing = setup(identity, state_dir)
    archive = state_dir / "Glintwake.xcarchive"
    destination = "generic/platform=iOS" if identity["platform"] == "IOS" else "generic/platform=macOS"
    run(["xcodebuild", "-project", "Glintwake.xcodeproj", "-scheme", identity["scheme"], "-configuration", "Release",
         "-destination", destination, "-archivePath", str(archive), "-derivedDataPath", str(state_dir / "DerivedData"),
         "CURRENT_PROJECT_VERSION=" + identity["build"], "CODE_SIGN_STYLE=Manual", "DEVELOPMENT_TEAM=" + identity["teamId"],
         "CODE_SIGN_IDENTITY=" + signing["appIdentity"], "PROVISIONING_PROFILE_SPECIFIER=" + signing["profileName"],
         "OTHER_CODE_SIGN_FLAGS=--keychain " + str(signing["keychain"]), "archive"], timeout=1800)
    app = archive / "Products/Applications/Glintwake.app"
    verify_app(app, identity)
    export = state_dir / "Artifact"
    export.mkdir(parents=True, exist_ok=True)
    if identity["platform"] == "IOS":
        options = signing["work"] / "ExportOptions.plist"
        options.write_bytes(plistlib.dumps(dict(method="app-store-connect", destination="export", signingStyle="manual", teamID=identity["teamId"],
            signingCertificate=signing["appIdentity"], provisioningProfiles={identity["bundleId"]: signing["profileName"]},
            manageAppVersionAndBuildNumber=False, uploadSymbols=True)))
        run(["xcodebuild", "-exportArchive", "-archivePath", str(archive), "-exportOptionsPlist", str(options), "-exportPath", str(export)], timeout=1200)
        files = list(export.glob("*.ipa"))
        if len(files) != 1:
            raise ReleaseError("Export did not produce one ipa.")
        artifact = files[0]
        # Validate the exported bundle too; export can re-sign an archive.
        with tempfile.TemporaryDirectory(dir=signing["work"]) as temp:
            with zipfile.ZipFile(artifact) as zip:
                if any(pathlib.PurePosixPath(n).is_absolute() or ".." in pathlib.PurePosixPath(n).parts for n in zip.namelist()):
                    raise ReleaseError("Unsafe IPA path.")
            run(["ditto", "-x", "-k", str(artifact), temp])
            verify_app(pathlib.Path(temp) / "Payload/Glintwake.app", identity)
    else:
        artifact = export / "Glintwake.pkg"
        run(["productbuild", "--component", str(app), "/Applications", "--sign", signing["installerIdentity"],
             "--keychain", str(signing["keychain"]), str(artifact)], timeout=300)
        run(["pkgutil", "--check-signature", str(artifact)])
    manifest = dict(identity=identity, file=artifact.name, sha256=hashlib.sha256(artifact.read_bytes()).hexdigest())
    (export / "artifact.json").write_text(json.dumps(manifest, indent=2) + "\n")
    # Keep only transport files and the identity manifest in the upload artifact.
    for path in export.iterdir():
        if path.name not in {artifact.name, "artifact.json"}:
            if path.is_dir():
                shutil.rmtree(path)
            else:
                path.unlink()
    return artifact


def binary(state_dir, identity):
    export = state_dir / "Artifact"
    if not (export / "artifact.json").exists():
        raise NeedsAction("No signed artifact. Run full, or upload with the previous artifact_run_id.")
    manifest = json.loads((export / "artifact.json").read_text())
    if manifest["identity"] != identity or pathlib.Path(manifest["file"]).name != manifest["file"]:
        raise ReleaseError("Downloaded artifact identity differs from the requested release.")
    artifact = export / manifest["file"]
    if hashlib.sha256(artifact.read_bytes()).hexdigest() != manifest["sha256"]:
        raise ReleaseError("Downloaded artifact checksum mismatch.")
    if artifact.suffix != (".ipa" if identity["platform"] == "IOS" else ".pkg"):
        raise ReleaseError("Incorrect App Store package format.")
    return artifact
