import 'package:flutter/foundation.dart';

import '../core/answer_matcher.dart';

enum TextSizeChoice {
  large(1.0),
  larger(1.18),
  largest(1.36);

  const TextSizeChoice(this.scale);
  final double scale;
}

enum ThemeChoice { system, light, dark, contrast }

enum SpeechSpeed { slower, normal }

/// Which on-device speech model checks spoken answers.
enum RecognizerSize { standard, small }

/// The voice id for the phone's own text-to-speech engine.
const String systemVoiceId = 'system';

@immutable
class AppSettings {
  const AppSettings({
    this.language,
    this.onboarded = false,
    this.voiceId = systemVoiceId,
    this.speechSpeed = SpeechSpeed.slower,
    this.speechChecking = true,
    this.recognizer = RecognizerSize.standard,
    this.strictness = Strictness.gentle,
    this.sessionLength = 10,
    this.pictureChoices = 3,
    this.autoHints = true,
    this.speakInstructions = true,
    this.sounds = true,
    this.textSize = TextSizeChoice.large,
    this.theme = ThemeChoice.system,
  });

  /// Language code; null until chosen on first start.
  final String? language;
  final bool onboarded;

  /// [systemVoiceId] or the id of a downloaded natural voice.
  final String voiceId;
  final SpeechSpeed speechSpeed;
  final bool speechChecking;
  final RecognizerSize recognizer;
  final Strictness strictness;
  final int sessionLength;
  final int pictureChoices;
  final bool autoHints;
  final bool speakInstructions;
  final bool sounds;
  final TextSizeChoice textSize;
  final ThemeChoice theme;

  static const sessionLengths = [5, 10, 15, 20];
  static const pictureChoiceCounts = [2, 3, 4];

  AppSettings copyWith({
    String? language,
    bool? onboarded,
    String? voiceId,
    SpeechSpeed? speechSpeed,
    bool? speechChecking,
    RecognizerSize? recognizer,
    Strictness? strictness,
    int? sessionLength,
    int? pictureChoices,
    bool? autoHints,
    bool? speakInstructions,
    bool? sounds,
    TextSizeChoice? textSize,
    ThemeChoice? theme,
  }) =>
      AppSettings(
        language: language ?? this.language,
        onboarded: onboarded ?? this.onboarded,
        voiceId: voiceId ?? this.voiceId,
        speechSpeed: speechSpeed ?? this.speechSpeed,
        speechChecking: speechChecking ?? this.speechChecking,
        recognizer: recognizer ?? this.recognizer,
        strictness: strictness ?? this.strictness,
        sessionLength: sessionLength ?? this.sessionLength,
        pictureChoices: pictureChoices ?? this.pictureChoices,
        autoHints: autoHints ?? this.autoHints,
        speakInstructions: speakInstructions ?? this.speakInstructions,
        sounds: sounds ?? this.sounds,
        textSize: textSize ?? this.textSize,
        theme: theme ?? this.theme,
      );

  Map<String, Object?> toJson() => {
        if (language != null) 'language': language,
        'onboarded': onboarded,
        'voiceId': voiceId,
        'speechSpeed': speechSpeed.name,
        'speechChecking': speechChecking,
        'recognizer': recognizer.name,
        'strictness': strictness.name,
        'sessionLength': sessionLength,
        'pictureChoices': pictureChoices,
        'autoHints': autoHints,
        'speakInstructions': speakInstructions,
        'sounds': sounds,
        'textSize': textSize.name,
        'theme': theme.name,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    const defaults = AppSettings();
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return fallback;
    }

    int choose(Object? value, List<int> allowed, int fallback) =>
        value is int && allowed.contains(value) ? value : fallback;

    return AppSettings(
      language: json['language'] as String?,
      onboarded: json['onboarded'] as bool? ?? false,
      voiceId: json['voiceId'] as String? ?? systemVoiceId,
      speechSpeed: pick(SpeechSpeed.values, json['speechSpeed'], defaults.speechSpeed),
      speechChecking: json['speechChecking'] as bool? ?? defaults.speechChecking,
      recognizer: pick(RecognizerSize.values, json['recognizer'], defaults.recognizer),
      strictness: pick(Strictness.values, json['strictness'], defaults.strictness),
      sessionLength: choose(json['sessionLength'], sessionLengths, defaults.sessionLength),
      pictureChoices: choose(json['pictureChoices'], pictureChoiceCounts, defaults.pictureChoices),
      autoHints: json['autoHints'] as bool? ?? defaults.autoHints,
      speakInstructions: json['speakInstructions'] as bool? ?? defaults.speakInstructions,
      sounds: json['sounds'] as bool? ?? defaults.sounds,
      textSize: pick(TextSizeChoice.values, json['textSize'], defaults.textSize),
      theme: pick(ThemeChoice.values, json['theme'], defaults.theme),
    );
  }
}
