import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/pack.dart';
import 'pack_importer.dart';
import 'storage/imported_pack_storage.dart';

/// Finds every pack: the starter packs bundled in `assets/packs/<language>/`
/// and the ones the person added from files.
class PackRepository {
  PackRepository({required this.storage, AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final ImportedPackStorage storage;
  final AssetBundle _bundle;

  final List<Pack> _bundled = [];
  final List<Pack> _imported = [];
  final Map<String, Uint8List> _imageCache = {};

  /// Problems found in bundled packs (shown in debug builds and caught by tests).
  final List<String> loadProblems = [];

  List<Pack> get all => [..._bundled, ..._imported];

  List<Pack> forLanguage(String language) =>
      all.where((p) => p.language == language || p.language.split('-').first == language).toList();

  Future<void> load() async {
    _bundled.clear();
    _imported.clear();
    loadProblems.clear();

    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final packFiles = manifest.listAssets().where((a) => a.startsWith('assets/packs/') && a.endsWith('/pack.json')).toList()
      ..sort();
    for (final path in packFiles) {
      try {
        final json = jsonDecode(await _bundle.loadString(path));
        _bundled.add(Pack.fromJson(json, basePath: path.substring(0, path.length - '/pack.json'.length)));
      } on PackFormatException catch (e) {
        loadProblems.add('$path: ${e.problems.join('; ')}');
      } on FormatException catch (e) {
        loadProblems.add('$path: ${e.message}');
      }
    }
    if (loadProblems.isNotEmpty) debugPrint('Pack problems:\n${loadProblems.join('\n')}');

    for (final stored in await storage.loadAll()) {
      try {
        _imported.add(Pack.fromJson(stored.json, source: PackSource.imported));
      } on PackFormatException {
        // Imported packs were checked when added; skip one that no longer reads.
      }
    }
  }

  /// Adds (or replaces) a pack from a file. Returns the added pack.
  Future<Pack> import(Uint8List bytes) async {
    final imported = const PackImporter().read(bytes);
    final pack = imported.pack;
    if (_bundled.any((p) => p.id == pack.id)) {
      throw PackFormatException(['A starter pack already uses the id "${pack.id}". Give the pack another id.']);
    }
    await storage.save(pack.id, pack.toJson(), imported.images);
    _imported.removeWhere((p) => p.id == pack.id);
    _imageCache.removeWhere((key, _) => key.startsWith('${pack.id}|'));
    _imported.add(pack);
    return pack;
  }

  Future<void> remove(Pack pack) async {
    if (pack.source != PackSource.imported) return;
    await storage.remove(pack.id);
    _imported.removeWhere((p) => p.id == pack.id);
    _imageCache.removeWhere((key, _) => key.startsWith('${pack.id}|'));
  }

  /// The picture for an item: an OpenMoji symbol, or a file from the pack.
  Future<Uint8List?> image(Pack pack, String ref) async {
    final key = '${pack.id}|$ref';
    final cached = _imageCache[key];
    if (cached != null) return cached;
    Uint8List? bytes;
    try {
      if (ref.startsWith('openmoji:')) {
        bytes = (await _bundle.load(openMojiAsset(ref))).buffer.asUint8List();
      } else if (pack.source == PackSource.bundled) {
        bytes = (await _bundle.load('${pack.basePath}/$ref')).buffer.asUint8List();
      } else {
        bytes = await storage.image(pack.id, ref);
      }
    } on FlutterError {
      bytes = null;
    }
    if (bytes != null) _imageCache[key] = bytes;
    return bytes;
  }

  static String openMojiAsset(String ref) => 'assets/symbols/openmoji/${ref.substring('openmoji:'.length)}.svg';
}
