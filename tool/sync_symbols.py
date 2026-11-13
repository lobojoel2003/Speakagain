"""Copies the OpenMoji symbols Speakagain uses into assets/symbols/openmoji/.

Speakagain uses the same symbol set as Saywell: OpenMoji (CC BY-SA 4.0), from
the npm package pinned below. Only the symbols that packs and screens use are
bundled, to keep the app small. The script finds them in:

- every `"image": "openmoji:<HEX>"` in assets/packs/**/pack.json
- every quoted symbol code ('1F31F') in lib/ui/

    python3 tool/sync_symbols.py          # update assets/symbols/openmoji/
    python3 tool/sync_symbols.py --check  # fail if a symbol is missing or unused (CI)
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


def main() -> None:
    codes = used_codes()
    if '--check' in sys.argv:
        present = {p.stem for p in OUT.glob('*.svg')}
        missing, unused = sorted(codes - present), sorted(present - codes)
        if missing or unused:
            raise SystemExit(f'Symbols out of date (missing: {missing}, unused: {unused}). Run: python3 tool/sync_symbols.py')
        print(f'{len(codes)} symbols, all bundled')
        return

    with tarfile.open(fileobj=io.BytesIO(archive()), mode='r:gz') as tar:
        names = {m.name: m for m in tar.getmembers()}
        OUT.mkdir(parents=True, exist_ok=True)
        for old in OUT.glob('*.svg'):
            old.unlink()
        missing = []
        for code in sorted(codes):
            member = names.get(f'package/color/svg/{code}.svg')
            if member is None:
                missing.append(code)
                continue
            (OUT / f'{code}.svg').write_text(minify(tar.extractfile(member).read().decode('utf-8')), encoding='utf-8')
        license_member = names['package/LICENSE.txt']
        (OUT / 'LICENSE.txt').write_bytes(tar.extractfile(license_member).read())
    if missing:
        raise SystemExit(f'Not in OpenMoji {VERSION}: {", ".join(missing)}')
    print(f'Bundled {len(codes)} OpenMoji {VERSION} symbols')


if __name__ == '__main__':
    main()
