import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/languages.dart';
import '../../models/settings.dart';
import '../models/model_catalog.dart';
import '../models/model_store.dart';
import 'recorder.dart';
import 'speech_engine.dart';
import 'wav.dart';

/// Everything the practice screens need from audio: speaking words, listening
/// to answers and turning them into text. Tests use a fake.
abstract class SpeechServices extends ChangeNotifier {
  /// Applies the person's language, voice and speed.
  void configure(AppSettings settings);

  /// Says [text] in the current language; completes when it has been said.
  Future<void> speak(String text);

  Future<void> stopSpeaking();

  /// A soft chime for a correct answer.
  Future<void> playChime();

  /// Plays back what the person said, so they can hear themselves.
  Future<void> playRecording(Recording recording);

  /// Whether spoken answers can be checked right now (model installed, the
  /// person turned it on, and the platform supports it).
  bool get canCheckSpeech;

  /// Whether the device can record at all (false on the web build).
  bool get canRecord;

  /// Loudness while listening, 0..1.
  ValueListenable<double> get inputLevel;

  /// Asks for the microphone if needed. False if the person said no.
  Future<bool> ensureMicrophone();

  /// Records one answer; completes after a pause or [stopListening].
  Future<Recording> listen();

  Future<void> stopListening();

  Future<void> cancelListening();

  /// What the on-device recogniser heard.
  Future<String> transcribe(Recording recording);

  /// Loads the speech model in the background so the first check is quick.
  Future<void> warmUp();
}

/// The real implementation: the phone's text-to-speech or a downloaded
/// natural voice, the microphone, and Whisper through sherpa-onnx.
class DeviceSpeechServices extends SpeechServices {
  DeviceSpeechServices({required this.engine, required this.models, FlutterTts? tts, AudioPlayer? player})
    : _tts = tts ?? FlutterTts(),
      _player = player ?? AudioPlayer(),
      _chimePlayer = AudioPlayer();

  final SpeechEngine engine;
  final ModelStore models;
  final FlutterTts _tts;
  final AudioPlayer _player;
  final AudioPlayer _chimePlayer;
  final VoiceRecorder _recorder = VoiceRecorder();

  AppSettings _settings = const AppSettings();
  bool _ttsReady = false;
  String? _ttsLanguage;
  double? _ttsRate;

  String get _language => _settings.language ?? 'en';

  @override
  void configure(AppSettings settings) {
    _settings = settings;
    notifyListeners();
  }

