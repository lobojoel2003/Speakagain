"""Bundles the OpenMoji symbols into assets/symbols/openmoji/.

Speakagain uses the same symbol set as Saywell: every OpenMoji (CC BY-SA 4.0)
colour symbol without a skin-tone variant (2,456 in OpenMoji 17), from the npm
package pinned below, minified. Packs can use any of them as "openmoji:<HEX>".

    python3 tool/sync_symbols.py          # update assets/symbols/openmoji/
    python3 tool/sync_symbols.py --check  # fail if the folder differs, or a pack or screen
                                          # uses a symbol that isn't bundled (CI)
"""
import hashlib
import io
import json
import re
import sys
import tarfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION = '17.0.0'
SHA256 = '55ee7d13485dec86e9f38c1f3a645a13382d33ff97c0cd845ee824b0aef45e68'
URL = f'https://registry.npmjs.org/openmoji/-/openmoji-{VERSION}.tgz'
OUT = ROOT / 'assets' / 'symbols' / 'openmoji'
CACHE = ROOT / 'build' / f'openmoji-{VERSION}.tgz'


def used_codes() -> set[str]:
    """Symbols the starter packs and the app's screens refer to."""
    codes = set()
    for pack in (ROOT / 'assets' / 'packs').glob('**/pack.json'):
        for item in json.loads(pack.read_text(encoding='utf-8')).get('items', []):
            image = item.get('image', '')
            if image.startswith('openmoji:'):
                codes.add(image[len('openmoji:'):])
    pattern = re.compile(r"'((?:1F|2[0-9A-B]|1FA)[0-9A-F]{2,3}(?:-[0-9A-F]{4,6})*)'")
    for dart in (ROOT / 'lib' / 'ui').glob('**/*.dart'):
        codes.update(pattern.findall(dart.read_text(encoding='utf-8')))
    return codes


def minify(svg: str) -> str:
    svg = re.sub(r'<!--.*?-->', '', svg, flags=re.S)
    svg = re.sub(r'<g id="[^"]*"\s*/>', '', svg)
    svg = re.sub(r'>\s+<', '><', svg)
    return re.sub(r'\s{2,}', ' ', svg).strip()


def archive() -> bytes:
    if CACHE.exists():
        data = CACHE.read_bytes()
    else:
        with urllib.request.urlopen(URL) as response:
            data = response.read()
    if hashlib.sha256(data).hexdigest() != SHA256:
        raise SystemExit(f'Checksum mismatch for {URL}')
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    CACHE.write_bytes(data)
    return data


def symbols() -> dict[str, str]:
    """code -> minified SVG for every bundled symbol."""
    result = {}
    with tarfile.open(fileobj=io.BytesIO(archive()), mode='r:gz') as tar:
        names = {m.name: m for m in tar.getmembers()}
        entries = json.loads(tar.extractfile(names['package/data/openmoji.json']).read())
        for entry in entries:
            code = entry.get('hexcode')
            if not code or entry.get('skintone') or entry.get('group') == 'component':
                continue
            member = names.get(f'package/color/svg/{code}.svg')
            if member is not None:
                result[code] = minify(tar.extractfile(member).read().decode('utf-8'))
        result['LICENSE'] = tar.extractfile(names['package/LICENSE.txt']).read().decode('utf-8')
    return result


def main() -> None:
    wanted = symbols()
    license_text = wanted.pop('LICENSE')
    missing = sorted(used_codes() - wanted.keys())
    if missing:
        raise SystemExit(f'Not in the OpenMoji {VERSION} symbol set: {", ".join(missing)}')

    if '--check' in sys.argv:
        present = {p.stem: p for p in OUT.glob('*.svg')}
        extra = sorted(present.keys() - wanted.keys())
        absent = sorted(wanted.keys() - present.keys())
        changed = sorted(c for c in wanted.keys() & present.keys() if present[c].read_text(encoding='utf-8') != wanted[c])
        if extra or absent or changed:
            raise SystemExit(
                f'assets/symbols/openmoji is out of date (extra: {extra[:5]}, missing: {absent[:5]}, '
                f'changed: {changed[:5]}). Run: python3 tool/sync_symbols.py'
            )
        print(f'{len(wanted)} OpenMoji symbols bundled; all {len(used_codes())} in use are present')
        return

    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob('*.svg'):
        if old.stem not in wanted:
            old.unlink()
    for code, svg in wanted.items():
        (OUT / f'{code}.svg').write_text(svg, encoding='utf-8')
    (OUT / 'LICENSE.txt').write_text(license_text, encoding='utf-8')
    print(f'Bundled {len(wanted)} OpenMoji {VERSION} symbols')


if __name__ == '__main__':
    main()
