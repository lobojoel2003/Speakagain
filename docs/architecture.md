# Architecture

Speakagain is one Flutter app for Android, iOS and the web. Everything runs on the device; there
is no server.

```
lib/
  main.dart              start-up: storage, packs, models, speech; licences of bundled assets
  app.dart               MaterialApp: themes, text scale, 11 locales
  app_state.dart         AppState (ChangeNotifier): settings, progress, packs, downloads
  core/
    languages.dart       the 11 languages: names in their own script, TTS locale, spacing
    text_normalizer.dart per-language normalisation for answer matching
    answer_matcher.dart  said / nearly / not yet, with forgiving similarity
    session_planner.dart what to practise next, and which exercise suits each word
    build_info.dart      CI run, commit and channel passed with --dart-define
  models/
    pack.dart            pack format, parsing and validation (every problem at once)
    progress.dart        per-item progress (Leitner boxes), daily logs
    settings.dart        settings with safe parsing
  services/
    local_store.dart     shared_preferences: settings, progress, days (and imported packs on web)
    pack_repository.dart bundled packs from the asset manifest, imported packs, pictures
    pack_importer.dart   .zip or pack.json import with size limits and path checks
    storage/             imported packs: app files (mobile) or browser storage (web)
    models/              model catalog; downloads with SHA-256 checks (mobile) or a stub (web)
    speech/              sherpa-onnx in a background isolate, recorder with end-of-speech
                         detection, WAV encoding, text-to-speech and playback
  ui/
    theme.dart           light, dark and high-contrast themes; SpeakColors (no red)
    widgets/             large buttons, mic button, feedback banner, pictures
    screens/             onboarding, home, practice, summary, progress, settings, packs, about
  l10n/                  app_<language>.arb (generated Dart is not committed)
```

## Platform differences

Platform-specific code is chosen at compile time with conditional imports, so the web build never
imports `dart:io` or FFI code:

| Piece | Android and iOS | Web |
|---|---|---|
| Speech engine | sherpa-onnx (FFI) in an isolate | Not available: the person confirms answers |
| Model store | Files in app support storage | Not available |
| Imported packs | Files in app support storage | Browser storage, pictures embedded |
| Text-to-speech | Phone's engine or natural voice | Browser's speech synthesis |
| Recording | `record` (16 kHz PCM stream) | Not used |

## Data on the device

| What | Where | Backed up by Android |
|---|---|---|
| Settings, progress, practice days | shared preferences | Yes |
| Imported packs | `<app support>/packs/<id>/` | Yes |
| Speech models and voices | `<app support>/models/<id>/` | No (they can be downloaded again) |

Progress is keyed by `<pack id>/<item id>`, so packs can be updated without losing progress for
items whose ids stay the same. At most 400 days of daily logs are kept.

## Practice logic

- **Planning** (`SessionPlanner.plan`): items due for review first (oldest due first), then new
  items taking turns between packs, then the rest, least recently seen first; lightly shuffled.
- **Exercise per item** in a mixed session, by box: 0 → repeat, 1 → listen, 2 → read,
  3+ → name or complete. This keeps most tries successful (errorless learning) while moving towards
  naming without help.
- **Spacing** (`ItemProgress.record`): said without help moves the item up a box, with a hint keeps
  it, with the whole word or skipped moves it down. Boxes come back after 0, 1, 2, 4, 7 and 14 days.
- **Cueing** (`SpokenExercise`): meaning hint → first letter → whole word ("say it together"),
  offered after each try that wasn't caught when *Offer a hint when it's hard* is on.

## Testing

- `test/answer_matcher_test.dart`: normalisation and matching in several scripts.
- `test/pack_test.dart`: the format rules, and every bundled pack (ids, symbols, pictures, same
  concepts in every language).
- `test/planner_test.dart`: planning, exercise choice, picture choices, progress.
- `test/services_test.dart`: end-of-speech detection, WAV, settings, pack import, model catalog.
- `test/l10n_test.dart`: every language has every string with the same placeholders.
- `test/app_flow_test.dart`: whole flows with a fake microphone and recogniser (onboarding, hints,
  listening, self-check, a full session, settings, RTL), and a check that no theme uses red.
- `test/screenshots_test.dart` (tag `screenshots`): renders the README screenshots with the real
  fonts.
