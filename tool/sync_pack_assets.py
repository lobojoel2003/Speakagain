"""Lists every pack folder under assets/packs/ in pubspec.yaml.

Flutter asset folders are not recursive, so each pack folder (and its images
folder) must be named. Run after adding a pack:

    python3 tool/sync_pack_assets.py          # update pubspec.yaml
    python3 tool/sync_pack_assets.py --check  # fail if it is out of date (CI)
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BEGIN, END = '    # BEGIN PACK ASSETS', '    # END PACK ASSETS'


def folders() -> list[str]:
    result = []
    for pack_json in sorted((ROOT / 'assets' / 'packs').glob('**/pack.json')):
        folder = pack_json.parent
        result.append(folder)
        result.extend(sorted(p for p in folder.rglob('*') if p.is_dir()))
    return [f'    - {p.relative_to(ROOT).as_posix()}/' for p in result]


def main() -> None:
    pubspec = ROOT / 'pubspec.yaml'
    text = pubspec.read_text(encoding='utf-8')
    start, end = text.index(BEGIN) + len(BEGIN), text.index(END)
    updated = text[:start] + '\n' + '\n'.join(folders()) + '\n' + text[end:]
    if '--check' in sys.argv:
        if updated != text:
            raise SystemExit('pubspec.yaml does not list every pack folder. Run: python3 tool/sync_pack_assets.py')
        print('pubspec.yaml lists every pack folder')
        return
    pubspec.write_text(updated, encoding='utf-8')
    print(f'Listed {len(folders())} pack folders in pubspec.yaml')


if __name__ == '__main__':
    main()
