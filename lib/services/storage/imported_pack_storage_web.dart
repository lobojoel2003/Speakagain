import 'dart:convert';
import 'dart:typed_data';

import '../local_store.dart';
import 'imported_pack_storage.dart';

ImportedPackStorage createStorage(LocalStore store) => BlobImportedPackStorage(store);

/// Saves imported packs in browser storage, pictures embedded as base64.
class BlobImportedPackStorage implements ImportedPackStorage {
  BlobImportedPackStorage(this._store);

  final LocalStore _store;
  final Map<String, Map<String, Uint8List>> _images = {};

  @override
  Future<List<StoredPack>> loadAll() async {
    final result = <StoredPack>[];
    for (final entry in _store.loadImportedPackBlobs().entries) {
      try {
        final blob = jsonDecode(entry.value) as Map<String, Object?>;
        final images = (blob['images'] as Map?)?.cast<String, String>() ?? const {};
        _images[entry.key] = {for (final i in images.entries) i.key: base64Decode(i.value)};
        result.add(StoredPack(entry.key, blob['pack']));
      } on Object {
        // Skip a damaged entry.
      }
    }
    return result;
  }

  @override
  Future<void> save(String id, Map<String, Object?> packJson, Map<String, Uint8List> images) async {
    _images[id] = images;
    await _store.saveImportedPackBlob(
      id,
      jsonEncode({
        'pack': packJson,
        'images': {for (final i in images.entries) i.key: base64Encode(i.value)},
      }),
    );
  }

  @override
  Future<void> remove(String id) async {
    _images.remove(id);
    await _store.removeImportedPackBlob(id);
  }

  @override
  Future<Uint8List?> image(String packId, String path) async => _images[packId]?[path];
}
