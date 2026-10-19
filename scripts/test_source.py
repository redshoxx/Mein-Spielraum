import json
import plistlib
import tempfile
import unittest
import zipfile
from pathlib import Path
from make_source import build_source, BUNDLE_ID

class SourceTests(unittest.TestCase):
    def make_ipa(self, folder, version='0.1.1', executable=True, scheme=True):
        path = Path(folder) / 'test.ipa'
        with zipfile.ZipFile(path, 'w') as z:
            z.writestr('Payload/MeinSpielraum.app/Info.plist', plistlib.dumps({'CFBundleIdentifier': BUNDLE_ID, 'CFBundleShortVersionString': version, 'CFBundleExecutable': 'MeinSpielraum', 'MinimumOSVersion': '17.0', 'CFBundleURLTypes': [{'CFBundleURLSchemes': ['spielraum'] if scheme else []}]}))
            if executable: z.writestr('Payload/MeinSpielraum.app/MeinSpielraum', b'fixture-not-an-ios-build')
        return path
    def test_real_metadata_and_stable_source(self):
        with tempfile.TemporaryDirectory() as d:
            ipa = self.make_ipa(d)
            feed = build_source(ipa, 'redshoxx/Mein-Spielraum', '0.1.1')
            app = feed['apps'][0]
            self.assertEqual(app['bundleIdentifier'], BUNDLE_ID)
            self.assertEqual(app['versions'][0]['size'], ipa.stat().st_size)
            self.assertEqual(app['versions'][0]['minOSVersion'], '17.0')
            self.assertEqual(feed['sourceURL'], 'https://github.com/redshoxx/Mein-Spielraum/releases/latest/download/source.json')
            self.assertNotIn('marketplaceID', app)
            json.dumps(feed)
    def test_reject_mismatched_or_incomplete_ipa(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(ValueError): build_source(self.make_ipa(d), 'redshoxx/Mein-Spielraum', '0.1.2')
            with self.assertRaises(ValueError): build_source(self.make_ipa(d, executable=False), 'redshoxx/Mein-Spielraum', '0.1.1')
    def test_reject_missing_purchase_check_scheme(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(ValueError): build_source(self.make_ipa(d, scheme=False), 'redshoxx/Mein-Spielraum', '0.1.1')
    def test_reject_bad_repository_and_version(self):
        with tempfile.TemporaryDirectory() as d:
            ipa = self.make_ipa(d)
            for repo,version in [('not a repo','0.1.1'), ('a/b','v1'), ('a/b','0.1.01')]:
                with self.assertRaises(ValueError): build_source(ipa, repo, version)

if __name__ == '__main__': unittest.main()
