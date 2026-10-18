import 'dart:js_interop';

@JS('document.documentElement.lang')
external set _documentLanguage(String value);

void updateDocumentLocale(String language) => _documentLanguage = language;
