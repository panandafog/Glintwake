"""Portable signing audit against disposable P12 and CMS fixtures, no Apple account."""
import base64
import contextlib
import datetime
import io
import os
import pathlib
import plistlib
import tempfile
import unittest
from unittest.mock import patch

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.serialization import pkcs12, pkcs7
from cryptography.x509.oid import NameOID

from Scripts.release import signing
from Scripts.release.metadata import NeedsAction, ReleaseError, identity
from Scripts.release.plan import choose_build


class PreflightTests(unittest.TestCase):
    @classmethod
    def certificate(cls, name):
        key = ec.generate_private_key(ec.SECP256R1())
        subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, name)])
        now = datetime.datetime.now(datetime.timezone.utc)
        cert = (x509.CertificateBuilder().subject_name(subject).issuer_name(subject)
                .public_key(key.public_key()).serial_number(x509.random_serial_number())
                .not_valid_before(now - datetime.timedelta(days=1))
                .not_valid_after(now + datetime.timedelta(days=30)).sign(key, hashes.SHA256()))
        return key, cert

    @staticmethod
    def p12(key, cert):
        return base64.b64encode(pkcs12.serialize_key_and_certificates(
            b'fixture', key, cert, None, serialization.BestAvailableEncryption(b'fixture-password'))).decode()

    def materials(self, platform, profile_change=None, certificate_name=None):
        ident = identity(platform)
        key, cert = self.certificate(certificate_name or 'Apple Distribution: Test (' + ident['teamId'] + ')')
        profile = dict(ExpirationDate=datetime.datetime.now() + datetime.timedelta(days=10),
                       TeamIdentifier=[ident['teamId']], Platform=['iOS' if platform == 'ios' else 'OSX'],
                       DeveloperCertificates=[cert.public_bytes(serialization.Encoding.DER)],
                       Entitlements={'application-identifier': ident['teamId'] + '.' + ident['bundleId']})
        profile.update(profile_change or {})
        cms = (pkcs7.PKCS7SignatureBuilder().set_data(plistlib.dumps(profile))
               .add_signer(cert, key, hashes.SHA256())
               .sign(serialization.Encoding.DER, [pkcs7.PKCS7Options.Binary]))
        prefix = 'IOS' if platform == 'ios' else 'MAC_APP'
        env = {prefix + '_DISTRIBUTION_P12_BASE64': self.p12(key, cert),
               prefix + '_DISTRIBUTION_P12_PASSWORD': 'fixture-password',
               ('IOS' if platform == 'ios' else 'MAC') + '_PROVISION_PROFILE_BASE64': base64.b64encode(cms).decode()}
        if platform == 'macos':
            installer_key, installer = self.certificate('3rd Party Mac Developer Installer: Test (' + ident['teamId'] + ')')
            env.update(MAC_INSTALLER_P12_BASE64=self.p12(installer_key, installer),
                       MAC_INSTALLER_P12_PASSWORD='fixture-password')
        return env

    def test_matching_p12_and_cms_profiles_pass_for_both_platforms_without_keychain(self):
        for platform in ('ios', 'macos'):
            with self.subTest(platform=platform), patch.dict(os.environ, self.materials(platform), clear=True), \
                    contextlib.redirect_stdout(io.StringIO()):
                signing.validate_materials(platform)

    def test_wrong_password_and_wrong_team_are_rejected_before_building(self):
        cases = [self.materials('ios') | {'IOS_DISTRIBUTION_P12_PASSWORD': 'wrong'},
                 self.materials('ios', certificate_name='Apple Distribution: Test (OTHERTEAM)')]
        for env in cases:
            with self.subTest(keys=list(env)), patch.dict(os.environ, env, clear=True), self.assertRaises(NeedsAction):
                signing.validate_materials('ios')

    def test_profile_must_include_the_imported_certificate_and_exact_platform(self):
        for change in ({'DeveloperCertificates': []}, {'Platform': ['OSX']},
                       {'ExpirationDate': datetime.datetime.now() - datetime.timedelta(days=1)},
                       {'ProvisionedDevices': ['fixture-device']}):
            with self.subTest(change=change), patch.dict(os.environ, self.materials('ios', change), clear=True), \
                    self.assertRaises(NeedsAction):
                signing.validate_materials('ios')

    def test_mac_installer_requires_its_own_certificate_type(self):
        env = self.materials('macos')
        env['MAC_INSTALLER_P12_BASE64'] = env['MAC_APP_DISTRIBUTION_P12_BASE64']
        with patch.dict(os.environ, env, clear=True), self.assertRaises(NeedsAction):
            signing.validate_materials('macos')

    def test_all_missing_secrets_are_reported_together_and_review_needs_no_signing(self):
        with patch.dict(os.environ, {}, clear=True), self.assertRaises(NeedsAction) as caught:
            signing.preflight(['ios', 'macos'], 'full')
        for name in ('IOS_PROVISION_PROFILE_BASE64', 'MAC_PROVISION_PROFILE_BASE64', 'MAC_INSTALLER_P12_PASSWORD'):
            self.assertIn(name, str(caught.exception))
        self.assertNotIn('FINDER', str(caught.exception))
        env = {name: 'dGVzdA==' for name in signing.required_secrets('ios', 'review')}
        with patch.dict(os.environ, env, clear=True):
            signing.preflight(['ios', 'macos'], 'review')

    def test_auto_build_and_explicit_retries(self):
        self.assertEqual(choose_build('5', ['4', '5', '8'], '', 'full'), '9')
        self.assertEqual(choose_build('5', ['8'], '6', 'full'), '6')
        self.assertEqual(choose_build('5', [], '', 'full'), '5')
        with self.assertRaises(ReleaseError):
            choose_build('5', [], '$(not-a-number)', 'full')

    def test_artifact_commit_must_match_verified_source_run(self):
        import hashlib
        import json
        ident = identity('ios')
        source = dict(repository='panandafog/Glintwake', sha='a' * 40, runId='123',
                      workflow='.github/workflows/app-store-release.yml')
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            export = root / 'Artifact'
            export.mkdir()
            artifact = export / 'Glintwake.ipa'
            artifact.write_bytes(b'fixture')
            (export / 'artifact.json').write_text(json.dumps(dict(identity=ident, source=source,
                file=artifact.name, sha256=hashlib.sha256(artifact.read_bytes()).hexdigest())))
            (root / 'artifact-source.json').write_text(json.dumps(source))
            self.assertEqual(signing.binary(root, ident), artifact)
            (root / 'artifact-source.json').write_text(json.dumps(source | {'sha': 'b' * 40}))
            with self.assertRaises(ReleaseError):
                signing.binary(root, ident)
