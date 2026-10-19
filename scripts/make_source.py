#!/usr/bin/env python3
"""Generate an AltSource v2 feed using metadata from the actual built IPA."""
import argparse
import datetime
import json
import plistlib
import re
import zipfile
from pathlib import Path

BUNDLE_ID = 'at.redshoxx.meinspielraum'

def build_source(ipa: Path, repository: str, version: str) -> dict:
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise ValueError('Expected GitHub OWNER/REPOSITORY')
    if not re.fullmatch(r'0|[1-9][0-9]*', version.split('.')[-1]) or not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version):
        raise ValueError('Version must have three numeric components')
    with zipfile.ZipFile(ipa) as archive:
        plists = [p for p in archive.namelist() if re.fullmatch(r'Payload/[^/]+\.app/Info.plist', p)]
        if len(plists) != 1:
            raise ValueError('IPA must contain exactly one root application')
        info = plistlib.loads(archive.read(plists[0]))
        if info.get('CFBundleIdentifier') != BUNDLE_ID or info.get('CFBundleShortVersionString') != version:
            raise ValueError('Built IPA identifier or version does not match source')
        executable = info.get('CFBundleExecutable', '')
        root = plists[0].removesuffix('Info.plist')
        if not executable or root + executable not in archive.namelist():
            raise ValueError('IPA executable is missing')
    base = f'https://github.com/{repository}/releases'
    source_url = f'{base}/latest/download/source.json'
    release_url = f'{base}/download/v{version}'
    return {
        'name': 'Mein Spielraum',
        'identifier': 'at.redshoxx.meinspielraum.source',
        'sourceURL': source_url,
        'apps': [{
            'name': 'Mein Spielraum',
            'bundleIdentifier': BUNDLE_ID,
            'developerName': 'redshoxx',
            'subtitle': 'Haushaltsbudget und Spartöpfe – einfach und offline',
            'localizedDescription': 'Dein Wochenbudget, deine Ausgaben und Sparziele. Lokale Speicherung auf deinem iPhone, Backup-Export und Wiederherstellung. Keine Anmeldung, keine Bankanbindung.',
            'iconURL': f'{release_url}/icon.png',
            'tintColor': '65F3C5',
            'versions': [{
                'version': version,
                'date': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
                'downloadURL': f'{release_url}/Mein-Spielraum.ipa',
                'size': ipa.stat().st_size,
                'minOSVersion': str(info.get('MinimumOSVersion', '17.0')),
                'localizedDescription': f'Version {version}. Automatischer Build aus GitHub; Änderungen siehe GitHub-Release.'
            }]
        }],
        'news': []
    }

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--ipa', type=Path, required=True)
    p.add_argument('--repository', required=True)
    p.add_argument('--version', required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    a.output.write_text(json.dumps(build_source(a.ipa, a.repository, a.version), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
