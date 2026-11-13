import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// What the microphone picked up for one answer.
class Recording {
  const Recording(this.samples, this.sampleRate, {required this.heardSpeech});

  /// The speech, trimmed of the silence around it.
  final Float32List samples;
  final int sampleRate;

  /// False when nothing louder than the room was heard.
  final bool heardSpeech;

  Duration get duration => Duration(microseconds: samples.length * 1000000 ~/ sampleRate);
}

/// Finds where speech starts and stops in a stream of 16 kHz samples, so the
/// person only taps once: recording ends by itself after a pause.
///
/// Speech after a stroke can be slow, with pauses inside a word, so the pause
/// that ends an answer is long (1.4 s by default) and the wait for the first
/// sound is generous.
class SpeechEndpointer {
  SpeechEndpointer({
    this.sampleRate = 16000,
    this.endSilence = const Duration(milliseconds: 1400),
    this.maxWait = const Duration(seconds: 7),
    this.maxLength = const Duration(seconds: 10),
  });

  final int sampleRate;
  final Duration endSilence;
  final Duration maxWait;
  final Duration maxLength;

  static const _frameMs = 20;
  int get _frame => sampleRate * _frameMs ~/ 1000;

  final List<double> _samples = [];
  double _noiseFloor = 0.004;
  int _loudFrames = 0;
  int? _speechStart;
  int _lastSpeech = 0;
  int _framesSeen = 0;
  double level = 0;

  bool get heardSpeech => _speechStart != null;

  int get _ms => _framesSeen * _frameMs;

  int _processed = 0;

  /// Adds samples; returns true when the answer is over.
  bool add(Float32List chunk) {
    _samples.addAll(chunk);
    var finished = false;
    while (_processed + _frame <= _samples.length) {
      var sum = 0.0;
      for (var i = _processed; i < _processed + _frame; i++) {
        sum += _samples[i] * _samples[i];
      }
      _processed += _frame;
      final rms = math.sqrt(sum / _frame);
      _framesSeen++;
      level = math.min(1.0, rms * 12);
      final threshold = math.max(0.012, _noiseFloor * 3);
      if (_speechStart == null) {
        // Follow the room's noise until speech starts.
        _noiseFloor = rms < _noiseFloor ? _noiseFloor * 0.9 + rms * 0.1 : _noiseFloor * 0.995 + rms * 0.005;
        _loudFrames = rms > threshold ? _loudFrames + 1 : 0;
        if (_loudFrames >= 3) {
          _speechStart = math.max(0, _framesSeen - 3);
          _lastSpeech = _framesSeen;
        }
      } else if (rms > threshold * 0.7) {
        _lastSpeech = _framesSeen;
      }
      if (_speechStart == null && _ms >= maxWait.inMilliseconds) finished = true;
      if (_speechStart != null && (_framesSeen - _lastSpeech) * _frameMs >= endSilence.inMilliseconds) finished = true;
      if (_ms >= maxLength.inMilliseconds) finished = true;
    }
    return finished;
  }

  Recording finish() {
    if (_speechStart == null) return Recording(Float32List(0), sampleRate, heardSpeech: false);
    final before = sampleRate * 300 ~/ 1000;
    final after = sampleRate * 350 ~/ 1000;
    final from = math.max(0, _speechStart! * _frame - before);
    final to = math.min(_samples.length, _lastSpeech * _frame + after);
    return Recording(Float32List.fromList(_samples.sublist(from, math.max(from, to))), sampleRate, heardSpeech: true);
  }
}

/// Records one spoken answer from the microphone.
class VoiceRecorder {
  VoiceRecorder();

  static const sampleRate = 16000;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _subscription;
  Completer<Recording>? _current;
  SpeechEndpointer? _endpointer;

  /// Loudness while listening, 0..1, for the microphone animation.
  final ValueNotifier<double> level = ValueNotifier(0);

  AudioRecorder get _rec => _recorder ??= AudioRecorder();

  Future<bool> hasPermission({bool request = true}) async {
    try {
      return await _rec.hasPermission(request: request);
    } on Object {
      return false;
    }
  }

  bool get isRecording => _current != null && !_current!.isCompleted;

  /// Starts listening; completes when the person stops talking or [stop] is called.
  Future<Recording> record() async {
    if (isRecording) await stop();
    final completer = _current = Completer<Recording>();
    final endpointer = _endpointer = SpeechEndpointer(sampleRate: sampleRate);
    final stream = await _rec.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        autoGain: true,
        noiseSuppress: true,
      ),
    );
    var carry = <int>[];
    _subscription = stream.listen(
      (bytes) {
        final all = carry.isEmpty ? bytes : Uint8List.fromList([...carry, ...bytes]);
        final usable = all.length - all.length % 2;
        carry = all.sublist(usable);
        final view = ByteData.sublistView(all, 0, usable);
        final samples = Float32List(usable ~/ 2);
        for (var i = 0; i < samples.length; i++) {
          samples[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
        }
        final done = endpointer.add(samples);
        level.value = endpointer.level;
        if (done) unawaited(stop());
      },
      onError: (Object error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
    );
    return completer.future;
  }

  /// Stops listening and finishes the current answer.
  Future<void> stop() async {
    final completer = _current;
    final endpointer = _endpointer;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _recorder?.stop();
    } on Object {
      // Already stopped.
    }
    level.value = 0;
    if (completer != null && !completer.isCompleted && endpointer != null) {
      completer.complete(endpointer.finish());
    }
  }

  /// Stops without an answer (leaving the screen).
  Future<void> cancel() async {
    final completer = _current;
    _current = null;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _recorder?.cancel();
    } on Object {
      // Nothing to cancel.
    }
    level.value = 0;
    if (completer != null && !completer.isCompleted) {
      completer.complete(Recording(Float32List(0), sampleRate, heardSpeech: false));
    }
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder?.dispose();
    _recorder = null;
  }
}
