import 'package:flutter/foundation.dart';

import 'model_catalog.dart';
import 'model_store.dart';

ModelStore createModelStore(ModelCatalog catalog) => UnsupportedModelStore(catalog);

class UnsupportedModelStore implements ModelStore {
  UnsupportedModelStore(this.catalog);

  @override
  final ModelCatalog catalog;

  @override
  bool get isSupported => false;

  @override
  Future<void> init() async {}

  @override
  bool isInstalled(Downloadable item) => false;

  @override
  String pathOf(Downloadable item, ModelFile file) => '';

  @override
  String get voiceDataDir => '';

  @override
  Future<void> download(Downloadable item, {ProgressCallback? onProgress, ValueListenable<bool>? cancel}) =>
      Future.error(const ModelDownloadException('Not available on the web'));

  @override
  Future<List<Downloadable>> installFromFiles(List<String> paths) async => const [];

  @override
  Future<void> remove(Downloadable item) async {}
}
