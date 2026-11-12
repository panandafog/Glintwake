"""Read existing human-maintained metadata; never create a second text source."""
import json
import pathlib
import re
import struct

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]
PLATFORMS = {"ios": "IOS", "macos": "MAC_OS"}


class ReleaseError(Exception):
    pass


class NeedsAction(ReleaseError):
    pass


class Waiting(ReleaseError):
    pass


def identity(platform, build_override="", root=ROOT):
    project = yaml.safe_load((root / "project.yml").read_text())
    settings = project["settings"]["base"] | project["targets"]["Glintwake"]["settings"]["base"]
    version = str(settings["MARKETING_VERSION"])
    build = build_override or str(settings["CURRENT_PROJECT_VERSION"])
    if not re.fullmatch(r"\d+\.\d+(?:\.\d+)?", version) or not re.fullmatch(r"[1-9]\d{0,8}", build):
        raise ReleaseError("Invalid marketing version or build number (use a positive integer build).")
    return dict(name="Glintwake", platform=PLATFORMS[platform], bundleId=settings["PRODUCT_BUNDLE_IDENTIFIER"],
                teamId=settings["DEVELOPMENT_TEAM"], version=version, build=build, scheme="Glintwake")


def metadata(root=ROOT):
    config = json.loads((root / "AppStore/release.json").read_text())
    text = (root / config["metadataSource"]).read_text()
    common = dict(re.findall(r"^\| ([^|]+?) \| ([^|]*?) \|$", text, re.M))
    localizations = {}
    for locale, body in re.findall(r"^## ([a-z]{2}-[A-Z]{2})\n(.*?)(?=^## |\Z)", text, re.M | re.S):
        fields = dict(re.findall(r"^### ([^\n]+)\n\n```text\n(.*?)\n```", body, re.M | re.S))
        mapped = {name: fields[heading] for heading, name in {
            "Name": "name", "Subtitle": "subtitle", "Description": "description",
            "Keywords": "keywords", "Promotional Text": "promotionalText"}.items() if fields.get(heading)}
        for heading, name in [("Support URL", "supportUrl"), ("Privacy Policy URL", "privacyPolicyUrl"),
                              ("Marketing URL", "marketingUrl")]:
            value = common.get(heading, "")
            if value.startswith("https://"):
                mapped[name] = value
        limits = {"name": 30, "subtitle": 30, "description": 4000, "keywords": 100, "promotionalText": 170}
        for name, limit in limits.items():
            if not mapped.get(name) or len(mapped[name]) > limit:
                raise ReleaseError(f"Metadata {locale}/{name} missing or exceeds {limit} characters.")
        localizations[locale] = mapped
    if set(localizations) != {"en-US", "ru-RU"}:
        raise ReleaseError("Expected the existing en-US and ru-RU metadata blocks.")
    contact = common["App Review contact"].split(", ")
    first, last = contact[0].split(" ", 1)
    notes = dict(re.findall(r"^### ([^\n]+)\n\n```text\n(.*?)\n```",
                           text.split("## " + config["reviewLocale"] + "\n", 1)[1].split("\n## ", 1)[0], re.M | re.S))["App Review Notes"]
    return config, localizations, dict(contactFirstName=first, contactLastName=last, contactEmail=contact[1],
                                       demoAccountRequired=False, notes=notes), common["Copyright"]


def release_notes(version, locale, root=ROOT):
    path = root / "AppStore/release-notes" / version / (locale + ".txt")
    if not path.exists():
        return None
    value = path.read_text().strip()
    if not value or len(value) > 4000:
        raise ReleaseError(f"Empty or oversized release notes for {locale}.")
    return value


def screenshot_files(group, locale, root=ROOT):
    files = sorted((root / "AppStore/screenshots" / group["folder"] / locale).glob("*.png"))
    if len(files) != 4:
        raise ReleaseError(f"Expected four screenshots: {group['folder']}/{locale}.")
    for file in files:
        data = file.read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n" or list(struct.unpack(">II", data[16:24])) != group["size"] or data[25] not in (0, 2):
            raise ReleaseError(f"Invalid screenshot dimensions/opacity: {file.name}.")
    return files
