"""Read existing human-maintained metadata; never create a second text source."""
import json
import pathlib
import re
import struct

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]
PLATFORMS = {"ios": "IOS", "macos": "MAC_OS"}
AGE_BOOLEAN_FIELDS = {
    "advertising", "ageAssurance", "gambling", "healthOrWellnessTopics", "lootBox",
    "messagingAndChat", "parentalControls", "socialMedia", "unrestrictedWebAccess", "userGeneratedContent"
}
AGE_FREQUENCY_FIELDS = {
    "alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated", "gunsOrOtherWeapons",
    "horrorOrFearThemes", "matureOrSuggestiveThemes", "medicalOrTreatmentInformation",
    "profanityOrCrudeHumor", "sexualContentGraphicAndNudity", "sexualContentOrNudity",
    "violenceCartoonOrFantasy", "violenceRealistic", "violenceRealisticProlongedGraphicOrSadistic"
}


class ReleaseError(Exception):
    pass


class NeedsAction(ReleaseError):
    pass


class Waiting(ReleaseError):
    pass


def complete_age_answers(configured, existing):
    """Supply the full initial declaration without guessing omitted answers."""
    fields = AGE_BOOLEAN_FIELDS | AGE_FREQUENCY_FIELDS
    result = {key: existing[key] for key in fields if existing.get(key) is not None}
    result.update({key: value for key, value in configured.items() if value is not None})
    missing = sorted(fields - result.keys())
    if missing:
        raise NeedsAction("Age-rating declaration needs explicit answers in AppStore/release.json or existing ASC data: " + ", ".join(missing))
    frequencies = {"NONE", "INFREQUENT_OR_MILD", "FREQUENT_OR_INTENSE", "INFREQUENT", "FREQUENT"}
    invalid = sorted(key for key in fields if
                     (key in AGE_BOOLEAN_FIELDS and type(result[key]) is not bool) or
                     (key in AGE_FREQUENCY_FIELDS and (not isinstance(result[key], str) or result[key] not in frequencies)))
    if invalid:
        raise NeedsAction("Invalid age-rating answer types/values: " + ", ".join(invalid))
    return result


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
