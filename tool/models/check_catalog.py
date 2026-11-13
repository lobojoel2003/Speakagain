#!/usr/bin/env python3
"""Checks every file in assets/models/catalog.json can be downloaded, with the listed size.

    python3 tool/models/check_catalog.py
"""
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def files(catalog: dict):
    for rec in catalog['recognizers']:
        yield from (rec['encoder'], rec['decoder'], rec['tokens'])
    for voice in catalog['voices']:
        yield from (voice['model'], voice['tokens'], voice['modelCard'])
    if catalog.get('voiceData'):
        yield catalog['voiceData']['archive']


def main() -> None:
    catalog = json.loads((ROOT / 'assets' / 'models' / 'catalog.json').read_text(encoding='utf-8'))
    seen, problems = set(), []
    for entry in files(catalog):
        if entry['name'] in seen:
            continue
        seen.add(entry['name'])
        url = catalog['baseUrl'] + entry['name']
        # A one-byte ranged GET: release downloads redirect to signed URLs that refuse HEAD.
        request = urllib.request.Request(url, headers={'User-Agent': 'speakagain-ci', 'Range': 'bytes=0-0'})
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                content_range = response.headers.get('Content-Range', '')
                if response.status == 206 and '/' in content_range:
                    size = int(content_range.rsplit('/', 1)[1])
                else:
                    size = int(response.headers.get('Content-Length', '-1'))
        except Exception as error:  # noqa: BLE001
            problems.append(f'{url}: {error}')
            continue
        if size != entry['bytes']:
            problems.append(f'{url}: {size} bytes, catalog says {entry["bytes"]}')
        else:
            print(f'ok {entry["name"]} ({size} bytes)')
    if problems:
        raise SystemExit('\n'.join(problems))
    print(f'All {len(seen)} files are available.')


if __name__ == '__main__':
    sys.exit(main())
