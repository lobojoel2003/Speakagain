import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'speech_engine.dart';

SpeechEngine createSpeechEngine() => IsolateSpeechEngine();

/// Runs sherpa-onnx in one long-lived background isolate that keeps the last
/// recogniser and voice loaded.
class IsolateSpeechEngine implements SpeechEngine {
  Isolate? _isolate;
  SendPort? _send;
  ReceivePort? _receive;
  Completer<void>? _starting;
  int _nextId = 0;
  final Map<int, Completer<Object?>> _pending = {};

  @override
  bool get isSupported => true;

  Future<SendPort> _port() async {
    if (_send != null) return _send!;
    if (_starting != null) {
      await _starting!.future;
      return _send!;
    }
    final starting = _starting = Completer<void>();
    final receive = _receive = ReceivePort();
    receive.listen((message) {
      if (message is SendPort) {
        _send = message;
        starting.complete();
        return;
      }
      if (message is List && message.length == 3) {
        final completer = _pending.remove(message[0] as int);
        if (completer == null) return;
        final error = message[1] as String?;
        if (error != null) {
          completer.completeError(SpeechEngineException(error));
        } else {
          completer.complete(message[2]);
        }
      }
    });
    _isolate = await Isolate.spawn(_workerMain, receive.sendPort, debugName: 'speakagain-speech');
    await starting.future;
    return _send!;
  }

  Future<Object?> _call(String op, Map<String, Object?> args) async {
    final port = await _port();
    final id = _nextId++;
    final completer = _pending[id] = Completer<Object?>();
    port.send([id, op, args]);
    return completer.future;
  }

  @override
  Future<void> prepareRecognizer(RecognizerFiles files, String language) =>
      _call('loadAsr', _asrArgs(files, language));

  @override
  Future<String> transcribe(Float32List samples, int sampleRate,
      {required RecognizerFiles files, required String language}) async {
    final result = await _call('transcribe', {
      ..._asrArgs(files, language),
      'samples': TransferableTypedData.fromList([samples]),
      'sampleRate': sampleRate,
    });
    return (result as String?) ?? '';
  }

  @override
  Future<SynthesizedAudio> synthesize(String text, {required VoiceFiles files, double speed = 1.0}) async {
    final result = await _call('synthesize', {
      'model': files.model,
      'tokens': files.tokens,
      'dataDir': files.dataDir,
      'text': text,
      'speed': speed,
    }) as List;
    final samples = (result[0] as TransferableTypedData).materialize().asFloat32List();
    return SynthesizedAudio(samples, result[1] as int);
  }

  @override
  Future<void> dispose() async {
    for (final c in _pending.values) {
      c.completeError(const SpeechEngineException('Speech engine closed'));
    }
    _pending.clear();
    _receive?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _send = null;
    _starting = null;
  }

  static Map<String, Object?> _asrArgs(RecognizerFiles files, String language) => {
        'encoder': files.encoder,
        'decoder': files.decoder,
        'tokens': files.tokens,
        'language': language,
      };
}

// ---- Background isolate -----------------------------------------------------

void _workerMain(SendPort replies) {
  final requests = ReceivePort();
  replies.send(requests.sendPort);
  final worker = _Worker();
  requests.listen((message) {
    final list = message as List;
    final id = list[0] as int;
    try {
      final result = worker.handle(list[1] as String, (list[2] as Map).cast<String, Object?>());
      replies.send([id, null, result]);
    } on Object catch (error) {
      replies.send([id, '$error', null]);
    }
  });
}

class _Worker {
  bool _initialized = false;
  sherpa.OfflineRecognizer? _recognizer;
  String? _recognizerKey;
  sherpa.OfflineTts? _tts;
  String? _ttsKey;

  /// Silence added before and after speech: Whisper hears isolated words
  /// better with a little room around them.
  static const _padSeconds = 0.25;

  Object? handle(String op, Map<String, Object?> args) {
    if (!_initialized) {
      sherpa.initBindings();
      _initialized = true;
    }
    switch (op) {
      case 'loadAsr':
        _loadRecognizer(args);
        return null;
      case 'transcribe':
        final recognizer = _loadRecognizer(args);
        final samples = (args['samples'] as TransferableTypedData).materialize().asFloat32List();
        final rate = args['sampleRate'] as int;
        final pad = (rate * _padSeconds).round();
        final padded = Float32List(samples.length + 2 * pad)..setRange(pad, pad + samples.length, samples);
        final stream = recognizer.createStream();
        try {
          stream.acceptWaveform(samples: padded, sampleRate: rate);
          recognizer.decode(stream);
          return recognizer.getResult(stream).text.trim();
        } finally {
          stream.free();
        }
      case 'synthesize':
        final tts = _loadTts(args);
        final audio = tts.generate(
          text: args['text'] as String,
          sid: 0,
          speed: (args['speed'] as num?)?.toDouble() ?? 1.0,
        );
        return [TransferableTypedData.fromList([audio.samples]), audio.sampleRate];
      default:
        throw ArgumentError('Unknown operation $op');
    }
  }

  sherpa.OfflineRecognizer _loadRecognizer(Map<String, Object?> args) {
    final key = '${args['encoder']}|${args['decoder']}|${args['language']}';
    if (_recognizer != null && _recognizerKey == key) return _recognizer!;
    _recognizer?.free();
    _recognizer = null;
    final config = sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        whisper: sherpa.OfflineWhisperModelConfig(
          encoder: args['encoder'] as String,
          decoder: args['decoder'] as String,
          language: args['language'] as String,
          task: 'transcribe',
        ),
        tokens: args['tokens'] as String,
        modelType: 'whisper',
        numThreads: 2,
        debug: false,
      ),
    );
    _recognizer = sherpa.OfflineRecognizer(config);
    _recognizerKey = key;
    return _recognizer!;
  }

  sherpa.OfflineTts _loadTts(Map<String, Object?> args) {
    final key = '${args['model']}|${args['dataDir']}';
    if (_tts != null && _ttsKey == key) return _tts!;
    _tts?.free();
    _tts = null;
    final config = sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(
        vits: sherpa.OfflineTtsVitsModelConfig(
          model: args['model'] as String,
          tokens: args['tokens'] as String,
          dataDir: args['dataDir'] as String,
        ),
        numThreads: 2,
        debug: false,
      ),
    );
    _tts = sherpa.OfflineTts(config);
    _ttsKey = key;
    return _tts!;
  }
}
