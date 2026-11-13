import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'app_state.dart';
import 'core/languages.dart';
import 'services/local_store.dart';
import 'services/models/model_catalog.dart';
import 'services/models/model_store.dart';
import 'services/pack_repository.dart';
import 'services/speech/speech_engine.dart';
import 'services/speech/speech_services.dart';
import 'services/storage/imported_pack_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerLicences();

  final store = await LocalStore.open();
  final catalog = await ModelCatalog.load();
  final models = ModelStore.create(catalog);
  final speech = DeviceSpeechServices(engine: SpeechEngine.create(), models: models);
  final state = AppState(
    store: store,
    packs: PackRepository(storage: ImportedPackStorage.create(store)),
    models: models,
    speech: speech,
  );
  await state.load();
  if (state.settings.language == null) {
    // Start in the phone's language when Speakagain has it.
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    await state.updateSettings(state.settings.copyWith(language: languageForLocale(locale).code));
  }
  runApp(SpeakagainApp(state: state));
}

/// Licences of bundled assets that don't come from Dart packages.
void _registerLicences() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['OpenMoji'],
      'Pictures from OpenMoji (https://openmoji.org), the open-source emoji and icon project.\n'
      'License: CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/).',
    );
    yield const LicenseEntryWithLineBreaks(
      ['Atkinson Hyperlegible'],
      'Atkinson Hyperlegible font, Copyright 2020 Braille Institute of America, Inc.\n'
      'Licensed under the SIL Open Font License, Version 1.1 (https://openfontlicense.org).',
    );
    yield const LicenseEntryWithLineBreaks(
      ['Whisper speech models'],
      'Speech checking uses OpenAI Whisper models (MIT License, Copyright (c) 2022 OpenAI), '
      'exported for sherpa-onnx by the k2-fsa project.',
    );
    yield const LicenseEntryWithLineBreaks(
      ['Piper voices', 'eSpeak NG'],
      'Natural voices are Piper voices (https://github.com/rhasspy/piper) as used by Saywell; each '
      "voice's licence is shown with it. Text is turned into sounds with eSpeak NG data (GPL-3.0-or-later).",
    );
  });
}
