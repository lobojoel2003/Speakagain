## What changes for the person using Speakagain

<!-- One or two sentences. Screenshots help for anything on screen. -->

## How it was checked

- [ ] `dart format lib test`, `flutter analyze --fatal-infos` and `flutter test --exclude-tags screenshots` pass
- [ ] Tried on a device, emulator or browser (which one?)
- [ ] Large text, dark and high-contrast themes still look right, if it changes a screen
- [ ] New text is in every `lib/l10n/app_*.arb`; translations are by fluent speakers only
- [ ] Packs: checked by a fluent speaker; `python3 tool/sync_pack_assets.py` run
- [ ] `CHANGELOG.md` updated under **Unreleased** if people will notice
