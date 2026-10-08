import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:perfume_app/database/app_database.dart';
import 'package:perfume_app/services/usage_session_service.dart';
import 'package:perfume_app/services/smell_moment_repository.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late Directory directory;
  late UsageSessionService service;
  late DateTime now;
  late List<String> commands;
  late bool connected;
  String? failCommand;
  Future<void> Function(String)? intercept;
  final scents = {1: '雪松', 2: '薄荷', 3: '檀香', 4: '甜橙'};

  UsageSessionService create() => UsageSessionService(
    db: db,
    clock: () => now,
    connected: () => connected,
    scentForFan: (fan) => scents[fan]!,
    send: (command) async {
      commands.add(command);
      if (command == failCommand) throw StateError('模拟写入失败');
      await intercept?.call(command);
    },
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('scent_session_');
    db = await AppDatabase().openAt(
      '${directory.path}/test.db',
      factory: databaseFactoryFfi,
    );
    now = DateTime(2026, 1, 1, 12);
    commands = [];
    connected = true;
    failCommand = null;
    intercept = null;
    service = create();
    await service.initialize();
  });
  tearDown(() async {
    service.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });
  Future<Map<String, Object?>> session() async =>
      (await db.query('usage_sessions')).single;

  test(
    'start is persisted before BLE, becomes active only after successful write',
    () async {
      intercept = (_) async {
        expect((await db.query('usage_records')).single['status'], 'pending');
        expect(service.activeFans, isEmpty);
        now = now.add(const Duration(seconds: 2));
      };
      await service.startFan(1, userId: 'alice', beforeState: 2, scene: '睡前');
      expect(service.activeFans, {1});
      final record = (await db.query('usage_records')).single;
      expect(record['status'], 'active_unverified');
      expect(record['start_time'], now.millisecondsSinceEpoch);
      expect(record['session_id'], (await session())['id']);
      expect((await session())['before_state_source'], 'before_use');
      expect(record['end_time'], isNull);
    },
  );

  test(
    'failed start records no successful use or feedback candidate',
    () async {
      failCommand = 'fan1on';
      await expectLater(service.startFan(1, userId: 'alice'), throwsStateError);
      expect(service.activeFans, isEmpty);
      expect((await session())['status'], 'failed');
      expect((await db.query('usage_records')).single['duration'], isNull);
      expect(await service.feedbackSessions('alice'), isEmpty);
    },
  );

  test('DB failure prevents hardware start', () async {
    await db.execute(
      "CREATE TRIGGER reject_start BEFORE INSERT ON usage_records BEGIN SELECT RAISE(ABORT, 'test'); END",
    );
    await expectLater(
      service.startFan(1, userId: 'alice'),
      throwsA(isA<DatabaseException>()),
    );
    expect(commands, isEmpty);
    expect(await db.query('usage_sessions'), isEmpty);
  });

  test(
    'overlapping fans share one session and preserve changing composition',
    () async {
      await service.startFan(1, userId: 'alice');
      now = now.add(const Duration(seconds: 10));
      await service.startFan(2, userId: 'alice');
      now = now.add(const Duration(seconds: 10));
      await service.stopFan(1);
      expect(service.lastFinished, isNull);
      expect(service.activeFans, {2});
      now = now.add(const Duration(seconds: 10));
      await service.stopAll();
      final row = await session();
      expect(row['duration'], 30);
      expect(row['status'], 'completed_unverified');
      expect(row['combination_key'], isNull);
      final snapshot = jsonDecode(row['scent_snapshot'] as String) as List;
      expect(snapshot, hasLength(2));
      expect(snapshot.first['duration'], 20);
      expect(snapshot.last['duration'], 20);
      expect(service.lastFinished, row['id']);
      expect(service.activeFans, isEmpty);
    },
  );

  test('recommended combination starts as one session', () async {
    await service.startCombination(
      [1, 3],
      userId: 'alice',
      beforeState: 3,
      scene: '阅读',
    );
    expect(service.activeFans, {1, 3});
    expect(await db.query('usage_sessions'), hasLength(1));
    expect(await db.query('usage_records'), hasLength(2));
    expect(commands, ['fan1_cancel', 'fan1on', 'fan3_cancel', 'fan3on']);
  });

  test(
    'recommendation simulation creates a feedback-ready session without BLE',
    () async {
      final id = await service.createRecommendationSimulation(
        [1, 3, 4],
        userId: 'alice',
        durationSeconds: 65,
        beforeState: 2,
        scene: '测试',
      );
      expect(commands, isEmpty);
      expect(service.lastFinished, id);
      final row = await session();
      expect(row['source'], 'recommendation_simulation');
      expect(row['duration'], 65);
      expect(await service.feedbackSessions('alice'), hasLength(1));
      final records = await db.query('usage_records');
      expect(records, hasLength(3));
      expect(
        records.every((r) => r['source'] == 'recommendation_simulation'),
        isTrue,
      );
    },
  );

  test('partial recommended combination failure is interrupted', () async {
    failCommand = 'fan2on';
    await expectLater(
      service.startCombination([1, 2], userId: 'alice'),
      throwsStateError,
    );
    expect(commands.last, 'alloff');
    expect(service.activeFans, isEmpty);
    expect((await session())['status'], 'interrupted');
    expect((await db.query('usage_records')).first['duration'], isNull);
  });

  test(
    'failed off preserves last commanded state and retry does not invent duration',
    () async {
      await service.startFan(1, userId: 'alice');
      failCommand = 'fan1off';
      await expectLater(service.stopFan(1), throwsStateError);
      expect(service.activeFans, {1});
      expect((await db.query('usage_records')).single['end_time'], isNull);
      failCommand = null;
      now = now.add(const Duration(minutes: 5));
      await service.stopFan(1);
      expect((await session())['duration'], isNull);
      expect((await session())['status'], 'completed_estimated');
    },
  );

  test(
    'alloff failure closes no records; successful retry ends all fans',
    () async {
      await service.startFan(1, userId: 'alice');
      await service.startFan(2, userId: 'alice');
      failCommand = 'alloff';
      await expectLater(service.stopAll(), throwsStateError);
      expect(service.activeFans, {1, 2});
      expect(
        (await db.query('usage_records')).every((r) => r['end_time'] == null),
        isTrue,
      );
      failCommand = null;
      await service.stopAll();
      expect(service.activeFans, isEmpty);
      expect(await service.feedbackSessions('alice'), hasLength(1));
    },
  );

  test('rapid duplicate starts serialize and send once', () async {
    final gate = Completer<void>();
    intercept = (_) => gate.future;
    final first = service.startFan(1, userId: 'alice');
    final second = service.startFan(1, userId: 'alice');
    gate.complete();
    await Future.wait([first, second]);
    expect(commands, ['fan1_cancel', 'fan1on']);
    expect(await db.query('usage_records'), hasLength(1));
  });

  test('timer replacement and cancellation invalidate old callbacks', () async {
    await service.startFan(1, userId: 'alice');
    await service.setTimer(1, 60000);
    final old = now.millisecondsSinceEpoch + 60000;
    await service.setTimer(1, 120000);
    now = now.add(const Duration(seconds: 60));
    await service.expireTimer(1, old);
    expect(service.activeFans, {1});
    await service.setTimer(1, 0);
    now = now.add(const Duration(seconds: 60));
    await service.expireTimer(1, old + 60000);
    expect(service.activeFans, {1});
    expect(commands.where((c) => c == 'fan1off'), isEmpty);
    expect((await db.query('usage_records')).single['timer_end_time'], isNull);
  });

  test(
    'timer expiry sends off and records estimated end without trusted duration',
    () async {
      await service.startFan(1, userId: 'alice');
      await service.setTimer(1, 60000);
      final deadline = now.millisecondsSinceEpoch + 60000;
      now = now.add(const Duration(minutes: 2));
      await service.expireTimer(1, deadline);
      expect(commands.last, 'fan1off');
      expect(service.activeFans, isEmpty);
      expect((await session())['status'], 'completed_estimated');
      final record = (await db.query('usage_records')).single;
      expect(record['end_time'], deadline);
      expect(record['duration'], isNull);
      final id = await SmellMomentRepository(
        db,
      ).save(usageRecordIds: [record['id'] as int]);
      expect(
        (await db.query(
          'smell_moment_record',
          where: 'id = ?',
          whereArgs: [id],
        )).single['duration_seconds'],
        isNull,
      );
    },
  );

  test('disconnect and restart never fabricate a completed use', () async {
    await service.startFan(1, userId: 'alice');
    await service.setTimer(1, 60000);
    connected = false;
    await service.interrupt('断连');
    expect((await session())['status'], 'interrupted');
    expect((await session())['duration'], isNull);
    expect(service.activeFans, isEmpty);
    expect((await db.query('usage_records')).single['end_time'], isNull);
    connected = true;
    await service.startFan(2, userId: 'alice');
    service.dispose();
    service = create();
    now = now.add(const Duration(days: 1));
    await service.initialize();
    expect(
      (await db.query(
        'usage_sessions',
      )).every((r) => r['status'] == 'interrupted'),
      isTrue,
    );
    expect(service.activeFans, isEmpty);
    expect(commands.where((c) => c.endsWith('off')), isEmpty);
  });

  test(
    'feedback is independent of collection and edits invalidate profile',
    () async {
      await service.startFan(1, userId: 'alice', beforeState: 2);
      now = now.add(const Duration(seconds: 60));
      await service.stopAll();
      final id = service.lastFinished!;
      await service.saveFeedback(
        sessionId: id,
        userId: 'alice',
        beforeState: 2,
        afterState: 4,
        liking: 5,
        reuseIntent: 2,
        note: '清爽',
      );
      await service.saveFeedback(
        sessionId: id,
        userId: 'alice',
        beforeState: 2,
        afterState: 3,
        liking: 3,
        reuseIntent: 1,
        note: '有点浓',
      );
      expect(await db.query('usage_feedback'), hasLength(1));
      expect((await db.query('usage_feedback')).single['note'], '有点浓');
      expect(
        (await db.query('preference_profiles')).single['input_version'],
        2,
      );
      expect(
        (await db.query('preference_profiles')).single['status'],
        'pending',
      );
      expect(await db.query('smell_moment_record'), isEmpty);
      await expectLater(
        service.saveFeedback(sessionId: id, userId: 'alice', beforeState: 5),
        throwsStateError,
      );
      await expectLater(
        service.saveFeedback(sessionId: id, userId: 'bob'),
        throwsStateError,
      );
      expect(await service.feedbackSessions('bob'), isEmpty);
    },
  );

  test(
    'missing before-state remains null and recalled state is marked',
    () async {
      await service.startFan(1, userId: 'alice');
      await service.stopAll();
      final id = service.lastFinished!;
      await service.saveFeedback(sessionId: id, userId: 'alice', liking: 3);
      expect((await session())['before_state'], isNull);
      await service.saveFeedback(
        sessionId: id,
        userId: 'alice',
        beforeState: 2,
        liking: 3,
      );
      expect((await session())['before_state_source'], 'recalled');
      await expectLater(
        service.saveFeedback(sessionId: id, userId: 'alice', liking: 9),
        throwsArgumentError,
      );
    },
  );
}
