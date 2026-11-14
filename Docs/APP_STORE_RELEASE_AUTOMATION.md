# App Store release automation

The pipeline was split using the verified Farport implementation. All changes are
prepared on `dev`; `master`, the published release and App Store data are unchanged.

## Workflows

| Workflow | Where it runs | Purpose |
| --- | --- | --- |
| Build and Test | Push to dev, pull requests, manual | Solver/generator tests and unsigned native iOS/Mac Release builds |
| Release automation checks | PRs and changes to release files | Offline API/security/workflow tests and real fastlane option validation |
| Upload App Store Build | Manual, master or dev | Audit signing, build or restore a package, upload, wait for VALID |
| Prepare App Store Review | Manual, master or dev | Metadata/screenshots, exact build selection, review draft or read-only status |

Normal CI has no Apple secrets and never uploads a binary. Upload and review use
the `app-store` environment, explicitly permit only `panandafog/Glintwake` and
trusted branches, and share a concurrency group with cancellation disabled.
Environment protection must permit dev when testing release jobs from dev.
GitHub may require a newly added manual workflow to exist on the default branch
before offering it in Run workflow. This does not require merging code merely to
run ordinary push/PR checks on dev.

### Upload App Store Build

File: `.github/workflows/app-store-release.yml`.

| Input | Meaning |
| --- | --- |
| platform | both, ios or macos |
| source | build: new signed package; artifact: restore a package from a previous upload run |
| build_number | Blank for a NEW build: audit chooses one number above the existing Apple inventory for both selected platforms, at least the project number. For retries supply the SAME exact number from the previous Summary |
| artifact_run_id | Required only for artifact source: numeric original GitHub run ID |

The Ubuntu audit checks missing inputs together, P12/password, expiration, profile
identity/platform, certificate membership and installer certificate. It uses
portable cryptography/OpenSSL; macOS preparation starts only after audit succeeds.
The chosen build is passed to both platform jobs. Marketing version still comes
from project.yml. The audit does not read review text/PNG files or mutate Apple.

macOS runners archive/export only when necessary, preserve the signed package
before transport, upload it, and wait for the exact build to become VALID.
Already accepted builds/receipts are reused. Upload does not edit existing review
metadata, select another review build, or remove/cancel a draft or active review.
A missing platform is registered before its first transport request.

Success means UPLOADED, not READY_FOR_REVIEW. The Summary gives the build number
and link to the separate review workflow. Missing encryption information is shown
as an owner action without falsely treating a successful binary delivery as failed.
Glintwake's archived privacy/encryption assertions remain unchanged: no non-exempt
encryption. The pipeline never writes Apple's legal declaration to force a pass.

### Prepare App Store Review

File: `.github/workflows/app-store-review.yml`. Ubuntu runners only; no Xcode,
Ruby, signing certificates or provisioning profiles are required.

| Input | Meaning |
| --- | --- |
| platform | both, ios or macos |
| action | prepare: metadata/screenshots + review draft; status: read-only verification |
| build_number | Required: exact number from the upload Summary |

Prepare checks encryption before metadata mutations, reads existing EN/RU text
from AppStore/app-store-metadata.md and PNG files from AppStore/screenshots, binds
the exact processed build, updates contact/notes and prepares an unsubmitted draft.
Status reads back the exact version resource, selected build, metadata, screenshot
checksums/order/COMPLETE state, and matching review item/draft. READY_FOR_REVIEW is
reported only after Apple confirms it. Existing matching ready drafts are checked
read-only; an old build in a ready draft requires an explicit owner decision in ASC.
Active submitted reviews and live versions are not rewritten or cancelled.

## Signing secrets

Add secrets under Settings → Environments → app-store. Never paste their values
into an issue/chat, commit them, print them in logs or place them in artifacts.

| Secret | Contents |
| --- | --- |
| ASC_KEY_ID | App Store Connect Team API key ID |
| ASC_ISSUER_ID | Team API issuer ID |
| ASC_PRIVATE_KEY_P8_BASE64 | Original .p8 file, single-line Base64 |
| ASC_REVIEW_CONTACT_PHONE | Review contact phone in international format; review preparation only |
| IOS_DISTRIBUTION_P12_BASE64 | Apple Distribution certificate AND private key exported as .p12, Base64 |
| IOS_DISTRIBUTION_P12_PASSWORD | Nonempty export password, plain text |
| IOS_PROVISION_PROFILE_BASE64 | App Store Connect profile for com.panandafog.glintwake, Base64 |
| MAC_APP_DISTRIBUTION_P12_BASE64 | Apple Distribution or Mac App Distribution certificate/private key, Base64 |
| MAC_APP_DISTRIBUTION_P12_PASSWORD | Nonempty .p12 export password, plain text |
| MAC_INSTALLER_P12_BASE64 | Mac Installer Distribution certificate/private key, Base64 |
| MAC_INSTALLER_P12_PASSWORD | Its export password, plain text |
| MAC_PROVISION_PROFILE_BASE64 | Separate Mac App Store Connect profile for com.panandafog.glintwake, Base64 |

