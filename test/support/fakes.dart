import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speakagain/app_state.dart';
import 'package:speakagain/models/settings.dart';
import 'package:speakagain/services/local_store.dart';
import 'package:speakagain/services/models/model_catalog.dart';
import 'package:speakagain/services/models/model_store.dart';
import 'package:speakagain/services/pack_repository.dart';
import 'package:speakagain/services/speech/recorder.dart';
import 'package:speakagain/services/speech/speech_services.dart';
import 'package:speakagain/services/storage/imported_pack_storage.dart';

/// Speech services that record what the app asked for and answer with scripted text.
class FakeSpeechServices extends SpeechServices {
  FakeSpeechServices({this.checking = true, this.recording = true});

  bool checking;
  bool recording;
  bool microphoneAllowed = true;

  /// What the "recogniser" hears next, in order. Empty string = nothing caught.
  final List<String> heard = [];

  /// Make the next recording silent (no speech detected).
  bool nextSilent = false;

  final List<String> spoken = [];
  int chimes = 0;
  AppSettings settings = const AppSettings();
  final ValueNotifier<double> _level = ValueNotifier(0);

  @override
  void configure(AppSettings settings) => this.settings = settings;

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stopSpeaking() async {}

  @override
  Future<void> playChime() async => chimes++;

  @override
  Future<void> playRecording(Recording recording) async {}

  @override
  bool get canCheckSpeech => checking && settings.speechChecking;

  @override
  bool get canRecord => recording;

  @override
  ValueListenable<double> get inputLevel => _level;

  @override
  Future<bool> ensureMicrophone() async => microphoneAllowed;

  @override
  Future<Recording> listen() async {
    if (nextSilent) {
      nextSilent = false;
      return Recording(Float32List(0), 16000, heardSpeech: false);
    }
    return Recording(Float32List(1600), 16000, heardSpeech: true);
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> cancelListening() async {}

  @override
  Future<String> transcribe(Recording recording) async => heard.isEmpty ? '' : heard.removeAt(0);

  @override
  Future<void> warmUp() async {}
}

/// In-memory pack storage for tests.
class MemoryPackStorage implements ImportedPackStorage {
  final Map<String, Object?> packs = {};
  final Map<String, Map<String, Uint8List>> images = {};

  @override
  Future<List<StoredPack>> loadAll() async => [for (final e in packs.entries) StoredPack(e.key, e.value)];

  @override
  Future<void> save(String id, Map<String, Object?> packJson, Map<String, Uint8List> images) async {
    packs[id] = packJson;
    this.images[id] = images;
  }

  @override
  Future<void> remove(String id) async {
    packs.remove(id);
    images.remove(id);
  }

  @override
  Future<Uint8List?> image(String packId, String path) async => images[packId]?[path];
}

/// A model store where nothing is downloaded (like the web build).
class EmptyModelStore implements ModelStore {
  EmptyModelStore(this.catalog);

  @override
  final ModelCatalog catalog;

  @override
  bool get isSupported => true;

  @override
  Future<void> init() async {}

  final Set<String> installed = {};

  @override
  bool isInstalled(Downloadable item) => installed.contains(item.id);

  @override
  String pathOf(Downloadable item, ModelFile file) => '/models/${item.id}/${file.name}';

  @override
  String get voiceDataDir => '/models/espeak-ng-data/espeak-ng-data';

  @override
  Future<void> download(Downloadable item, {ProgressCallback? onProgress, ValueListenable<bool>? cancel}) async {
    onProgress?.call(0.5);
    installed.add(item.id);
    onProgress?.call(1);
  }

  @override
  Future<List<Downloadable>> installFromFiles(List<String> paths) async => const [];

  @override
  Future<void> remove(Downloadable item) async => installed.remove(item.id);
}

/// A fully loaded [AppState] with the real bundled packs and fake speech.
Future<AppState> createTestState({
  AppSettings settings = const AppSettings(language: 'en', onboarded: true, speakInstructions: false),
  FakeSpeechServices? speech,
  DateTime Function()? clock,
}) async {
  // rootBundle caches futures; one cached in an earlier test's fake-async zone
  // never completes in the next test.
  rootBundle.clear();
  SharedPreferences.setMockInitialValues({});
  final store = LocalStore(await SharedPreferences.getInstance());
  await store.saveSettings(settings);
  final catalog = await ModelCatalog.load(rootBundle);
  final state = AppState(
    store: store,
    packs: PackRepository(storage: MemoryPackStorage(), bundle: rootBundle),
    models: EmptyModelStore(catalog),
    speech: speech ?? FakeSpeechServices(),
    clock: clock,
  );
  await state.load();
  return state;
}
