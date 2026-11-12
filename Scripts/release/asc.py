"""Small allowlisted Apple API client. It cannot submit or publish a release."""
import base64
import hashlib
import json
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request

from .metadata import NeedsAction, ReleaseError, Waiting, release_notes

ORIGIN = "https://api.appstoreconnect.apple.com"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}
ACTIVE = {"WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES", "CANCELING", "COMPLETING"}
# A mutation must match this list. There is deliberately no PATCH reviewSubmissions,
# appStoreVersionSubmissions, release request, phased release or pricing endpoint.
MUTATIONS = {
    "POST": [r"/v1/(appStoreVersions|appStoreVersionLocalizations|appInfoLocalizations|appStoreReviewDetails|appScreenshotSets|appScreenshots|reviewSubmissions|reviewSubmissionItems)"],
    "PATCH": [r"/v1/(appStoreVersions|appStoreVersionLocalizations|appInfos|appInfoLocalizations|appStoreReviewDetails|appScreenshots|ageRatingDeclarations|builds)/[\w-]+",
              r"/v1/appScreenshotSets/[\w-]+/relationships/appScreenshots"],
    "DELETE": [r"/v1/appScreenshots/[\w-]+"]
}


def state(resource):
    attrs = resource.get("attributes", {})
    return attrs.get("appVersionState") or attrs.get("state") or attrs.get("appStoreState")


def relationship(resource, name):
    data = resource.get("relationships", {}).get(name, {}).get("data")
    return data.get("id") if isinstance(data, dict) else None


def payload(kind, attrs=None, rels=None, id=None):
    data = {"type": kind}
    if id:
        data["id"] = id
    if attrs is not None:
        data["attributes"] = attrs
    if rels:
        data["relationships"] = {key: {"data": {"type": typ, "id": value}} for key, (typ, value) in rels.items()}
    return {"data": data}


