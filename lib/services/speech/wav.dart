import 'dart:math' as math;
import 'dart:typed_data';

/// A 16-bit mono WAV file for [samples] in -1..1.
Uint8List encodeWav(Float32List samples, int sampleRate) {
  final data = ByteData(44 + samples.length * 2);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      data.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(44 + i * 2, v, Endian.little);
  }
  return data.buffer.asUint8List();
}

/// Scales quiet recordings up (to about -3 dBFS peak) so playback is easy to hear.
Float32List normalizeLoudness(Float32List samples) {
  var peak = 0.0;
  for (final s in samples) {
    peak = math.max(peak, s.abs());
  }
  if (peak < 1e-4 || peak > 0.7) return samples;
  final gain = math.min(0.7 / peak, 8.0);
  return Float32List.fromList([for (final s in samples) s * gain]);
}