One compatible Apple Distribution .p12 can be used for iOS and Mac if both profiles
include that certificate. Profiles remain platform-specific. Glintwake has one
application target and NO Finder extension. Team: 3HG9ZBM8AV.
The existing API key is sufficient; no new Apple Account password or new API key is
needed. Certificates/profiles require replacement when expired/revoked.

Export certificates in Xcode → Settings → Accounts → Team → Manage Certificates →
Export Certificate. A .cer alone has no private key. Create distribution profiles
in Apple Developer → Certificates, Identifiers & Profiles → Profiles, choosing
App Store Connect for iOS and Mac App Store Connect for Mac.
Copy a file's Base64 without printing it:

```sh
base64 -i /absolute/path/to/file.p12 | tr -d '\n' | pbcopy
```

Mac temporary keychains/profiles and temporary API-key files are cleaned up.
API keys are ES256 JWTs with bounded lifetime; storage uploads use a separate client
and never receive the ASC bearer token. Diagnostics mask secrets before truncation.

## Packages and retries

Signed package artifact: `app-store-<ios|macos>-<RUN_ID>`, kept for 14 days.
Its manifest binds the binary checksum to app/platform/version/build and source
repository, workflow, commit SHA and run ID. Restoring is allowed only from a
completed manual upload workflow on this repository's default branch or dev.
Forks, PRs, other workflows and manifest/source mismatches fail before transport.
Old pre-migration artifacts without source provenance cannot be restored by the
new workflow. Build a new package instead; do not fabricate provenance for them.

Use explicit build_number on every retry. A fresh upload with an empty number is
intentionally a new build, not a retry. For metadata/review errors, rerun review
with the same build; no rebuild, signing secrets or artifact ID is required.
For an upload interrupted after packaging, select source=artifact with the original
run ID and the original build number.

Each report artifact includes run ID and numeric attempt. The aggregate result
picks the latest available report PER platform, preserving a successful platform
when only the other one is retried. It rejects foreign, duplicate/future attempts
and conflicting release identities. Rerunning only the result job can reuse the
latest reports from earlier attempts. Startup/dependency/cleanup/artifact errors
remain visible even when Python API initialization never completed.

The Summary contains outcome, reason, failed step, exact next action and links.
Screenshot progress identifies language, device and file without signed upload URLs.
Only fully matched automation filename conventions grant deletion ownership;
identical manually uploaded PNGs may be reused, unrelated owner files are preserved.

## Assets and App Store owner decisions

Text stays in AppStore/app-store-metadata.md, optional update notes in
AppStore/release-notes/<VERSION>/<en-US|ru-RU>.txt. Russian source folders use ru-RU,
while Apple's API locale is ru. Public support/privacy URLs are verified before
metadata changes. Optional omitted values do not clear existing remote data.

Current 40 PNGs include iPhone, iPad, Mac and both Duo displays, EN/RU. Capture is
separate local tooling (Docs/FramePilot.md); CI does not launch GUI captures.
Duo PNGs remain excluded from API upload until official supported display types
are configured. No made-up slot identifiers or resized substitute images are used.

Current game age answers are explicit in AppStore/release.json. The initial
questionnaire is complete, read back after modification and determines Apple's
calculated rating; overrides/Kids Category are not invented.

One-time owner decisions remain App Privacy publication, price/territories, Content
Rights, agreements, applicable trader status and any legal/export declarations.
Our first real release confirmed these are enforced when adding a review item.
Nested Apple associatedErrors now appear as sanitized actionable diagnostics.

No workflow invokes Submit for Review, publication, review cancellation or phased
release changes. Final submission and release remain owner actions.

## Local verification

```sh
python3 -m venv /private/tmp/glintwake-ci-env
/private/tmp/glintwake-ci-env/bin/pip install -r Scripts/release/requirements.txt
/private/tmp/glintwake-ci-env/bin/python -m unittest discover -s Tests/ReleaseAutomation -q
actionlint .github/workflows/*.yml
bundle exec ruby Scripts/release/check-fastlane.rb
sh Scripts/xcodegen.sh generate
git diff --exit-code -- Glintwake.xcodeproj
swift test -c release
```

XcodeGen 2.44.1 and its SHA-256 are pinned in Scripts/xcodegen.sh; project.yml remains
the source of truth. Normal CI separately builds Release for native iOS and Mac
without signing and verifies the bundle using Scripts/verify-release.py.

Historical production proof: build 5, both platforms VALID and READY_FOR_REVIEW:
https://github.com/panandafog/Glintwake/actions/runs/43465656415
The new split workflows must be distinguished from this historical verification;
o new delivery to Apple is implied by local/offline tests or unsigned builds.
