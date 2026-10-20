import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'local_database.g.dart';

class CacheEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  BoolColumn get personal => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [CacheEntries])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase([
    QueryExecutor? executor,
    Duration storageTimeout = const Duration(seconds: 2),
  ]) : _storageTimeout = storageTimeout,
       super(
         executor ??
             driftDatabase(
               name: 'firstcase_cache',
               web: DriftWebOptions(
                 sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                 driftWorker: Uri.parse('drift_worker.js'),
               ),
             ),
       );
  final Duration _storageTimeout;
  bool _storageUnavailable = false;
  int _personalRevision = 0;

  @override
  int get schemaVersion => 1;

  Future<T?> _bestEffort<T>(Future<T> Function() operation) async {
    if (_storageUnavailable) return null;
    try {
      return await operation().timeout(_storageTimeout);
    } catch (_) {
      // WebViews can leave a worker or storage request pending indefinitely.
      // Stop using this cache for the session, including late private reads.
      _storageUnavailable = true;
      return null;
    }
  }

  Future<dynamic> read(String key) async {
    final revision = _personalRevision;
    try {
      final row = await _bestEffort(
        () => (select(
          cacheEntries,
        )..where((t) => t.key.equals(key))).getSingleOrNull(),
      );
      if (_storageUnavailable || revision != _personalRevision || row == null) {
        return null;
      }
      return jsonDecode(row.value);
    } catch (_) {
      // Browser storage can be disabled in private mode. Server remains usable.
      return null;
    }
  }

  Future<void> write(String key, dynamic value, {bool personal = false}) async {
    await _bestEffort(
      () => into(cacheEntries).insertOnConflictUpdate(
        CacheEntriesCompanion.insert(
          key: key,
          value: jsonEncode(value),
          personal: Value(personal),
        ),
      ),
    );
  }

  Future<void> wipePersonal() async {
    _personalRevision++;
    await _bestEffort(
      () => (delete(cacheEntries)..where((t) => t.personal.equals(true))).go(),
    );
  }
}
