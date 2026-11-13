import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/pack.dart';

/// A pack read from a file, with the pictures it uses.
class ImportedPack {
  const ImportedPack(this.pack, this.images);

  final Pack pack;

  /// `images/<file>` -> bytes.
  final Map<String, Uint8List> images;
}

/// Reads a pack someone shared: either a `.zip` holding `pack.json` and an
/// `images/` folder, or a bare `pack.json` that only uses OpenMoji symbols.
class PackImporter {
  const PackImporter();

  static const maxFileBytes = 30 * 1024 * 1024;
  static const maxImageBytes = 3 * 1024 * 1024;
  static const maxEntries = 1000;

  ImportedPack read(Uint8List bytes) {
    if (bytes.length > maxFileBytes) {
      throw const PackFormatException(['The file is larger than 30 MB']);
    }
    final isZip = bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    if (!isZip) {
      final pack = _parse(bytes);
      if (pack.localImages.isNotEmpty) {
        throw PackFormatException([
          'This pack uses its own pictures (${pack.localImages.first}). Share it as a .zip with an images folder.',
        ]);
      }
      return ImportedPack(pack, const {});
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on Object {
      throw const PackFormatException(['The file is not a readable .zip']);
    }
    final files = archive.files.where((f) => f.isFile).toList();
    if (files.length > maxEntries) throw const PackFormatException(['The .zip has too many files']);

    // pack.json at the root, or inside a single top folder.
    final packFiles = files.where((f) => _normal(f.name).endsWith('pack.json')).toList()
      ..sort((a, b) => _normal(a.name).split('/').length.compareTo(_normal(b.name).split('/').length));
    if (packFiles.isEmpty) throw const PackFormatException(['No pack.json in the .zip']);
    final packFile = packFiles.first;
    final root = _normal(packFile.name).substring(0, _normal(packFile.name).length - 'pack.json'.length);
    final pack = _parse(packFile.content);

    final byPath = {for (final f in files) _normal(f.name): f};
    final images = <String, Uint8List>{};
    final missing = <String>[];
    for (final path in pack.localImages) {
      final file = byPath['$root$path'];
      if (file == null) {
        missing.add(path);
        continue;
      }
      final content = file.content;
      if (content.length > maxImageBytes) {
        throw PackFormatException(['$path is larger than 3 MB']);
      }
      images[path] = content;
    }
    if (missing.isNotEmpty) {
      throw PackFormatException([for (final m in missing) 'The .zip has no $m']);
    }
    return ImportedPack(pack, images);
  }

  static Pack _parse(List<int> bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const PackFormatException(['pack.json is not valid JSON']);
    }
    return Pack.fromJson(json, source: PackSource.imported);
  }

  static String _normal(String name) => name.replaceAll('\\', '/');
}
