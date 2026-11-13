import 'package:flutter/foundation.dart';

/// The kinds of practice a pack can offer.
enum ExerciseType {
  /// See a picture and say its name (confrontation naming).
  name,

  /// Hear a word and tap the matching picture (comprehension, no speech).
  listen,

  /// See a written word and say it.
  read,

  /// Hear a word or phrase and say it back (repetition).
  repeat,

  /// Say the missing word at the end of a sentence or series.
  complete;

  static ExerciseType? tryParse(String value) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    return null;
  }

  /// Whether the person answers by speaking (and so can use speech checking).
  bool get isSpoken => this != ExerciseType.listen;
}

/// Where a pack came from.
enum PackSource { bundled, imported }

/// The placeholder that marks the missing word in a `sentence`.
const String blank = '___';

/// Current version of the pack file format (`"format"` in pack.json).
const int packFormat = 1;

final RegExp _idPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
final RegExp _languagePattern = RegExp(r'^[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$');
final RegExp _openMojiPattern = RegExp(r'^openmoji:[0-9A-F]{4,6}(?:-[0-9A-F]{4,6})*$');
final RegExp _imagePathPattern = RegExp(r'^images/[A-Za-z0-9_\-./]+\.(?:png|jpg|jpeg|webp|svg)$');

/// One word, phrase or sentence to practise.
@immutable
class PackItem {
  const PackItem({
    required this.id,
    required this.answer,
    this.accept = const [],
    this.image,
    this.category,
    this.cue,
    this.sentence,
  });

  final String id;

  /// What the person says, as it is written.
  final String answer;

  /// Other ways of saying it that also count (plurals, synonyms, digits).
  final List<String> accept;

  /// `openmoji:<HEX>` for a bundled OpenMoji symbol, or `images/<file>` inside the pack.
  final String? image;

  /// Key into the pack's `categories`, used as a meaning hint.
  final String? category;

  /// A short meaning hint for this item (overrides the category hint).
  final String? cue;

  /// A sentence or series with [blank] where the answer goes, for [ExerciseType.complete].
  final String? sentence;

  List<String> get answers => [answer, ...accept];

  bool get hasImage => image != null;

  bool get hasSentence => sentence != null && sentence!.contains(blank);

  /// Whether this item can be practised as [type].
  bool supports(ExerciseType type) => switch (type) {
        ExerciseType.name || ExerciseType.listen => hasImage,
        ExerciseType.complete => hasSentence,
        ExerciseType.read || ExerciseType.repeat => true,
      };

  Map<String, Object?> toJson() => {
        'id': id,
        'answer': answer,
        if (accept.isNotEmpty) 'accept': accept,
        if (image != null) 'image': image,
        if (category != null) 'category': category,
        if (cue != null) 'cue': cue,
        if (sentence != null) 'sentence': sentence,
      };
}

/// A set of practice items in one language, loaded from a `pack.json`.
///
/// The format is documented in `docs/packs.md` and `schema/pack.schema.json`.
@immutable
class Pack {
  const Pack({
    required this.id,
    required this.version,
    required this.language,
    required this.title,
    required this.exercises,
    required this.items,
    this.description = '',
    this.author = '',
    this.license = '',
    this.categories = const {},
    this.source = PackSource.bundled,
    this.basePath = '',
  });

  final String id;
  final String version;
  final String language;
  final String title;
  final String description;
  final String author;
  final String license;
  final List<ExerciseType> exercises;
  final Map<String, String> categories;
  final List<PackItem> items;
  final PackSource source;

  /// Asset folder of a bundled pack (`assets/packs/en/en-everyday-words`), used to
  /// find its own images.
  final String basePath;

  bool offers(ExerciseType type) => exercises.contains(type) && items.any((i) => i.supports(type));

  List<PackItem> itemsFor(ExerciseType type) =>
      exercises.contains(type) ? items.where((i) => i.supports(type)).toList() : const [];

