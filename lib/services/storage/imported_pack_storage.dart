import 'dart:typed_data';

import '../local_store.dart';
import 'imported_pack_storage_web.dart' if (dart.library.io) 'imported_pack_storage_io.dart' as impl;

/// A pack someone added from a file, as saved on the device.
class StoredPack {
  const StoredPack(this.id, this.json);

  final String id;
  final Object? json;
}

/// Where imported packs live: app files on Android and iOS, browser storage on the web.
abstract class ImportedPackStorage {
  static ImportedPackStorage create(LocalStore store) => impl.createStorage(store);

  Future<List<StoredPack>> loadAll();

  Future<void> save(String id, Map<String, Object?> packJson, Map<String, Uint8List> images);

  Future<void> remove(String id);

  Future<Uint8List?> image(String packId, String path);
}
