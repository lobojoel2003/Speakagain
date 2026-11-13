# Speech checking and voices

How Speakagain listens to spoken answers and speaks words, all on the device.

## Choosing an engine

The project brief suggested on-device recognition with Vosk or whisper.cpp. Both were evaluated:

| Option | Finding |
|---|---|
| Vosk (`vosk_flutter`) | Last published in April 2023, limited to Dart 2 (`sdk: <3.0.0`); no iOS support. Not usable with current Flutter. |
| whisper.cpp (`whisper_ggml`) | Maintained, but depends on `ffmpeg_kit_flutter_new_min` for audio conversion, which adds FFmpeg to every build. |
| **sherpa-onnx** (`sherpa_onnx`) | Official package of the k2-fsa project, released every few weeks, Android, iOS, macOS, Linux and Windows. Runs Whisper models, and also runs the Piper voices Saywell uses. |

Speakagain uses **sherpa-onnx 1.13.8**: one native engine does both speech checking (Whisper) and
natural voices (Piper). Version 2 removed the built-in eSpeak NG phonemizer that Piper voices need,
so the dependency stays on 1.13.x (Dependabot is told to skip major updates).

The engine runs in **one long-lived background isolate** (`lib/services/speech/speech_engine_io.dart`)
that keeps the last recogniser and voice loaded, so loading an 80 MB model or decoding an answer
never freezes the screen.

## Recording an answer

`lib/services/speech/recorder.dart` records 16 kHz mono audio with the `record` package (noise
suppression and automatic gain on) and finds the answer with a small energy-based end-of-speech
detector:

- it follows the room's noise level until speech starts (three loud 20 ms frames in a row);
- the answer ends after **1.4 seconds** of quiet, which allows the slow speech and pauses common
  after a stroke;
- it gives up after 7 seconds without speech, and stops at 10 seconds;
- it keeps 0.3 s before and 0.35 s after the speech, and drops the rest.

If nothing was heard, the person is told so gently and nothing counts as a try.

## Recognising it

The trimmed audio, padded with 0.25 s of silence on each side (Whisper hears isolated words better
with some room), goes to Whisper with the language forced to the practice language.

### The models

The models release (tag `models-v1`) holds:

| Files | Size | Source |
|---|---|---|
| `whisper-base-encoder.int8.onnx`, `whisper-base-decoder.int8e.onnx` | 29 + 51 MB | sherpa-onnx's Whisper base export |
| `whisper-tiny-encoder.int8.onnx`, `whisper-tiny-decoder.int8e.onnx` | 13 + 31 MB | sherpa-onnx's Whisper tiny export |
| `whisper-tokens.txt` | 0.8 MB | shared by both |

sherpa-onnx's int8 Whisper decoders quantize the matrix multiplications but leave the
51,865 × d<sub>model</sub> token embedding in 32-bit floats: 106 MB of the 131 MB *base* decoder.
[`tool/models/shrink_whisper_decoder.py`](../tool/models/shrink_whisper_decoder.py) stores that
table as 8-bit with one scale per row and rewrites its two uses (the embedding lookup and the
output projection, as `DynamicQuantizeLinear` + `MatMulInteger`). The graph's inputs and outputs
don't change, so sherpa-onnx loads it as usual. The base download goes from 160 MB to 81 MB, and
tiny from 103 MB to 44 MB, with the same transcripts on our test words.

The [Models workflow](../.github/workflows/models.yml) runs
[`tool/models/build_models.py`](../tool/models/build_models.py): it downloads the pinned upstream
archives (`tool/models/sources.json`, SHA-256 checked), extracts the needed files, shrinks the
decoders with pinned `onnx` and `numpy` versions, and fails unless every output matches
`assets/models/catalog.json` byte for byte. Only then does it publish the release. The app checks
every download against the same SHA-256 sums.

### Matching the answer

`lib/core/answer_matcher.dart` compares what was heard with the item's `answer` and `accept` list.
Both are normalised (`lib/core/text_normalizer.dart`):

- lower case, punctuation removed, accents folded (`miércoles` = `miercoles`, `Fuß` = `fuss`);
- Arabic: diacritics, letter variants (أ إ آ → ا, ة → ه, ى → ي) and the article ال;
- Hindi: nukta and chandrabindu variants; Arabic-Indic and Devanagari digits as digits;
- Chinese: traditional characters used in the packs mapped to simplified, compared by character;
- doubled letters collapsed (`perro` ~ `pero`).

The answer counts if it appears as words anywhere in what was heard (`"it's an apple"`,
`"apple apple apple"`), or if the closest stretch of what was heard is similar enough (Levenshtein
similarity, also across split words: `"man sana"` ~ `manzana`):

| Setting | Counts as said | "Nearly there!" |
|---|---|---|
| Gently (default) | ≥ 0.72 | ≥ 0.40 |
| Closely | ≥ 0.86 | ≥ 0.55 |

### Limits

Whisper is not trained on aphasic speech, and isolated words are hard for any recogniser. It is
also weaker in Hindi, Arabic, Chinese, Polish and Dutch than in English, Spanish, French, German,
Italian and Portuguese. So the app never depends on it: **I said it** is always available, help is
offered instead of a verdict, and the person can switch speech checking off. On the web, where the
models don't run, the person always confirms their own answer.

## Speaking

`lib/services/speech/speech_services.dart`:

- **Phone's voice** (default): `flutter_tts` with the language's locale, at a slower or normal rate.
- **Natural voices**: Saywell's Piper voices with clear licences, synthesised by sherpa-onnx in the
  same background isolate and played with `audioplayers`. They need the shared eSpeak NG data
  (`espeak-ng-data.zip`, 9 MB), downloaded once with the first voice.
- If a natural voice fails, the phone's voice speaks instead, so *Hear it* always works.
- *Hear me* plays back the last try, made louder if it was quiet.
