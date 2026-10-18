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
  LocalDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'firstcase_cache',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );
  @override
  int get schemaVersion => 1;

  Future<dynamic> read(String key) async {
    try {
      final row = await (select(
        cacheEntries,
      )..where((t) => t.key.equals(key))).getSingleOrNull();
      return row == null ? null : jsonDecode(row.value);
    } catch (_) {
      // Browser storage can be disabled in private mode. Server remains usable.
      return null;
    }
  }

  Future<void> write(String key, dynamic value, {bool personal = false}) async {
    try {
      await into(cacheEntries).insertOnConflictUpdate(
        CacheEntriesCompanion.insert(
          key: key,
          value: jsonEncode(value),
          personal: Value(personal),
        ),
      );
    } catch (_) {
      // Cache availability never determines whether a server action succeeds.
    }
  }

  Future<void> wipePersonal() async {
    try {
      await (delete(cacheEntries)..where((t) => t.personal.equals(true))).go();
    } catch (_) {
      // No cache can be read when storage is unavailable; identity still changes.
    }
  }
}