  Future<void> _prepareTts() async {
    if (!_ttsReady) {
      _ttsReady = true;
      try {
        await _tts.awaitSpeakCompletion(true);
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          await _tts.setSharedInstance(true);
          await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playAndRecord, [
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          ], IosTextToSpeechAudioMode.defaultMode);
        }
      } on Object catch (e) {
        debugPrint('Text-to-speech setup: $e');
      }
    }
    final locale = languageFor(_language).ttsLocale;
    if (_ttsLanguage != locale) {
      _ttsLanguage = locale;
      try {
        await _tts.setLanguage(locale);
      } on Object catch (e) {
        debugPrint('Text-to-speech language $locale: $e');
      }
    }
    final rate = _systemRate(_settings.speechSpeed);
    if (_ttsRate != rate) {
      _ttsRate = rate;
      await _tts.setSpeechRate(rate);
    }
  }

  static double _systemRate(SpeechSpeed speed) {
    // flutter_tts rates differ: 0.5 is a normal pace on Android and iOS, 1.0 on the web.
    final normal = kIsWeb ? 1.0 : 0.5;
    return speed == SpeechSpeed.slower ? normal * (kIsWeb ? 0.8 : 0.8) : normal;
  }

  VoiceModel? get _naturalVoice {
    if (!models.isSupported || _settings.voiceId == systemVoiceId) return null;
    final voice = models.catalog.voice(_settings.voiceId);
    final data = models.catalog.voiceData;
    if (voice == null || data == null || voice.language != _language) return null;
    if (!models.isInstalled(voice) || !models.isInstalled(data)) return null;
    return voice;
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await stopSpeaking();
    final voice = _naturalVoice;
    if (voice != null) {
      try {
        final audio = await engine.synthesize(
          text,
          files: VoiceFiles(
            model: models.pathOf(voice, voice.model),
            tokens: models.pathOf(voice, voice.tokens),
            dataDir: models.voiceDataDir,
          ),
          speed: _settings.speechSpeed == SpeechSpeed.slower ? 0.8 : 1.0,
        );
        await _playWav(encodeWav(audio.samples, audio.sampleRate));
        return;
      } on Object catch (e) {
        // Fall back to the phone's voice so pressing "Hear it" always makes a sound.
        debugPrint('Natural voice failed, using the phone voice: $e');
      }
    }
    await _prepareTts();
    try {
      await _tts.speak(text);
    } on Object catch (e) {
      debugPrint('Text-to-speech failed: $e');
    }
  }

  Future<void> _playWav(Uint8List wav) async {
    final done = _player.onPlayerComplete.first;
    await _player.play(BytesSource(wav, mimeType: 'audio/wav'));
    await done.timeout(const Duration(seconds: 30), onTimeout: () {});
  }

  @override
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } on Object {
      // Not speaking.
    }
    if (_player.state == PlayerState.playing) await _player.stop();
  }

  @override
  Future<void> playChime() async {
    if (!_settings.sounds) return;
    try {
      await _chimePlayer.play(AssetSource('sounds/chime.wav'), volume: 0.6);
    } on Object catch (e) {
      debugPrint('Chime: $e');
    }
  }

  @override
  Future<void> playRecording(Recording recording) async {
    if (recording.samples.isEmpty) return;
    await stopSpeaking();
    await _playWav(encodeWav(normalizeLoudness(recording.samples), recording.sampleRate));
  }

  RecognizerModel get _recognizerModel => models.catalog.recognizer(_settings.recognizer);

  /// The chosen model if installed, otherwise any installed one.
  RecognizerModel? get _installedRecognizer {
    if (!models.isSupported) return null;
    if (models.isInstalled(_recognizerModel)) return _recognizerModel;
    for (final r in models.catalog.recognizers) {
      if (models.isInstalled(r)) return r;
    }
    return null;
  }

  RecognizerFiles _filesFor(RecognizerModel model) => RecognizerFiles(
    encoder: models.pathOf(model, model.encoder),
    decoder: models.pathOf(model, model.decoder),
    tokens: models.pathOf(model, model.tokens),
  );

  @override
  bool get canCheckSpeech => _settings.speechChecking && engine.isSupported && _installedRecognizer != null;

  @override
  bool get canRecord => !kIsWeb;

  @override
  ValueListenable<double> get inputLevel => _recorder.level;

  @override
  Future<bool> ensureMicrophone() => _recorder.hasPermission();

  @override
  Future<Recording> listen() async {
    await stopSpeaking();
    return _recorder.record();
  }

  @override
  Future<void> stopListening() => _recorder.stop();

  @override
  Future<void> cancelListening() => _recorder.cancel();

  @override
  Future<String> transcribe(Recording recording) async {
    final model = _installedRecognizer;
    if (model == null || !recording.heardSpeech) return '';
    return engine.transcribe(recording.samples, recording.sampleRate, files: _filesFor(model), language: _language);
  }

  @override
  Future<void> warmUp() async {
    final model = _installedRecognizer;
    if (model == null || !_settings.speechChecking) return;
    try {
      await engine.prepareRecognizer(_filesFor(model), _language);
    } on Object catch (e) {
      debugPrint('Speech model failed to load: $e');
    }
  }

  @override
  void dispose() {
    unawaited(_recorder.dispose());
    unawaited(_player.dispose());
    unawaited(_chimePlayer.dispose());
    unawaited(engine.dispose());
    super.dispose();
  }
}
