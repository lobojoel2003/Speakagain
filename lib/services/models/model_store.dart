import 'package:flutter/foundation.dart';

import 'model_catalog.dart';
import 'model_store_web.dart' if (dart.library.io) 'model_store_io.dart' as impl;

/// Download progress, 0..1.
typedef ProgressCallback = void Function(double progress);

class ModelDownloadException implements Exception {
  const ModelDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Keeps downloaded models in the app's own storage, checked by SHA-256.
abstract class ModelStore {
  static ModelStore create(ModelCatalog catalog) => impl.createModelStore(catalog);

  ModelCatalog get catalog;

  /// False on the web, where models can't be used.
  bool get isSupported;

  Future<void> init();

  bool isInstalled(Downloadable item);

  /// Local path of an installed file.
  String pathOf(Downloadable item, ModelFile file);

  /// Folder of the unpacked eSpeak NG data, for natural voices.
  String get voiceDataDir;

  Future<void> download(Downloadable item, {ProgressCallback? onProgress, ValueListenable<bool>? cancel});

  /// Installs from files copied to the device (for devices that never go
  /// online). Returns the items that became installed.
  Future<List<Downloadable>> installFromFiles(List<String> paths);

  Future<void> remove(Downloadable item);
}
