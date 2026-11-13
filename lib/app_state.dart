import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'core/languages.dart';
import 'core/session_planner.dart';
import 'models/pack.dart';
import 'models/progress.dart';
import 'models/settings.dart';
import 'services/local_store.dart';
import 'services/models/model_catalog.dart';
import 'services/models/model_store.dart';
import 'services/pack_repository.dart';
import 'services/speech/speech_services.dart';

/// Download state of one model or voice.
@immutable
class DownloadState {
  const DownloadState({this.progress, this.failed = false});

  /// 0..1 while downloading, null when idle.
  final double? progress;
  final bool failed;

  bool get active => progress != null;
}

/// The app's state: settings, practice history, packs and downloads.
class AppState extends ChangeNotifier {
  AppState({
    required this.store,
    required this.packs,
    required this.models,
    required this.speech,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LocalStore store;
  final PackRepository packs;
  final ModelStore models;
  final SpeechServices speech;
  final DateTime Function() _clock;

  AppSettings _settings = const AppSettings();
  Map<String, ItemProgress> _progress = {};
  List<DayLog> _days = [];
  final Map<String, DownloadState> _downloads = {};
  final Map<String, ValueNotifier<bool>> _cancels = {};

  AppSettings get settings => _settings;
  Map<String, ItemProgress> get progress => _progress;
  List<DayLog> get days => _days;
  DateTime get now => _clock();

  AppLanguage get language => languageFor(_settings.language);

  ModelCatalog get catalog => models.catalog;

  Future<void> load() async {
    _settings = store.loadSettings();
    _progress = store.loadProgress();
    _days = store.loadDays();
    await packs.load();
    await models.init();
    _fixVoiceChoice();
    speech.configure(_settings);
    notifyListeners();
    unawaited(speech.warmUp());
  }

  /// Falls back to the phone's voice if the chosen natural voice is missing
  /// or belongs to another language.
  void _fixVoiceChoice() {
    if (_settings.voiceId == systemVoiceId) return;
    final voice = catalog.voice(_settings.voiceId);
    if (voice == null || voice.language != language.code || !models.isInstalled(voice)) {
      _settings = _settings.copyWith(voiceId: systemVoiceId);
    }
  }

  Future<void> updateSettings(AppSettings settings) async {
    final languageChanged = settings.language != _settings.language;
    _settings = settings;
    _fixVoiceChoice();
    speech.configure(_settings);
    notifyListeners();
    await store.saveSettings(_settings);
    if (languageChanged) unawaited(speech.warmUp());
  }

  List<Pack> get currentPacks => packs.forLanguage(language.code);

  /// Exercise types with at least one pack in the current language.
  List<ExerciseType> get availableExercises => [
    for (final type in ExerciseType.values)
      if (currentPacks.any((p) => p.offers(type))) type,
  ];

  List<PracticeTask> planSession({ExerciseType? only, int? seed}) => const SessionPlanner().plan(
    packs: currentPacks,
    progress: _progress,
    count: _settings.sessionLength,
    now: now,
    only: only,
    random: math.Random(seed ?? now.millisecondsSinceEpoch),
  );

  Future<void> record(PracticeTask task, Outcome outcome) async {
    final time = now;
    _progress = {..._progress, task.key: (_progress[task.key] ?? const ItemProgress()).record(outcome, time)};
    final key = dayKey(time);
    final days = [..._days];
    if (days.isNotEmpty && days.last.date == key) {
      days[days.length - 1] = days.last.add(outcome);
    } else {
      days.add(DayLog(date: key).add(outcome));
    }
    _days = days;
    notifyListeners();
    await store.saveProgress(_progress);
    await store.saveDays(_days);
  }

  DayLog get today {
    final key = dayKey(now);
    return _days.isNotEmpty && _days.last.date == key ? _days.last : DayLog(date: key);
  }

  /// Days practised in the last 7 days, oldest first (for the week strip).
  List<bool> get lastSevenDays {
    final practised = {
      for (final d in _days)
        if (d.practised > 0) d.date,
    };
    final t = now;
    return [for (var i = 6; i >= 0; i--) practised.contains(dayKey(DateTime(t.year, t.month, t.day - i)))];
  }

  int get daysPractised => _days.where((d) => d.practised > 0).length;

  /// Progress entries for the current language's packs.
  Iterable<MapEntry<String, ItemProgress>> get _currentProgress {
    final ids = {for (final p in currentPacks) p.id};
    return _progress.entries.where((e) => ids.contains(e.key.split('/').first));
  }

  int get wordsPractised => _currentProgress.where((e) => e.value.attempts > 0).length;

  /// Items said without help across several spaced sessions.
  List<(Pack, PackItem)> get easierItems {
    final result = <(Pack, PackItem)>[];
    for (final entry in _currentProgress) {
      if (!entry.value.isEasier) continue;
      final parts = entry.key.split('/');
      final pack = currentPacks.where((p) => p.id == parts.first).firstOrNull;
      final item = pack?.item(parts.last);
      if (pack != null && item != null) result.add((pack, item));
    }
    return result;
  }

  Future<void> resetProgress() async {
    _progress = {};
    _days = [];
    notifyListeners();
    await store.clearProgress();
  }

  Future<Pack> importPack(Uint8List bytes) async {
    final pack = await packs.import(bytes);
    notifyListeners();
    return pack;
  }

  Future<void> removePack(Pack pack) async {
    await packs.remove(pack);
    notifyListeners();
  }

  // ---- Downloads -------------------------------------------------------------

  DownloadState downloadState(Downloadable item) => _downloads[item.id] ?? const DownloadState();

  bool isInstalled(Downloadable item) => models.isInstalled(item);

  Future<bool> download(Downloadable item) async {
    if (downloadState(item).active) return false;
    final cancel = _cancels[item.id] = ValueNotifier(false);
    _downloads[item.id] = const DownloadState(progress: 0);
    notifyListeners();
    var lastNotified = 0.0;
    try {
      await models.download(
        item,
        cancel: cancel,
        onProgress: (p) {
          _downloads[item.id] = DownloadState(progress: p);
          if (p - lastNotified >= 0.01 || p >= 1) {
            lastNotified = p;
            notifyListeners();
          }
        },
      );
      _downloads.remove(item.id);
      speech.configure(_settings);
      notifyListeners();
      if (item is RecognizerModel) unawaited(speech.warmUp());
      return true;
    } on Object catch (e) {
      debugPrint('Download of ${item.id} failed: $e');
      _downloads[item.id] = DownloadState(failed: !cancel.value);
      notifyListeners();
      return false;
    } finally {
      _cancels.remove(item.id);
    }
  }

  void cancelDownload(Downloadable item) => _cancels[item.id]?.value = true;

  /// Downloads a natural voice and the voice data it needs, then uses it.
  Future<bool> downloadVoice(VoiceModel voice) async {
    final data = catalog.voiceData;
    if (data != null && !models.isInstalled(data)) {
      if (!await download(data)) return false;
    }
    if (!models.isInstalled(voice) && !await download(voice)) return false;
    await updateSettings(_settings.copyWith(voiceId: voice.id));
    return true;
  }

  Future<int> installFromFiles(List<String> paths) async {
    final installed = await models.installFromFiles(paths);
    speech.configure(_settings);
    notifyListeners();
    if (installed.any((i) => i is RecognizerModel)) unawaited(speech.warmUp());
    return installed.length;
  }

  Future<void> removeModel(Downloadable item) async {
    await models.remove(item);
    _fixVoiceChoice();
    speech.configure(_settings);
    notifyListeners();
    await store.saveSettings(_settings);
  }
}