  PackItem? item(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// The meaning hint for [item]: its own cue, or its category's.
  String? cueFor(PackItem item) => item.cue ?? (item.category == null ? null : categories[item.category]);

  /// Image references used by the pack's own files (not OpenMoji symbols).
  Set<String> get localImages => {
        for (final item in items)
          if (item.image != null && !item.image!.startsWith('openmoji:')) item.image!,
      };

  Set<String> get openMojiCodes => {
        for (final item in items)
          if (item.image != null && item.image!.startsWith('openmoji:')) item.image!.substring(9),
      };

  Map<String, Object?> toJson() => {
        'format': packFormat,
        'id': id,
        'version': version,
        'language': language,
        'title': title,
        if (description.isNotEmpty) 'description': description,
        if (author.isNotEmpty) 'author': author,
        if (license.isNotEmpty) 'license': license,
        'exercises': [for (final e in exercises) e.name],
        if (categories.isNotEmpty) 'categories': categories,
        'items': [for (final item in items) item.toJson()],
      };

  Pack copyWith({PackSource? source, String? basePath}) => Pack(
        id: id,
        version: version,
        language: language,
        title: title,
        description: description,
        author: author,
        license: license,
        exercises: exercises,
        categories: categories,
        items: items,
        source: source ?? this.source,
        basePath: basePath ?? this.basePath,
      );

  /// Reads and checks a decoded `pack.json`. Throws [PackFormatException] listing
  /// every problem found, so pack authors can fix them all at once.
  factory Pack.fromJson(
    Object? json, {
    PackSource source = PackSource.bundled,
    String basePath = '',
  }) {
    final problems = <String>[];
    if (json is! Map) throw const PackFormatException(['pack.json must be a JSON object']);

    String text(Map map, String key, String where, {bool required = true}) {
      final value = map[key];
      if (value == null && !required) return '';
      if (value is! String || value.trim().isEmpty) {
        problems.add('$where: "$key" must be a non-empty string');
        return '';
      }
      return value.trim();
    }

    final format = json['format'];
    if (format != packFormat) problems.add('"format" must be $packFormat');

    final id = text(json, 'id', 'pack');
    if (id.isNotEmpty && !_idPattern.hasMatch(id)) {
      problems.add('pack: "id" must be lowercase letters, digits and dashes (got "$id")');
    }
    final version = text(json, 'version', 'pack');
    final language = text(json, 'language', 'pack');
    if (language.isNotEmpty && !_languagePattern.hasMatch(language)) {
      problems.add('pack: "language" must be a language code such as "en" or "pt-BR"');
    }
    final title = text(json, 'title', 'pack');
    final description = text(json, 'description', 'pack', required: false);
    final author = text(json, 'author', 'pack', required: false);
    final license = text(json, 'license', 'pack', required: false);

    final exercises = <ExerciseType>[];
    final rawExercises = json['exercises'];
    if (rawExercises is! List || rawExercises.isEmpty) {
      problems.add('pack: "exercises" must list at least one of ${ExerciseType.values.map((e) => e.name).join(', ')}');
    } else {
      for (final raw in rawExercises) {
        final type = raw is String ? ExerciseType.tryParse(raw) : null;
        if (type == null) {
          problems.add('pack: unknown exercise "$raw"');
        } else if (!exercises.contains(type)) {
          exercises.add(type);
        }
      }
    }

    final categories = <String, String>{};
    final rawCategories = json['categories'];
    if (rawCategories != null) {
      if (rawCategories is! Map) {
        problems.add('pack: "categories" must be an object of hint texts');
      } else {
        rawCategories.forEach((key, value) {
          if (value is String && value.trim().isNotEmpty) {
            categories['$key'] = value.trim();
          } else {
            problems.add('categories: "$key" must be a non-empty string');
          }
        });
      }
    }

    final items = <PackItem>[];
    final rawItems = json['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      problems.add('pack: "items" must be a non-empty list');
    } else {
      final seen = <String>{};
      for (var i = 0; i < rawItems.length; i++) {
        final raw = rawItems[i];
        if (raw is! Map) {
          problems.add('items[$i] must be an object');
          continue;
        }
        final where = 'items[$i]';
        final itemId = text(raw, 'id', where);
        if (itemId.isNotEmpty && !_idPattern.hasMatch(itemId)) {
          problems.add('$where: "id" must be lowercase letters, digits and dashes (got "$itemId")');
        }
        if (itemId.isNotEmpty && !seen.add(itemId)) problems.add('$where: duplicate id "$itemId"');
        final answer = text(raw, 'answer', where);
        final accept = <String>[];
        final rawAccept = raw['accept'];
        if (rawAccept != null) {
          if (rawAccept is! List || rawAccept.any((a) => a is! String || a.trim().isEmpty)) {
            problems.add('$where: "accept" must be a list of non-empty strings');
          } else {
            accept.addAll(rawAccept.cast<String>().map((a) => a.trim()));
          }
        }
        String? optional(String key) {
          final value = raw[key];
          if (value == null) return null;
          if (value is! String || value.trim().isEmpty) {
            problems.add('$where: "$key" must be a non-empty string');
            return null;
          }
          return value.trim();
        }

        final image = optional('image');
        if (image != null && !_openMojiPattern.hasMatch(image) && !_isSafeImagePath(image)) {
          problems.add('$where: "image" must be "openmoji:<HEX>" or "images/<file>.png|jpg|webp|svg" (got "$image")');
        }
        final category = optional('category');
        if (category != null && !categories.containsKey(category)) {
          problems.add('$where: category "$category" is not in "categories"');
        }
        final sentence = optional('sentence');
        if (sentence != null && blank.allMatches(sentence).length != 1) {
          problems.add('$where: "sentence" must contain "$blank" exactly once');
        }
        items.add(PackItem(
          id: itemId,
          answer: answer,
          accept: accept,
          image: image,
          category: category,
          cue: optional('cue'),
          sentence: sentence,
        ));
      }
    }

    for (final type in exercises) {
      final usable = items.where((i) => i.supports(type)).length;
      final needed = type == ExerciseType.listen ? 2 : 1;
      if (usable < needed) {
        final what = switch (type) {
          ExerciseType.name || ExerciseType.listen => 'items with an "image"',
          ExerciseType.complete => 'items with a "sentence"',
          _ => 'items',
        };
        problems.add('pack: "${type.name}" needs at least $needed $what');
      }
    }

    if (problems.isNotEmpty) throw PackFormatException(problems);
    return Pack(
      id: id,
      version: version,
      language: language,
      title: title,
      description: description,
      author: author,
      license: license,
      exercises: exercises,
      categories: categories,
      items: items,
      source: source,
      basePath: basePath,
    );
  }
}

bool _isSafeImagePath(String path) =>
    _imagePathPattern.hasMatch(path) && !path.split('/').any((part) => part == '..' || part == '.' || part.isEmpty);

/// A pack file that could not be read, with every problem found.
class PackFormatException implements Exception {
  const PackFormatException(this.problems);

  final List<String> problems;

  @override
  String toString() => 'Not a valid Speakagain pack:\n- ${problems.join('\n- ')}';
}
