import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:speakagain/services/models/model_catalog.dart';
import 'package:speakagain/services/models/model_store.dart';
import 'package:speakagain/services/models/model_store_io.dart';

Map<String, Object?> entry(String name, List<int> bytes) => {
  'name': name,
  'bytes': bytes.length,
  'sha256': sha256.convert(bytes).toString(),
};

void main() {
  late Directory root;
  final encoder = utf8.encode('encoder');
  final decoder = utf8.encode('decoder!');
  final tokens = utf8.encode('tokens');
  final zip = Uint8List.fromList(
    ZipEncoder().encodeBytes(
      Archive()
        ..addFile(ArchiveFile.bytes('espeak-ng-data/en_dict', utf8.encode('dict')))
        ..addFile(ArchiveFile.bytes('espeak-ng-data/voices/a', utf8.encode('a'))),
    ),
  );

  final catalog = ModelCatalog.fromJson({
    'release': 'models-test',
    'baseUrl': 'https://example.org/models/',
    'recognizers': [
      {
        'id': 'whisper-tiny',
        'size': 'small',
        'name': 'Whisper tiny',
        'license': 'MIT',
        'encoder': entry('enc.onnx', encoder),
        'decoder': entry('dec.onnx', decoder),
        'tokens': entry('tokens.txt', tokens),
      },
    ],
    'voiceData': {'id': 'espeak-ng-data', 'license': 'GPL-3.0-or-later', 'archive': entry('espeak-ng-data.zip', zip)},
    'voices': <Object?>[],
  });

  setUp(() => root = Directory.systemTemp.createTempSync('speakagain-models'));
  tearDown(() => root.deleteSync(recursive: true));

  FileModelStore store(Map<String, List<int>> served, {List<String>? requests}) => FileModelStore(
    catalog,
    root: root,
    client: () => MockClient((request) async {
      requests?.add(request.url.toString());
      final body = served[request.url.pathSegments.last];
      return body == null ? http.Response('missing', 404) : http.Response.bytes(body, 200);
    }),
  );

  test('downloads, checks and remembers a model', () async {
    final requests = <String>[];
    final s = store({'enc.onnx': encoder, 'dec.onnx': decoder, 'tokens.txt': tokens}, requests: requests);
    await s.init();
    final model = catalog.recognizers.single;
    expect(s.isInstalled(model), isFalse);
    final progress = <double>[];
    await s.download(model, onProgress: progress.add);
    expect(s.isInstalled(model), isTrue);
    expect(progress.last, 1);
    expect(requests.first, 'https://example.org/models/enc.onnx');
    expect(File(s.pathOf(model, model.decoder)).readAsStringSync(), 'decoder!');

    // A new start finds it without downloading again.
    final again = store({});
    await again.init();
    expect(again.isInstalled(model), isTrue);

    await again.remove(model);
    expect(again.isInstalled(model), isFalse);
    expect(File(again.pathOf(model, model.encoder)).existsSync(), isFalse);
  });

  test('rejects a file that does not match its checksum', () async {
    final s = store({'enc.onnx': encoder, 'dec.onnx': utf8.encode('tampered'), 'tokens.txt': tokens});
    await s.init();
    final model = catalog.recognizers.single;
    await expectLater(s.download(model), throwsA(isA<ModelDownloadException>()));
    expect(s.isInstalled(model), isFalse);
    expect(File('${s.pathOf(model, model.decoder)}.part').existsSync(), isFalse);
  });

  test('reports a failed request', () async {
    final s = store({});
    await s.init();
    await expectLater(s.download(catalog.recognizers.single), throwsA(isA<ModelDownloadException>()));
  });

  test('unpacks the voice data', () async {
    final s = store({'espeak-ng-data.zip': zip});
    await s.init();
    await s.download(catalog.voiceData!);
    expect(s.isInstalled(catalog.voiceData!), isTrue);
    expect(File('${s.voiceDataDir}/en_dict').readAsStringSync(), 'dict');
    expect(File('${s.voiceDataDir}/voices/a').existsSync(), isTrue);
  });

  test('installs from files copied to the device, checking each one', () async {
    final source = Directory('${root.path}/copied')..createSync();
    File('${source.path}/enc.onnx').writeAsBytesSync(encoder);
    File('${source.path}/dec.onnx').writeAsBytesSync(decoder);
    File('${source.path}/tokens.txt').writeAsBytesSync(tokens);
    final s = store({});
    await s.init();
    final installed = await s.installFromFiles([
      for (final name in ['enc.onnx', 'dec.onnx', 'tokens.txt']) '${source.path}/$name',
    ]);
    expect(installed.map((i) => i.id), ['whisper-tiny']);
    expect(s.isInstalled(catalog.recognizers.single), isTrue);

    File('${source.path}/dec.onnx').writeAsBytesSync(utf8.encode('wrong!!!'));
    await expectLater(s.installFromFiles(['${source.path}/dec.onnx']), throwsA(isA<ModelDownloadException>()));
  });
}
