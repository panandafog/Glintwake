import os
import pathlib
import tempfile
import unittest
from unittest.mock import patch
from Scripts.release import signing
from Scripts.release.asc import Store, screenshots
from Scripts.release.metadata import NeedsAction, ReleaseError, identity, metadata, screenshot_files
from test_release import FakeAPI


class ReleaseSafetyTests(unittest.TestCase):
    def test_app_prefixed_owner_screenshot_is_preserved(self):
        api = FakeAPI()
        config, locales, _, copyright = metadata()
        store = Store(api, identity("ios"), config, {})
        version = store.ensure_version()
        localization = store.metadata(version, locales, copyright)["en-US"]
        group = config["screenshotGroups"][0]
        aset = api.create("appScreenshotSets", {"screenshotDisplayType": group["displayType"]},
                          {"appStoreVersionLocalization": ("appStoreVersionLocalizations", localization["id"])})
        owner = api.create("appScreenshots", {"fileName": "glintwake-owner.png", "fileSize": 5},
                           {"appScreenshotSet": ("appScreenshotSets", aset["id"])})
        api.calls.clear()
        with self.assertRaises(NeedsAction):
            screenshots(store, localization, group, screenshot_files(group, "en-US"))
        self.assertIn(("appScreenshots", owner["id"]), api.records)
        self.assertFalse(any(method != "GET" for method, _ in api.calls))

    def test_api_cannot_set_an_encryption_exemption(self):
        from Scripts.release.asc import Client, payload
        from test_release import Opener
        opener = Opener()
        client = Client(lambda: "offline", opener)
        with self.assertRaises(ReleaseError):
            client.request("PATCH", "/v1/builds/build", payload("builds", {"usesNonExemptEncryption": False}, id="build"))
        self.assertEqual(opener.requests, [])


class PortableAPIStagesTests(unittest.TestCase):
    def test_review_and_cleanup_require_no_macos_tools(self):
        from Scripts.release import cli
        for platform in ("ios", "macos"):
            with self.subTest(platform=platform), tempfile.TemporaryDirectory() as temp:
                api = FakeAPI()
                ident = identity(platform)
                api.pre["attributes"]["platform"] = ident["platform"]
                with patch.object(cli, "ROOT", pathlib.Path(temp)), patch.object(cli, "Client", return_value=api):
                    with patch.object(signing, "run", side_effect=AssertionError("API-only stage invoked a native tool")):
                        with patch.dict(os.environ, {"ASC_REVIEW_CONTACT_PHONE": "+10000000000"}):
                            self.assertEqual(cli.main(["review", "--platform", platform,
                                                       "--build-number", ident["build"]]), 0)
                            self.assertEqual(cli.main(["cleanup", "--platform", platform,
                                                       "--build-number", ident["build"]]), 0)
                self.assertTrue(any(method == "POST" and path == "/v1/appStoreReviewDetails" for method, path in api.calls))
