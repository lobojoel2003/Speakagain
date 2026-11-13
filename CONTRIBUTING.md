# Contributing to Speakagain

Thank you for helping. Speakagain is for people relearning words after a stroke or brain injury,
so the most valuable contributions are often not code:

- **Feedback from people with aphasia, families and speech and language therapists**: what helps,
  what is confusing, what is missing. Open an issue, in any language.
- **Exercise packs**: vocabulary that matters to people, in any language. See
  [docs/packs.md](docs/packs.md).
- **Languages**: reviewing or improving app text and starter packs, or adding a language.
- **Bug reports** and **code**.

Please follow the [code of conduct](CODE_OF_CONDUCT.md). Don't include personal or health
information about anyone in issues or examples.

## Languages

App text is in `lib/l10n/app_<language>.arb`; starter packs are in `assets/packs/<language>/`.

- Translations and packs are accepted **only from people who speak the language fluently**.
  Machine translation is not accepted: a wrong or unnatural word in a therapy app does more harm
  than an English one.
- The current non-English text and packs have not yet been reviewed by native-speaking speech and
  language therapists. A review, even of a few strings, is a great first contribution: open an
  issue or a pull request saying which language and what you checked.
- Keep text short, warm and plain. Prefer forms that don't assume the person's gender. Never use
  words like "wrong", "error" or "failed" for an answer.
- **Adding a language**: add it to `lib/core/languages.dart`, add `lib/l10n/app_<code>.arb` with
  every string (the test `test/l10n_test.dart` checks), add the four starter packs under
  `assets/packs/<code>/` (the same items as English in `everyday-words`), run
  `python3 tool/sync_pack_assets.py`, and add the locale to `CFBundleLocalizations` in
  `ios/Runner/Info.plist`.

## Code

You need Flutter 3.47.9. Before opening a pull request:

```bash
dart format lib test && flutter analyze --fatal-infos
```

```bash
flutter test --exclude-tags screenshots
```

```bash
python3 tool/version.py check && python3 tool/sync_pack_assets.py --check && python3 tool/sync_symbols.py --check
```

Guidelines:

- **Design for the people who use it.** Large targets (at least 64 dp, main actions 76 dp or more),
  an icon with every button label, main actions at the bottom within thumb reach, no time pressure,
  and nothing that feels like failing. There is a test that no theme colour is red; keep it that way.
- **Everything works offline**, and nothing is sent anywhere. New network use needs a very good
  reason and a note in [PRIVACY.md](PRIVACY.md).
- **Every user-facing string** goes in the ARB files, in every language (ask in the pull request if
  you can't translate; a maintainer will find a fluent speaker).
- **Tests** for logic in `lib/core/` and `lib/models/`, and a widget test for new flows. If a screen
  changes, run `flutter test --tags screenshots` and update `docs/screenshots/` if the README
  pictures change.
- Add a line to `CHANGELOG.md` under **Unreleased** for anything people will notice.

## Releases

See [docs/releasing.md](docs/releasing.md).

## Licence

By contributing, you agree that your contributions are licensed under the
[GPL-3.0-or-later](LICENSE) (code) or [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
(packs and pictures).
