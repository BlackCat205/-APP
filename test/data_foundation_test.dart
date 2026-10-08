import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:perfume_app/database/app_database.dart';
import 'package:perfume_app/database/recommendation_schema.dart';
import 'package:perfume_app/models/usage_record.dart';
import 'package:perfume_app/services/smell_moment_repository.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late Database db;
  late SmellMomentRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('scent_data_test_');
    db = await AppDatabase().openAt(
      '${directory.path}/test.db',
      factory: databaseFactoryFfi,
    );
    repository = SmellMomentRepository(db);
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<int> addUsage(
    int id,
    int start,
    int end, {
    String source = 'app_command_unverified',
  }) => db.insert(
    'usage_records',
    UsageRecord(
      id: id,
      startTime: start,
      endTime: end,
      duration: (end - start) ~/ 1000,
      fanId: 1,
      scentName: '雪松',
      createdAt: start,
      source: source,
    ).toMap(),
  );

  test(
    'fresh database and repeated schema migration keep defaults and constraints',
    () async {
      expect(await db.getVersion(), 11);
      expect(await db.query('fan_scent_config'), hasLength(4));
      await RecommendationSchema.migrate(db);
      expect(await db.query('fan_scent_config'), hasLength(4));
      expect(await db.rawQuery('PRAGMA foreign_keys'), [
        {'foreign_keys': 1},
      ]);
      await expectLater(
        db.insert('usage_feedback', {
          'session_id': 'missing',
          'created_at': 0,
          'updated_at': 0,
        }),
        throwsA(isA<DatabaseException>()),
      );
    },
  );

  test(
    'v9 migration preserves old records without invented session or confidence',
    () async {
      await db.close();
      final path = '${directory.path}/v9.db';
      db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 9,
          onCreate: (db, _) async {
            await db.execute('''CREATE TABLE fan_scent_config (
              id INTEGER PRIMARY KEY, fan_id INTEGER UNIQUE,
              scent_name TEXT, updated_at INTEGER)''');
            await db.execute('''CREATE TABLE scent_diary_note (
              id INTEGER PRIMARY KEY, mood TEXT, used_scent TEXT,
              scene TEXT, note_content TEXT, created_at INTEGER)''');
            await db.execute('''CREATE TABLE card_trigger_records (
              id INTEGER PRIMARY KEY, created_at INTEGER NOT NULL)''');
            await db.insert('fan_scent_config', {
              'id': 1,
              'fan_id': 1,
              'scent_name': '薄荷',
              'updated_at': 0,
            });
            await db.insert('scent_diary_note', {
              'id': 1,
              'mood': '放松',
              'note_content': '原始日记',
              'created_at': 0,
            });
            await db.insert('card_trigger_records', {'id': 1, 'created_at': 0});
            await db.execute(
              '''CREATE TABLE usage_records (
          id INTEGER PRIMARY KEY, start_time INTEGER NOT NULL, end_time INTEGER,
          duration INTEGER, fan_id INTEGER NOT NULL, scent_name TEXT, created_at INTEGER NOT NULL)''',
            );
            await db.execute(
              '''CREATE TABLE smell_moment_record (
          id INTEGER PRIMARY KEY, title TEXT, scene_tag TEXT, emotion_emoji TEXT,
          note TEXT, scent_combo TEXT, score INTEGER, created_at INTEGER NOT NULL)''',
            );
            await db.insert('usage_records', {
              'id': 7,
              'start_time': 0,
              'end_time': 600000,
              'duration': 600,
              'fan_id': 2,
              'scent_name': '檀香',
              'created_at': 0,
            });
            await db.insert('smell_moment_record', {
              'id': 4,
              'title': '旧收藏',
              'score': 5,
              'scent_combo': '檀香',
              'created_at': 0,
            });
          },
        ),
      );
      await db.close();
      db = await AppDatabase().openAt(path, factory: databaseFactoryFfi);
      expect(await db.getVersion(), 11);
      final usage = (await db.query('usage_records')).single;
      expect(usage['id'], 7);
      expect(usage['duration'], 600);
      expect(usage['session_id'], isNull);
      expect(usage['source'], 'legacy_unknown');
      final moment = (await db.query('smell_moment_record')).single;
      expect(moment['score'], 5);
      expect(moment['scent_combo'], '檀香');
      expect(moment['duration_seconds'], isNull);
      expect(await db.query('usage_sessions'), isEmpty);
      expect(await db.query('preference_profiles'), isEmpty);
      expect((await db.query('fan_scent_config')).single['scent_name'], '薄荷');
      expect(
        (await db.query('scent_diary_note')).single['note_content'],
        '原始日记',
      );
      expect(await db.query('card_trigger_records'), hasLength(1));
    },
  );

  test(
    'feedback is unique per session, validates scale and cascades on deletion',
    () async {
      await db.insert('usage_sessions', {
        'id': 'session',
        'user_id': 'local',
        'start_time': 0,
        'scent_snapshot': '{}',
        'created_at': 0,
        'updated_at': 0,
      });
      final feedback = <String, Object?>{
        'session_id': 'session',
        'liking': 6,
        'created_at': 0,
        'updated_at': 0,
      };
      await expectLater(
        db.insert('usage_feedback', feedback),
        throwsA(isA<DatabaseException>()),
      );
      feedback['liking'] = 4;
      await db.insert('usage_feedback', feedback);
      await expectLater(
        db.insert('usage_feedback', feedback),
        throwsA(isA<DatabaseException>()),
      );
      await db.delete(
        'usage_sessions',
        where: 'id = ?',
        whereArgs: ['session'],
      );
      expect(await db.query('usage_feedback'), isEmpty);
    },
  );

  test('v10 upgrade retains sessions and adds timer deadline', () async {
    await db.insert('usage_sessions', {
      'id': 'old-session',
      'user_id': 'local',
      'start_time': 0,
      'scent_snapshot': '[]',
      'created_at': 0,
      'updated_at': 0,
    });
    await db.execute('ALTER TABLE usage_records DROP COLUMN timer_end_time');
    await db.setVersion(10);
    final path = db.path;
    await db.close();
    db = await AppDatabase().openAt(path, factory: databaseFactoryFfi);
    expect(await db.getVersion(), 11);
    expect((await db.query('usage_sessions')).single['id'], 'old-session');
    expect(
      (await db.rawQuery(
        'PRAGMA table_info(usage_records)',
      )).map((r) => r['name']),
      contains('timer_end_time'),
    );
  });

  test(
    'exact associations, union duration and deletion stay consistent',
    () async {
      await addUsage(1, 0, 600000);
      await addUsage(11, 0, 600000);
      final id = await repository.save(score: 4, usageRecordIds: [1, 1, 11]);
      final row = (await repository.getAll()).single;
      expect(row['duration_seconds'], 600);
      expect(row['session_id'], isNull);
      expect(await db.query('moment_usage_records'), hasLength(2));
      expect(await repository.getByUsageRecordId(1), hasLength(1));
      expect(await repository.getByUsageRecordId(2), isEmpty);
      expect(await repository.getByUsageRecordId(11), hasLength(1));
      await repository.delete(id);
      expect(await repository.getAll(), isEmpty);
      expect(await db.query('moment_usage_records'), isEmpty);
      expect(await db.query('usage_records'), hasLength(2));
    },
  );

  test(
    'missing association aborts whole save; test records stay marked',
    () async {
      await addUsage(1, 0, 2000, source: 'test');
      await expectLater(
        repository.save(usageRecordIds: [1, 99]),
        throwsStateError,
      );
      expect(await repository.getAll(), isEmpty);
      await repository.save(usageRecordIds: [1]);
      final row = (await repository.getAll()).single;
      expect(row['source'], 'test');
      expect(row['duration_seconds'], isNull);
      await expectLater(repository.save(score: 6), throwsArgumentError);
    },
  );

  test(
    'legacy import deduplicates, retains SQLite score, and never resurrects deletion',
    () async {
      final time = DateTime(2026, 1, 1, 12);
      final id = await db.insert('smell_moment_record', {
        'title': '午休',
        'note': '清爽',
        'scene_tag': '其他',
        'emotion_emoji': '',
        'score': 5,
        'scent_combo': '薄荷',
        'created_at': time.millisecondsSinceEpoch + 30,
      });
      final raw = jsonEncode({
        'title': '午休',
        'note': '清爽',
        'scene': '其他',
        'emoji': '',
        'timestamp': time.toString(),
        'recipe': '薰衣草,檀香,雪松',
        'duration': '00:30:00',
      });
      await repository.importLegacy([raw, raw]);
      await repository.importLegacy([raw]);
      final row = (await repository.getAll()).single;
      expect(row['id'], id);
      expect(row['score'], 5);
      expect(row['scent_combo'], '薄荷');
      expect(row['duration_seconds'], isNull);
      await repository.delete(id);
      await repository.importLegacy([raw]);
      expect(await repository.getAll(), isEmpty);
      expect(
        (await db.query('legacy_moment_imports')).single['moment_id'],
        isNull,
      );
    },
  );

  test(
    'orphan legacy text survives without demonstration recipe or duration',
    () async {
      await repository.importLegacy([
        jsonEncode({
          'title': '保留笔记',
          'note': '清爽',
          'timestamp': '2026-01-02 10:00:00',
          'recipe': '薰衣草,檀香,雪松',
          'duration': '00:30:00',
        }),
        '{title: 早期笔记, timestamp: 2026-01-03 10:00:00, note: 很好}',
        'broken data',
      ]);
      final rows = await repository.getAll();
      expect(rows, hasLength(2));
      for (final row in rows) {
        expect(row['source'], 'legacy_preferences');
        expect(row['duration_seconds'], isNull);
        expect(row['scent_combo'], isNull);
        expect(row['score'], isNull);
      }
      expect(rows.map((r) => r['note']), containsAll(['清爽', '很好']));
    },
  );

  test(
    'duration handles staggered fans, gaps, incomplete and test records',
    () {
      UsageRecord record(int start, int? end) => UsageRecord(
        startTime: start,
        endTime: end,
        fanId: 1,
        createdAt: start,
      );
      expect(
        SmellMomentRepository.elapsedSeconds([
          record(0, 600000),
          record(300000, 900000),
          record(1000000, 1100000),
        ]),
        1000,
      );
      expect(SmellMomentRepository.elapsedSeconds([record(0, null)]), isNull);
      expect(SmellMomentRepository.elapsedSeconds([record(10, 0)]), isNull);
      expect(SmellMomentRepository.elapsedSeconds([]), isNull);
    },
  );
}
