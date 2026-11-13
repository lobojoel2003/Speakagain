import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'model_catalog.dart';
import 'model_store.dart';

ModelStore createModelStore(ModelCatalog catalog) => FileModelStore(catalog);

/// Stores models in `<app support>/models/<id>/`. A file only counts as
/// installed once its SHA-256 matched the catalog; a `.ok` marker records that,
/// so the check runs once per download instead of on every start.
class FileModelStore implements ModelStore {
  FileModelStore(this.catalog, {Directory? root, http.Client Function()? client})
      : _root = root,
        _client = client ?? http.Client.new;

  @override
  final ModelCatalog catalog;
  Directory? _root;
  final http.Client Function() _client;
  final Set<String> _installed = {};

  @override
  bool get isSupported => true;

  Directory get _dir => _root!;

  @override
  Future<void> init() async {
    _root ??= Directory('${(await getApplicationSupportDirectory()).path}/models');
    await _dir.create(recursive: true);
    _installed.clear();
    for (final item in _all) {
      if (await _checkMarkers(item)) _installed.add(item.id);
    }
  }

  Iterable<Downloadable> get _all => [
        ...catalog.recognizers,
        ...catalog.voices,
        if (catalog.voiceData != null) catalog.voiceData!,
      ];

  Future<bool> _checkMarkers(Downloadable item) async {
    for (final file in item.files) {
      final path = pathOf(item, file);
      final data = File(path);
      final marker = File('$path.ok');
      if (!await data.exists() || !await marker.exists()) return false;
      if (await data.length() != file.bytes || (await marker.readAsString()).trim() != file.sha256) return false;
    }
    if (item is VoiceData && !await Directory(voiceDataDir).exists()) return false;
    return true;
  }

  @override
  bool isInstalled(Downloadable item) => _installed.contains(item.id);

  @override
  String pathOf(Downloadable item, ModelFile file) => '${_dir.path}/${item.id}/${file.name}';

  @override
  String get voiceDataDir => '${_dir.path}/espeak-ng-data/espeak-ng-data';

  @override
  Future<void> download(Downloadable item, {ProgressCallback? onProgress, ValueListenable<bool>? cancel}) async {
    final folder = Directory('${_dir.path}/${item.id}');
    await folder.create(recursive: true);
    final total = item.totalBytes;
    var done = 0;
    final client = _client();
    try {
      for (final file in item.files) {
        final target = File(pathOf(item, file));
        final marker = File('${target.path}.ok');
        if (await target.exists() &&
            await marker.exists() &&
            (await marker.readAsString()).trim() == file.sha256 &&
            await target.length() == file.bytes) {
          done += file.bytes;
          onProgress?.call(done / total);
          continue;
        }
        final part = File('${target.path}.part');
        final response = await client.send(http.Request('GET', catalog.urlFor(file)));
        if (response.statusCode != 200) {
          throw ModelDownloadException('Download failed (${response.statusCode}) for ${file.name}');
        }
        final sink = part.openWrite();
        final digest = _DigestSink();
        final hasher = sha256.startChunkedConversion(digest);
        var received = 0;
        try {
          await for (final chunk in response.stream) {
            if (cancel?.value ?? false) throw const ModelDownloadException('Cancelled');
            sink.add(chunk);
            hasher.add(chunk);
            received += chunk.length;
            onProgress?.call((done + received) / total);
          }
        } finally {
          await sink.close();
        }
        hasher.close();
        if (received != file.bytes || digest.value.toString() != file.sha256) {
          await part.delete();
          throw ModelDownloadException('${file.name} did not download completely. Please try again.');
        }
        await part.rename(target.path);
        await marker.writeAsString(file.sha256, flush: true);
        done += file.bytes;
      }
    } finally {
      client.close();
    }
    if (item is VoiceData) await _unpackVoiceData(item);
    _installed.add(item.id);
    onProgress?.call(1);
  }

  Future<void> _unpackVoiceData(VoiceData data) async {
    final out = Directory('${_dir.path}/espeak-ng-data');
    final unpacked = Directory(voiceDataDir);
    if (await unpacked.exists()) await unpacked.delete(recursive: true);
    await extractFileToDisk(pathOf(data, data.archive), out.path);
    if (!await unpacked.exists()) {
      throw const ModelDownloadException('The voice data could not be unpacked');
    }
  }

  @override
  Future<List<Downloadable>> installFromFiles(List<String> paths) async {
    final byName = <String, String>{for (final p in paths) p.split(Platform.pathSeparator).last: p};
    final installed = <Downloadable>[];
    for (final item in _all) {
      final matches = item.files.where((f) => byName.containsKey(f.name)).toList();
      if (matches.isEmpty) continue;
      for (final file in matches) {
        final source = File(byName[file.name]!);
        if (await source.length() != file.bytes) {
          throw ModelDownloadException('${file.name} is not the expected file (size differs).');
        }
        final actual = await sha256.bind(source.openRead()).first;
        if (actual.toString() != file.sha256) {
          throw ModelDownloadException('${file.name} is not the expected file (checksum differs).');
        }
        final target = File(pathOf(item, file));
        await target.parent.create(recursive: true);
        await source.copy(target.path);
        await File('${target.path}.ok').writeAsString(file.sha256, flush: true);
      }
      if (item is VoiceData && matches.isNotEmpty) await _unpackVoiceData(item);
      if (await _checkMarkers(item)) {
        _installed.add(item.id);
        installed.add(item);
      }
    }
    return installed;
  }

  @override
  Future<void> remove(Downloadable item) async {
    _installed.remove(item.id);
    final folder = Directory('${_dir.path}/${item.id}');
    if (await folder.exists()) await folder.delete(recursive: true);
    if (item is VoiceData) {
      final unpacked = Directory('${_dir.path}/espeak-ng-data');
      if (await unpacked.exists()) await unpacked.delete(recursive: true);
    }
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
