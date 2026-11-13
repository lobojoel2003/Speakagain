#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Release version checks and release notes.

The version lives in pubspec.yaml as `version: MAJOR.MINOR.PATCH+BUILD`, where the
build number is MAJOR * 10000 + MINOR * 100 + PATCH (1.0.0 -> 10000, 1.2.3 -> 10203).
It becomes the Android versionCode and the iOS CFBundleVersion, so every release
installs as an update of the one before.

    python3 tool/version.py check            # version valid, build number right, CHANGELOG has it
    python3 tool/version.py check v1.0.0     # ...and the tag matches
    python3 tool/version.py name             # 1.0.0
    python3 tool/version.py build            # 10000
    python3 tool/version.py notes v1.0.0     # the CHANGELOG section, for the GitHub Release
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def pubspec_version() -> tuple[str, int]:
    match = re.search(r'^version:\s*(\S+)\s*$', (ROOT / 'pubspec.yaml').read_text(encoding='utf-8'), re.M)
    if not match:
        raise SystemExit('pubspec.yaml has no version: line')
    value = match.group(1)
    parts = re.fullmatch(r'(\d+)\.(\d{1,2})\.(\d{1,2})\+(\d+)', value)
    if not parts:
        raise SystemExit(f"pubspec.yaml version '{value}' must be MAJOR.MINOR.PATCH+BUILD (MINOR and PATCH below 100)")
    return f'{parts[1]}.{parts[2]}.{parts[3]}', int(parts[4])


def build_number(name: str) -> int:
    major, minor, patch = (int(p) for p in name.split('.'))
    return major * 10000 + minor * 100 + patch


def notes(version: str) -> str:
    version = version.removeprefix('refs/tags/').removeprefix('v')
    text = (ROOT / 'CHANGELOG.md').read_text(encoding='utf-8')
    match = re.search(rf'^## \[{re.escape(version)}\][^\n]*\n(.*?)(?=^## \[|\Z)', text, re.M | re.S)
    if not match:
        raise SystemExit(f'CHANGELOG.md has no section for {version}')
    body = re.sub(r'^\[[^\]]+\]: \S+\s*$', '', match.group(1), flags=re.M)
    return body.strip() + '\n'


def check(tag: str | None) -> None:
    name, build = pubspec_version()
    expected = build_number(name)
    if build != expected:
        raise SystemExit(f'pubspec.yaml: build number for {name} must be {expected} (got {build})')
    notes(name)
    if tag is not None:
        tag = tag.removeprefix('refs/tags/')
        if tag != f'v{name}':
            raise SystemExit(f'Tag {tag} does not match pubspec.yaml (v{name})')
    print(f'Speakagain {name}, build {build}')


def main() -> None:
    command = sys.argv[1] if len(sys.argv) > 1 else 'check'
    argument = sys.argv[2] if len(sys.argv) > 2 else None
    if command == 'check':
        check(argument)
    elif command == 'name':
        print(pubspec_version()[0])
    elif command == 'build':
        print(pubspec_version()[1])
    elif command == 'notes':
        print(notes(argument or pubspec_version()[0]), end='')
    else:
        raise SystemExit(__doc__)


if __name__ == '__main__':
    main()
