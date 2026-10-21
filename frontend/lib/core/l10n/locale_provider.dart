import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart' show databaseProvider, sessionProvider;
import 'document_locale.dart';

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale> {
  bool _changedByUser = false;
  bool _hasPreference = false;
  late final Future<void> ready;

  @override
  Locale build() {
    ready = _restore();
    unawaited(ready);
    final system = WidgetsBinding.instance.platformDispatcher.locale;
    final initial = Locale(system.languageCode == 'ky' ? 'ky' : 'ru');
    updateDocumentLocale(initial.languageCode);
    return initial;
  }

  Future<void> _restore() async {
    final stored = await ref.read(databaseProvider).read('locale');
    if (ref.mounted && !_changedByUser && (stored == 'ru' || stored == 'ky')) {
      _hasPreference = true;
      state = Locale(stored as String);
      updateDocumentLocale(state.languageCode);
    }
  }

  Future<void> select(Locale locale) async {
    if (!const ['ru', 'ky'].contains(locale.languageCode)) {
      throw ArgumentError.value(locale, 'locale');
    }
    _changedByUser = true;
    _hasPreference = true;
    state = Locale(locale.languageCode);
    updateDocumentLocale(state.languageCode);
    await ref.read(databaseProvider).write('locale', state.languageCode);
    if (!ref.mounted) return;
    if (ref.read(sessionProvider).value != null) {
      await ref.read(sessionProvider.notifier).updateProfile({
        'language': state.languageCode,
      });
    }
  }

  Future<void> adoptAccountLanguage(String? language) async {
    await ready;
    if (!ref.mounted) return;
    if (!_hasPreference && (language == 'ru' || language == 'ky')) {
      state = Locale(language!);
      updateDocumentLocale(state.languageCode);
      await ref.read(databaseProvider).write('locale', language);
      _hasPreference = true;
    }
  }
}
