# Changelog

All notable changes to Speakagain are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/). The build number (Android `versionCode`, iOS
`CFBundleVersion`) is `MAJOR * 10000 + MINOR * 100 + PATCH`.

## [Unreleased]

## [1.0.0] - 2026-11-13

First release: free, offline speech practice for people with aphasia, in 11 languages, for
Android, iOS and the web.

### Added

- **Five exercises**: name the picture, listen and choose, read aloud, say it after me, and finish
  the sentence (including automatic series such as counting and the days of the week).
- **Today's practice**: a mixed session that moves each word from easier to harder exercises as
  it is learned, and brings words back with spaced repetition (after 1, 2, 4, 7 and 14 days).
- **Help in small steps**, in the usual cueing order: a meaning hint, the first letter, then
  hearing the word to say together. Offered automatically after a try that wasn't caught, or any
  time with *Hint* and *Hear it*.
- **Speech checking on the device** with OpenAI Whisper (base 81 MB or tiny 44 MB, one-time
  download, SHA-256 checked, or installed from a file), forgiving answer matching for 11 languages,
  *I said it* for the person or a carer to confirm, and *Hear me* to play back the last try.
- **Encouraging feedback**: praise, a soft chime and a green tick for success; warm "nearly there"
  messages otherwise. No red and no crosses anywhere.
- **Voices**: the phone's text-to-speech, or 10 natural Piper voices from Saywell (English,
  Spanish, French, German, Portuguese, Dutch and Polish) that work offline, at a slower or normal
  speed.
- **11 languages** for app text and starter packs: English, Spanish, French, German, Italian,
  Portuguese, Dutch, Polish, Hindi, Arabic (right to left) and Mandarin Chinese.
- **Starter packs** in every language: Everyday words (50 pictured words in 7 categories), Finish
  the sentence (18), Counting and days (15) and Useful phrases (16), with Saywell's OpenMoji symbols
  (all 2,456 bundled).
- **Exercise packs** as JSON plus pictures, with a JSON schema and a guide; import a pack from a
  `.zip` or `pack.json` in the app.
- **Progress** as encouragement: practice days this week, words practised, words getting easier.
- **Accessible design**: Atkinson Hyperlegible font, large text with three sizes on top of the
  phone's setting, light, dark and high-contrast themes (WCAG AAA), controls within thumb reach,
  instructions read out loud, screen reader labels.
- **Private by design**: no account, ads or tracking; practice stays on the device.
- **CI/CD**: checks, 100+ tests and screenshots on every change; signed Android APKs and App
  Bundle, the web app and an unsigned iOS build published from a version tag; a reproducible models
  release.

[Unreleased]: https://github.com/lobojoel2003/Speakagain/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/lobojoel2003/Speakagain/releases/tag/v1.0.0
