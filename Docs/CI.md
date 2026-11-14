# Continuous integration

`Build and Test` runs on dev pushes, pull requests and explicit dispatch. It tests
the solver/generator with `swift test -c release` and builds native iOS/macOS Release apps without signing.
Generated project drift and Scripts/verify-release.py failures fail the job.
Failure logs/xcresults are retained for seven days. No Apple secrets are used.

`Release automation checks` runs offline Python API/workflow/signing-fixture tests
on Linux and validates real fastlane deliver options using Ruby. No Apple requests,
transports, user Keychain access or screenshot captures occur in these tests.
Temporary signing fixtures use generated keys, certificates and CMS profiles.

Upload and review are separate manual workflows described in
[App Store release automation](APP_STORE_RELEASE_AUTOMATION.md). Review runs on
Linux; distribution packaging runs on macOS. Their shared concurrency lock is not
cancelled by a later run. Run/attempt-aware summaries preserve successful platform
results across partial reruns and expose early startup errors.

Changes to the split pipeline are being prepared on dev. The master branch and
published release are left untouched. The app marketing version/build need not
change for CI-only edits. An upload can select a new shared build automatically;
retries and review always use the exact prior build number.

Local validation of this migration: 113 offline release-automation tests, 20 Swift
core tests in Release, native iOS and Mac Release compilation and bundle checks,
reproducible project generation, actionlint and real fastlane option validation.
No signing/upload/review mutation in Apple was performed for these CI changes.
