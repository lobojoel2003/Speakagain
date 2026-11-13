import 'dart:typed_data';

import 'speech_engine.dart';

SpeechEngine createSpeechEngine() => UnsupportedSpeechEngine();

/// The web build has no on-device models; answers are confirmed by the person.
class UnsupportedSpeechEngine implements SpeechEngine {
  @override
  bool get isSupported => false;

  @override
  Future<void> prepareRecognizer(RecognizerFiles files, String language) async =>
      throw const SpeechEngineException('Speech checking is not available here');

  @override
  Future<String> transcribe(
    Float32List samples,
    int sampleRate, {
    required RecognizerFiles files,
    required String language,
  }) async => throw const SpeechEngineException('Speech checking is not available here');

  @override
  Future<SynthesizedAudio> synthesize(String text, {required VoiceFiles files, double speed = 1.0}) async =>
      throw const SpeechEngineException('Natural voices are not available here');

  @override
  Future<void> dispose() async {}
}
