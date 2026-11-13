import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'speech_engine_web.dart' if (dart.library.io) 'speech_engine_io.dart' as impl;

/// Files of an on-device Whisper model.
@immutable
class RecognizerFiles {
  const RecognizerFiles({required this.encoder, required this.decoder, required this.tokens});

  final String encoder;
  final String decoder;
  final String tokens;

  @override
  bool operator ==(Object other) =>
      other is RecognizerFiles && other.encoder == encoder && other.decoder == decoder && other.tokens == tokens;

  @override
  int get hashCode => Object.hash(encoder, decoder, tokens);
}

/// Files of a natural (Piper) voice.
@immutable
class VoiceFiles {
  const VoiceFiles({required this.model, required this.tokens, required this.dataDir});

  final String model;
  final String tokens;

  /// The shared eSpeak NG data folder that turns text into sounds.
  final String dataDir;

  @override
  bool operator ==(Object other) =>
      other is VoiceFiles && other.model == model && other.tokens == tokens && other.dataDir == dataDir;

  @override
  int get hashCode => Object.hash(model, tokens, dataDir);
}

class SynthesizedAudio {
  const SynthesizedAudio(this.samples, this.sampleRate);

  final Float32List samples;
  final int sampleRate;
}

class SpeechEngineException implements Exception {
  const SpeechEngineException(this.message);

  final String message;

  @override
  String toString() => 'SpeechEngineException: $message';
}

/// On-device speech recognition and synthesis with sherpa-onnx, the same
/// engine Saywell uses for its voices. It runs in a background isolate so the
/// screen stays smooth while a model loads or a word is checked.
abstract class SpeechEngine {
  static SpeechEngine create() => impl.createSpeechEngine();

  /// False where the native engine can't run (the web build).
  bool get isSupported;

  Future<void> prepareRecognizer(RecognizerFiles files, String language);

  /// What was said, as text. Loads the model first if needed.
  Future<String> transcribe(Float32List samples, int sampleRate, {required RecognizerFiles files, required String language});

  Future<SynthesizedAudio> synthesize(String text, {required VoiceFiles files, double speed = 1.0});

  Future<void> dispose();
}