def sanitized(value):
    text = str(value)
    for key, secret in os.environ.items():
        if any(word in key for word in ("PASSWORD", "PRIVATE_KEY", "P12", "TOKEN", "CONTACT_PHONE", "DEMO_ACCOUNT")) and len(secret) > 3:
            text = text.replace(secret, "[REDACTED]")
    text = re.sub(r"-----BEGIN .*?PRIVATE KEY-----.*?-----END .*?PRIVATE KEY-----", "[REDACTED KEY]", text, flags=re.S)
    text = re.sub(r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+", "[REDACTED JWT]", text)
    return text


class ApiError(ReleaseError):
    def __init__(self, status, errors=None, operation=""):
        self.status = status
        # Apple's detailed messages can echo request values; retain codes and
        # field pointers, never dump a body containing review credentials.
        self.codes = [e.get("code", "UNKNOWN") for e in errors or []]
        self.fields = [e.get("source", {}).get("pointer", "") for e in errors or []]
        super().__init__(f"Apple API HTTP {status} {operation}; codes={','.join(self.codes)}; fields={','.join(self.fields)}")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class Client:
    def __init__(self, token=None, opener=None, sleep=time.sleep):
        self.token = token or Token()
        self.opener = opener or urllib.request.build_opener(NoRedirect())
        self.sleep = sleep

    def request(self, method, path, data=None, params=None):
        url = path if path.startswith("https://") else ORIGIN + path
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != "https" or parsed.netloc != "api.appstoreconnect.apple.com" or parsed.fragment:
            raise ReleaseError("Refused API URL outside Apple's API origin.")
        if method != "GET":
            if parsed.query or not any(re.fullmatch(p, parsed.path) for p in MUTATIONS.get(method, [])):
                raise ReleaseError("Refused mutation: submission/publishing endpoints are unavailable.")
            if any(k in json.dumps(data or {}) for k in ('"submitted"', '"cancel"', '"releaseType"', '"earliestReleaseDate"')):
                # The sole allowed releaseType is the conservative initial value
                # of a newly created version, never an edit of existing settings.
                attrs = (data or {}).get("data", {}).get("attributes", {})
                if not (method == "POST" and parsed.path == "/v1/appStoreVersions" and attrs.get("releaseType") == "MANUAL"
                        and not any(k in json.dumps(data) for k in ('"submitted"', '"cancel"', '"earliestReleaseDate"'))):
                    raise ReleaseError("Refused submission or release-setting change.")
        if params:
            url += ("&" if parsed.query else "?") + urllib.parse.urlencode(params)
        for attempt in range(5):
            req = urllib.request.Request(url, data=json.dumps(data).encode() if data is not None else None,
                                         headers={"Authorization": "Bearer " + self.token(), "Content-Type": "application/json"}, method=method)
            try:
                with self.opener.open(req, timeout=60) as response:
                    body = response.read()
                    return json.loads(body) if body else {}
            except urllib.error.HTTPError as error:
                try:
                    errors = json.loads(error.read()).get("errors", [])
                except (ValueError, AttributeError):
                    errors = []
                error.close()
                if (error.code == 429 or error.code >= 500) and method in {"GET", "PATCH", "DELETE"} and attempt < 4:
                    delay = error.headers.get("Retry-After", "") if error.headers else ""
                    self.sleep(min(float(delay) if delay.isdigit() else 2 ** attempt, 60))
                    continue
                raise ApiError(error.code, errors, f"{method} {parsed.path}") from None
            except (OSError, TimeoutError):
                if method in {"GET", "PATCH", "DELETE"} and attempt < 4:
                    self.sleep(2 ** attempt)
                    continue
                raise ReleaseError("Apple API network timeout/failure. Rerun the same stage; ambiguous POSTs are not blindly retried.") from None

    def list(self, path, params=None):
        result = []
        seen = set()
        while path:
            if path in seen:
                raise ReleaseError("Repeated API pagination URL.")
            seen.add(path)
            response = self.request("GET", path, params=params)
            result.extend(response["data"])
            path = response.get("links", {}).get("next")
            params = None
        return result

    def get(self, path):
        return self.request("GET", path)["data"]

    def create(self, kind, attrs=None, rels=None):
        return self.request("POST", "/v1/" + kind, payload(kind, attrs, rels))["data"]

    def update(self, resource, attrs=None, rels=None):
        return self.request("PATCH", f"/v1/{resource['type']}/{resource['id']}", payload(resource["type"], attrs, rels, resource["id"]))["data"]


class Token:
    def __init__(self):
        self.value = None
        self.expires = 0

    def __call__(self):
        if time.time() >= self.expires - 60:
            import jwt
            from pathlib import Path
            try:
                key = Path(os.environ["ASC_KEY_PATH"]).read_text()
                now = int(time.time())
                self.value = jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now - 5,
                                         "exp": now + 900, "aud": "appstoreconnect-v1"}, key,
                                        algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})
            except (KeyError, OSError, ValueError, jwt.PyJWTError):
                raise NeedsAction("Configure ASC_KEY_ID, ASC_ISSUER_ID and the private-key secret in GitHub.") from None
            self.expires = now + 900
        return self.value


