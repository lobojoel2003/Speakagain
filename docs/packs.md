# Making exercise packs

A pack is a set of words, phrases or sentences to practise in one language. Anyone can make one: a
speech and language therapist with a client's own vocabulary, a family with names and places that
matter at home, or a community adding a language. No programming is needed.

- [What a pack looks like](#what-a-pack-looks-like)
- [Fields](#fields)
- [Pictures](#pictures)
- [Exercises](#exercises)
- [Writing good items](#writing-good-items)
- [Trying a pack in the app](#trying-a-pack-in-the-app)
- [Adding a pack to Speakagain for everyone](#adding-a-pack-to-speakagain-for-everyone)
- [Checking a pack](#checking-a-pack)

## What a pack looks like

A folder with a `pack.json`, and an `images/` folder if the pack has its own pictures:

```
en-my-family/
  pack.json
  images/
    maria.jpg
    rex.jpg
```

```json
{
  "$schema": "https://raw.githubusercontent.com/lobojoel2003/Speakagain/main/schema/pack.schema.json",
  "format": 1,
  "id": "en-my-family",
  "version": "1.0.0",
  "language": "en",
  "title": "My family",
  "description": "The people and pets at home.",
  "author": "Sam (speech and language therapist)",
  "license": "CC BY-SA 4.0",
  "exercises": ["name", "listen", "read", "repeat", "complete"],
  "categories": {
    "people": "Someone in the family",
    "pets": "An animal at home"
  },
  "items": [
    {
      "id": "maria",
      "answer": "Maria",
      "image": "images/maria.jpg",
      "category": "people",
      "cue": "Your daughter",
      "sentence": "Your daughter is called ___."
    },
    {
      "id": "rex",
      "answer": "Rex",
      "accept": ["Rexy"],
      "image": "images/rex.jpg",
      "category": "pets"
    },
    {
      "id": "cup-of-tea",
      "answer": "a cup of tea",
      "accept": ["cup of tea", "tea"],
      "image": "openmoji:1F375"
    }
  ]
}
```

The `$schema` line is optional: editors such as VS Code then check the file and suggest fields as
you type.

## Fields

| Field | Required | What |
|---|:-:|---|
| `format` | ✓ | Always `1`. |
| `id` | ✓ | Unique, lowercase letters, digits and dashes, starting with the language: `es-cocina`. |
| `version` | ✓ | The pack's own version, `MAJOR.MINOR.PATCH`. Raise it when you change the pack. |
| `language` | ✓ | Language code: `en`, `es`, `fr`, `de`, `it`, `pt`, `nl`, `pl`, `hi`, `ar`, `zh`, or another code such as `pt-BR`. The pack shows when that language is chosen. |
| `title` | ✓ | Short title in the pack's language. |
| `description` |  | One sentence about the pack, in its language. |
| `author` |  | Who made it. |
| `license` |  | Licence for the text and pictures. Starter packs use `CC BY-SA 4.0`. |
| `exercises` | ✓ | Which exercises the pack offers (see [Exercises](#exercises)). |
| `categories` |  | Meaning hints by category: `{"food": "Something to eat or drink"}`. |
| `items` | ✓ | The words, phrases or sentences. |

Each item:

| Field | Required | What |
|---|:-:|---|
| `id` | ✓ | Unique within the pack: lowercase letters, digits and dashes. Progress is saved by pack and item id, so keep ids when you edit a pack. |
| `answer` | ✓ | What the person says, written as it should be shown: `apple`, `Apfel`, `a cup of tea`. |
| `accept` |  | Other answers that also count: plurals, synonyms, regional words, digits (`"7"` for *seven*), with or without articles. |
| `image` |  | `openmoji:<code>` or `images/<file>` (see [Pictures](#pictures)). |
| `category` |  | A key of `categories`; its text is the meaning hint. |
| `cue` |  | A meaning hint for this item only (used instead of the category's). |
| `sentence` |  | For *Finish the sentence*: the sentence with `___` (three underscores) where the answer goes, once. |

## Pictures

- **OpenMoji symbols**: Speakagain bundles the 2,456 [OpenMoji](https://openmoji.org/library/)
  colour symbols that Saywell uses. Find one in the library, and use its code: the apple
  🍎 is `openmoji:1F34E`. Codes with several parts keep the dashes: `openmoji:1F9D1-200D-2695-FE0F`.
  Skin-tone variants aren't bundled; use the base symbol.
- **Your own pictures**: put PNG, JPG, WebP or SVG files in `images/` and refer to them as
  `images/kettle.jpg`. Keep each under 3 MB (about 600 × 600 pixels is plenty) and only use photos
  you may share. Photos of real family members are best kept in packs you don't publish.

Use clear pictures of one thing on a plain background. For people with aphasia, a familiar photo
is often easier to name than a drawing.

## Exercises

| Exercise | Needs | What the person does |
|---|---|---|
| `name` | items with `image` | Sees the picture and says the word |
| `listen` | at least 2 items with `image` (4 or more is better) | Hears the word and taps its picture |
| `read` | any items | Sees the word and says it |
| `repeat` | any items | Hears the word or phrase and says it back |
| `complete` | items with `sentence` | Sees (and can hear) the sentence and says the missing word |

Items that don't fit an exercise are left out of it: a phrase without a picture is still used for
`read` and `repeat`. In *Today's practice* each item moves from `repeat` and `listen` to `read`
and then `name` or `complete` as it gets easier.

## Writing good items

These follow common practice in aphasia therapy:

- **Start with words that matter to the person**: family, food they like, their hobbies, things
  they need to say. Functional words are practised more and remembered better.
- **Group by meaning** with `categories`: the hint "Something to eat or drink" helps find a word.
  Write hints as a short phrase in plain words.
- **Be generous with `accept`**: plurals, articles ("an apple"), regional words (*coche*, *carro*,
  *auto*), and digits for numbers (speech recognisers often write `7`). Speakagain already ignores
  case, punctuation, accents and small slips.
- **Keep sentences short and predictable** for *Finish the sentence*, with the missing word at the
  end: *"You sleep in a ___."* Automatic series work well too: *"Monday, Tuesday, ___"*. In
  languages that change word endings (Polish, German, Arabic…), write the answer in the form the
  sentence needs (`łóżku`, *in the bed*) and add the dictionary form to `accept`.
- **10 to 50 items** per pack is a good size; a session takes 5 to 20.

## Trying a pack in the app

1. Put `pack.json` (and `images/`) in a folder and zip the folder, or use a bare `pack.json` if it
   only uses OpenMoji symbols.
2. Copy the file to the phone, tablet or computer.
3. In Speakagain: **Settings › Exercise packs › Add a pack from a file**.

If something is wrong, the app lists the problems (for example "items[3]: "answer" must be a
non-empty string"). Adding a pack with the same `id` again replaces it, and keeps progress for
items whose ids didn't change.

## Adding a pack to Speakagain for everyone

1. Fork the repository and add the folder under `assets/packs/<language>/`, named as the pack's id:
   `assets/packs/es/es-cocina/pack.json`.
2. Run `python3 tool/sync_pack_assets.py` to list the new folder in `pubspec.yaml`.
3. Open a pull request. Say who wrote the pack and whether a fluent speaker (ideally a speech and
   language therapist) checked it. Machine-translated packs aren't accepted: a wrong word in a
   therapy app does more harm than a missing language.

Starter packs are under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), like the
OpenMoji symbols; please use the same licence for packs added here.

## Checking a pack

CI checks every pack in the repository, and you can run the same checks:

```bash
pip install check-jsonschema && check-jsonschema --schemafile schema/pack.schema.json assets/packs/*/*/pack.json
```

```bash
flutter test test/pack_test.dart
```

The second also checks that every OpenMoji code and picture exists, that the folder name matches
the id, and that no answer is listed twice.
