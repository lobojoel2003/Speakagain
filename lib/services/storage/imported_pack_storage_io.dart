import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../local_store.dart';
import 'imported_pack_storage.dart';

ImportedPackStorage createStorage(LocalStore store) => FileImportedPackStorage();

/// Saves each imported pack in `<app support>/packs/<id>/`.
class FileImportedPackStorage implements ImportedPackStorage {
  FileImportedPackStorage({Directory? root}) : _root = root; // ignore: prefer_initializing_formals

  Directory? _root;

  Future<Directory> _packsDir() async {
    _root ??= Directory('${(await getApplicationSupportDirectory()).path}/packs');
    return _root!;
  }

  @override
  Future<List<StoredPack>> loadAll() async {
    final dir = await _packsDir();
    if (!await dir.exists()) return const [];
    final result = <StoredPack>[];
    await for (final entry in dir.list()) {
      if (entry is! Directory) continue;
      final file = File('${entry.path}/pack.json');
      if (!await file.exists()) continue;
      try {
        result.add(
          StoredPack(entry.uri.pathSegments.where((s) => s.isNotEmpty).last, jsonDecode(await file.readAsString())),
        );
      } on FormatException {
        // A damaged pack is skipped; the others still load.
      }
    }
    return result;
  }

  @override
  Future<void> save(String id, Map<String, Object?> packJson, Map<String, Uint8List> images) async {
    final dir = Directory('${(await _packsDir()).path}/$id');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    for (final entry in images.entries) {
      final file = File('${dir.path}/${entry.key}');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.value, flush: true);
    }
    await File('${dir.path}/pack.json').writeAsString(jsonEncode(packJson), flush: true);
  }

  @override
  Future<void> remove(String id) async {
    final dir = Directory('${(await _packsDir()).path}/$id');
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  @override
  Future<Uint8List?> image(String packId, String path) async {
    final file = File('${(await _packsDir()).path}/$packId/$path');
    return await file.exists() ? file.readAsBytes() : null;
  }
}