class Store:
    def __init__(self, client, identity, config, report, sleep=time.sleep, clock=time.monotonic):
        self.api, self.identity, self.config, self.report = client, identity, config, report
        self.sleep, self.clock = sleep, clock
        apps = client.list("/v1/apps", {"filter[bundleId]": identity["bundleId"], "limit": 200})
        if len(apps) != 1 or apps[0]["attributes"]["bundleId"] != identity["bundleId"]:
            raise NeedsAction("Create the app record for this Bundle ID in App Store Connect, or grant the API key app access.")
        self.app = apps[0]
        report["appId"] = self.app["id"]

    def versions(self):
        return [v for v in self.api.list(f"/v1/apps/{self.app['id']}/appStoreVersions", {"filter[platform]": self.identity["platform"], "limit": 200})
                if v["attributes"].get("platform") == self.identity["platform"]]

    def submissions(self):
        return [s for s in self.api.list(f"/v1/apps/{self.app['id']}/reviewSubmissions", {"filter[platform]": self.identity["platform"], "limit": 200})
                if s["attributes"].get("platform") in (None, self.identity["platform"])]

    def guard(self, allow_ready=False):
        for submission in self.submissions():
            if state(submission) in ACTIVE:
                raise NeedsAction("An active review submission exists for this platform. Resolve it in ASC; this workflow never cancels or removes it.")
        matches = [v for v in self.versions() if v["attributes"]["versionString"] == self.identity["version"]]
        if len(matches) > 1:
            raise ReleaseError("Ambiguous App Store version.")
        if matches and state(matches[0]) not in EDITABLE | ({"READY_FOR_REVIEW"} if allow_ready else set()):
            raise NeedsAction(f"Version is {state(matches[0])}; use status mode. Draft items are not removed for editing.")
        return matches[0] if matches else None

    def ensure_version(self):
        version = self.guard()
        if version:
            return version
        if any(state(v) in EDITABLE | {"READY_FOR_REVIEW"} for v in self.versions()):
            raise NeedsAction("Another editable version already exists on this platform; resolve it in ASC first.")
        try:
            return self.api.create("appStoreVersions", {"platform": self.identity["platform"], "versionString": self.identity["version"],
                                                       "releaseType": "MANUAL"}, {"app": ("apps", self.app["id"])})
        except ApiError as error:
            if error.status == 409:
                version = self.guard()
                if version:
                    return version
            raise

    def find_build(self):
        builds = self.api.list("/v1/builds", {"filter[app]": self.app["id"], "filter[version]": self.identity["build"],
            "filter[preReleaseVersion.version]": self.identity["version"], "filter[preReleaseVersion.platform]": self.identity["platform"], "limit": 200})
        exact = []
        for build in builds:
            prerelease = self.api.get(f"/v1/builds/{build['id']}/preReleaseVersion")
            app = self.api.get(f"/v1/builds/{build['id']}/app")
            if (app["id"] == self.app["id"] and app["attributes"]["bundleId"] == self.identity["bundleId"]
                    and prerelease["attributes"]["version"] == self.identity["version"]
                    and prerelease["attributes"]["platform"] == self.identity["platform"]
                    and build["attributes"]["version"] == self.identity["build"]):
                exact.append(build)
        if len(exact) > 1:
            raise ReleaseError("Ambiguous exact build identity.")
        if exact:
            self.report["processing"] = exact[0]["attributes"].get("processingState", "UNKNOWN")
            if exact[0]["attributes"].get("expired") or self.report["processing"] in {"FAILED", "INVALID"}:
                raise NeedsAction("This exact build is invalid, failed or expired. Inspect Apple diagnostics and use a new build number.")
            if exact[0]["attributes"].get("buildAudienceType") == "INTERNAL_ONLY":
                raise NeedsAction("This build is restricted to internal testing; upload an App Store distribution build with a new number.")
        return exact[0] if exact else None

    def wait_build(self):
        deadline = self.clock() + self.config["processingTimeoutSeconds"]
        while True:
            build = self.find_build()
            if build and build["attributes"]["processingState"] == "VALID":
                return build
            if not build:
                self.find_upload()
            if self.clock() >= deadline:
                self.report["processing"] = "PROCESSING" if build else "NOT_VISIBLE_YET"
                raise Waiting("Apple processing is not finished. Rerun status, then review/full with the same build; do not increment it for this retry.")
            self.sleep(20)

    def find_upload(self):
        # Transport receipt appears before an ordinary Build may be searchable.
        uploads = self.api.list(f"/v1/apps/{self.app['id']}/buildUploads", {
            "filter[cfBundleShortVersionString]": self.identity["version"], "filter[cfBundleVersion]": self.identity["build"],
            "filter[platform]": self.identity["platform"], "limit": 200})
        uploads = [u for u in uploads if u["attributes"].get("cfBundleShortVersionString") == self.identity["version"]
                   and u["attributes"].get("cfBundleVersion") == self.identity["build"]
                   and u["attributes"].get("platform") == self.identity["platform"]]
        accepted = [u for u in uploads if u["attributes"].get("state", {}).get("state") in {"PROCESSING", "COMPLETE"}]
        if accepted:
            self.report["upload"] = "ALREADY_RECEIVED (Apple upload receipt; build may not yet be visible)"
            return accepted[0]
        if uploads:
            raise NeedsAction("Apple has a failed/incomplete upload receipt for this exact build. Inspect build upload diagnostics before retrying; this workflow does not delete Apple upload records.")
        return None

    def bind(self, version, build):
        self.guard()
        fresh = self.api.get(f"/v1/appStoreVersions/{version['id']}")
        if fresh["attributes"]["versionString"] != self.identity["version"] or fresh["attributes"]["platform"] != self.identity["platform"]:
            raise ReleaseError("Version identity changed.")
        if relationship(fresh, "build") != build["id"]:
            self.api.update(fresh, rels={"build": ("builds", build["id"])})
        actual = self.api.get(f"/v1/appStoreVersions/{version['id']}/build")
        if actual["id"] != build["id"]:
            raise ReleaseError("Apple did not retain the selected build.")
        self.report["selectedBuild"] = build["id"]

    def editable_info(self):
        infos = self.api.list(f"/v1/apps/{self.app['id']}/appInfos", {"limit": 200})
        matches = [i for i in infos if state(i) in EDITABLE]
        if len(matches) == 1:
            return matches[0], True
        if matches:
            raise NeedsAction("Multiple editable App Information records. Resolve them in ASC.")
        # App Information is shared across iOS and Mac. Once the first platform
        # has a ready draft, the second can reuse identical information read-only.
        for states in ({"READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW"}, {"READY_FOR_DISTRIBUTION", "READY_FOR_SALE"}):
            matches = [i for i in infos if state(i) in states]
            if len(matches) == 1:
                return matches[0], False
            if matches:
                break
        raise NeedsAction("No unique App Information record. Prepare it in ASC; live/shared review information is never modified.")

    def verify_info(self, info, localizations):
        locales = self.api.list(f"/v1/appInfos/{info['id']}/appInfoLocalizations", {"limit": 200})
        by_locale = {l["attributes"]["locale"]: l for l in locales}
        for locale, expected in localizations.items():
            current = by_locale.get(locale)
            if not current or any(current["attributes"].get(k) != expected[k] for k in ("name", "subtitle", "privacyPolicyUrl")):
                raise NeedsAction("Shared App Information differs from the repository. Edit it in a permitted draft state; reviewed/live information was preserved.")
        for key, expected in self.config.get("appInfoCategories", {}).items():
            actual = relationship(info, key)
            if actual is None:
                actual = self.api.get(f"/v1/appInfos/{info['id']}/{key}")["id"]
            if actual != expected:
                raise NeedsAction("Shared App Information category differs; no live/reviewed fields were changed.")
        if self.config.get("ageRating"):
            age = self.api.get(f"/v1/appInfos/{info['id']}/ageRatingDeclaration")
            if any(age["attributes"].get(k) != v for k, v in self.config["ageRating"].items()):
                raise NeedsAction("Shared age-rating answers differ. Resolve the declaration while it is editable.")

    def upsert_locale(self, parent, relationship_name, kind, locale, attrs):
        existing = self.api.list(f"/v1/{parent['type']}/{parent['id']}/{relationship_name}", {"limit": 200})
        matches = [x for x in existing if x["attributes"]["locale"] == locale]
        if len(matches) > 1:
            raise ReleaseError("Ambiguous localization.")
        # Missing optional values preserve server data; never send empty strings.
        attrs = {k: v for k, v in attrs.items() if v is not None and v != ""}
        if matches:
            changed = {k: v for k, v in attrs.items() if matches[0]["attributes"].get(k) != v}
            return self.api.update(matches[0], changed) if changed else matches[0]
        parent_name = "appInfo" if kind == "appInfoLocalizations" else "appStoreVersion"
        return self.api.create(kind, {"locale": locale, **attrs}, {parent_name: (parent["type"], parent["id"])})

    def metadata(self, version, localizations, copyright):
        self.guard()
        info, writable = self.editable_info()
        if not writable:
            self.verify_info(info, localizations)
        categories = self.config.get("appInfoCategories", {})
        for category in categories.values():
            actual = self.api.get("/v1/appCategories/" + category)
            if actual["id"] != category:
                raise ReleaseError("Unexpected App Store category identity.")
        if categories and writable:
            self.api.update(info, rels={key: ("appCategories", value) for key, value in categories.items()})
        self.api.update(version, {"copyright": copyright})
        if self.config.get("ageRating") and writable:
            age = self.api.get(f"/v1/appInfos/{info['id']}/ageRatingDeclaration")
            self.api.update(age, self.config["ageRating"])
        result = {}
        update = any(state(v) in {"READY_FOR_DISTRIBUTION", "READY_FOR_SALE", "REPLACED_WITH_NEW_VERSION"} for v in self.versions())
        for locale, attrs in localizations.items():
            if writable:
                self.upsert_locale(info, "appInfoLocalizations", "appInfoLocalizations", locale,
                                   {k: attrs[k] for k in ("name", "subtitle", "privacyPolicyUrl") if k in attrs})
            values = {k: v for k, v in attrs.items() if k not in {"name", "subtitle", "privacyPolicyUrl"}}
            notes = release_notes(self.identity["version"], locale)
            if update and notes:
                values["whatsNew"] = notes
            result[locale] = self.upsert_locale(version, "appStoreVersionLocalizations", "appStoreVersionLocalizations", locale, values)
            if update and not result[locale]["attributes"].get("whatsNew"):
                raise NeedsAction(f"Provide AppStore/release-notes/{self.identity['version']}/{locale}.txt for this update.")
        self.report["metadata"] = "SUCCEEDED"
        return result

    def configure_review(self, version, attrs):
        self.guard()
        phone = os.environ.get("ASC_REVIEW_CONTACT_PHONE", "").strip()
        if phone:
            attrs = {**attrs, "contactPhone": phone}
        try:
            existing = self.api.get(f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail")
        except ApiError as error:
            if error.status != 404:
                raise
            existing = None
        merged = (existing or {}).get("attributes", {}) | attrs
        missing = [key for key in ("contactFirstName", "contactLastName", "contactEmail", "contactPhone", "notes") if not merged.get(key)]
        if missing:
            raise NeedsAction("Missing App Review fields: " + ", ".join(missing) + ". Set ASC_REVIEW_CONTACT_PHONE in GitHub Secrets; other values come from metadata.")
        if merged.get("demoAccountRequired"):
            for key in ("demoAccountName", "demoAccountPassword"):
                if not merged.get(key):
                    raise NeedsAction("Demo account required but credentials missing; do not invent an account.")
        if existing:
            changed = {key: value for key, value in attrs.items() if existing["attributes"].get(key) != value}
            if changed:
                self.api.update(existing, changed)
        else:
            self.api.create("appStoreReviewDetails", attrs, {"appStoreVersion": ("appStoreVersions", version["id"])})
        self.report["review"] = "SUCCEEDED"

    def draft(self, version, build):
        current = self.guard(allow_ready=True)
        if not current or current["id"] != version["id"]:
            raise ReleaseError("Draft target version changed.")
        actual = self.api.get(f"/v1/appStoreVersions/{version['id']}/build")
        if actual["id"] != build["id"] or actual["attributes"].get("processingState") != "VALID":
            raise ReleaseError("Draft does not select the requested processed build.")
        drafts = [s for s in self.submissions() if state(s) == "READY_FOR_REVIEW"]
        if len(drafts) > 1:
            raise NeedsAction("Several drafts exist for this platform. Choose/resolve them in ASC first.")
        submission = drafts[0] if drafts else self.api.create("reviewSubmissions", {"platform": self.identity["platform"]}, {"app": ("apps", self.app["id"])})
        items = self.api.list(f"/v1/reviewSubmissions/{submission['id']}/items", {"include": "appStoreVersion", "limit": 200})
        other = [i for i in items if relationship(i, "appStoreVersion") not in (None, version["id"]) and state(i) != "REMOVED"]
        if other:
            raise NeedsAction("Draft contains another app version; no items were removed.")
        matches = [i for i in items if relationship(i, "appStoreVersion") == version["id"] and state(i) != "REMOVED"]
        if not matches:
            self.api.create("reviewSubmissionItems", rels={"reviewSubmission": ("reviewSubmissions", submission["id"]),
                                                             "appStoreVersion": ("appStoreVersions", version["id"])})
        fresh = self.api.get(f"/v1/reviewSubmissions/{submission['id']}")
        items = self.api.list(f"/v1/reviewSubmissions/{submission['id']}/items", {"include": "appStoreVersion", "limit": 200})
        fresh_version = self.api.get(f"/v1/appStoreVersions/{version['id']}")
        self.report["draftState"] = state(fresh)
        self.report["versionState"] = state(fresh_version)
        self.report["draftId"] = fresh["id"]
        target = [i for i in items if relationship(i, "appStoreVersion") == version["id"] and state(i) == "READY_FOR_REVIEW"]
        if state(fresh) != "READY_FOR_REVIEW" or state(fresh_version) != "READY_FOR_REVIEW" or len(target) != 1:
            raise NeedsAction("Apple has not confirmed READY_FOR_REVIEW for the draft, item and version. Inspect ASC validation.")
        self.report["draft"] = "SUCCEEDED"


def upload_asset_operations(operations, data, opener=None, sleep=time.sleep):
    opener = opener or urllib.request.build_opener(NoRedirect())
    for operation in operations:
        if urllib.parse.urlparse(operation["url"]).scheme != "https" or operation["method"] != "PUT":
            raise ReleaseError("Unexpected Apple asset upload operation.")
        offset, length = operation["offset"], operation["length"]
        if offset < 0 or length <= 0 or offset + length > len(data):
            raise ReleaseError("Invalid asset upload byte range.")
        headers = {h["name"]: h["value"] for h in operation.get("requestHeaders", [])}
        if any(h.lower() == "authorization" for h in headers):
            raise ReleaseError("Unexpected authorization on a presigned asset upload.")
        for attempt in range(4):
            try:
                # Separate opener: never attach the ASC Bearer token to storage URLs.
                with opener.open(urllib.request.Request(operation["url"], data[offset:offset + length], headers, method="PUT"), timeout=90):
                    break
            except (OSError, TimeoutError):
                if attempt == 3:
                    raise ReleaseError("Apple asset transfer failed; rerun metadata. Signed storage URLs are intentionally not logged.") from None
                sleep(2 ** attempt)


def screenshots(store, localization, group, files):
    api = store.api
    store.guard()
    sets = api.list(f"/v1/appStoreVersionLocalizations/{localization['id']}/appScreenshotSets", {"limit": 200})
    matches = [s for s in sets if s["attributes"]["screenshotDisplayType"] == group["displayType"]]
    if len(matches) > 1:
        raise ReleaseError("Ambiguous screenshot set.")
    aset = matches[0] if matches else api.create("appScreenshotSets", {"screenshotDisplayType": group["displayType"]},
                                                {"appStoreVersionLocalization": ("appStoreVersionLocalizations", localization["id"])})
    existing = api.list(f"/v1/appScreenshotSets/{aset['id']}/appScreenshots", {"limit": 200})
    if any(not a["attributes"].get("fileName", "").startswith("glintwake-") for a in existing):
        raise NeedsAction("Screenshot set contains unmanaged images. Review/migrate them once in ASC; existing images were preserved.")
    desired = []
    discarded = set()
    for file in files:
        data = file.read_bytes()
        checksum = hashlib.md5(data).hexdigest()
        name = "glintwake-" + file.stem + "-" + hashlib.sha256(data).hexdigest()[:16] + ".png"
        matches = [a for a in existing if a["attributes"].get("fileName") == name]
        if len(matches) > 1:
            raise NeedsAction("Duplicate managed screenshot reservations. Remove the duplicates in ASC first.")
        asset = matches[0] if matches else None
        if asset and asset["attributes"].get("assetDeliveryState", {}).get("state") == "FAILED":
            api.request("DELETE", "/v1/appScreenshots/" + asset["id"])
            discarded.add(asset["id"])
            asset = None
        if not asset:
            asset = api.create("appScreenshots", {"fileName": name, "fileSize": len(data)}, {"appScreenshotSet": ("appScreenshotSets", aset["id"])})
        delivery = asset["attributes"].get("assetDeliveryState", {}).get("state")
        if delivery == "COMPLETE" and asset["attributes"].get("sourceFileChecksum", "").lower() != checksum:
            raise ReleaseError("Completed screenshot checksum does not match local source.")
        if delivery not in {"COMPLETE", "UPLOAD_COMPLETE"}:
            operations = asset["attributes"].get("uploadOperations")
            if not operations:
                raise NeedsAction("Screenshot reservation has no upload operations. Retry metadata or inspect the reservation in ASC.")
            upload_asset_operations(operations, data)
            api.update(asset, {"uploaded": True, "sourceFileChecksum": checksum})
        deadline = store.clock() + store.config["assetTimeoutSeconds"]
        while True:
            fresh = api.get("/v1/appScreenshots/" + asset["id"])
            delivery = fresh["attributes"].get("assetDeliveryState", {})
            if delivery.get("state") == "COMPLETE":
                if fresh["attributes"].get("sourceFileChecksum", "").lower() != checksum:
                    raise ReleaseError("Screenshot checksum changed during processing.")
                break
            if delivery.get("state") == "FAILED":
                raise NeedsAction("Apple screenshot processing failed. Rerun metadata to recreate only the failed managed reservation.")
            if store.clock() >= deadline:
                raise Waiting("Apple screenshot processing is unfinished. Rerun metadata; uploaded assets will be reused.")
            store.sleep(5)
        desired.append(asset["id"])
    # Delete obsolete managed images only after all replacements are complete.
    store.guard()
    for old in existing:
        if old["id"] not in desired and old["id"] not in discarded:
            api.request("DELETE", "/v1/appScreenshots/" + old["id"])
    api.request("PATCH", f"/v1/appScreenshotSets/{aset['id']}/relationships/appScreenshots",
                {"data": [{"type": "appScreenshots", "id": id} for id in desired]})
