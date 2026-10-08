import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:perfume_app/database/app_database.dart';
import 'package:perfume_app/models/recommendation.dart';
import 'package:perfume_app/services/recommendation_service.dart';
import 'package:perfume_app/services/usage_session_service.dart';
import 'package:perfume_app/services/scent_catalog.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late Database db;
  late RecommendationService engine;
  late Map<int, String> config;
  final now = DateTime(2026, 9, 22, 12);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('scent_recommendation_');
    db = await AppDatabase().openAt(
      '${directory.path}/test.db',
      factory: databaseFactoryFfi,
    );
    config = {1: '雪松', 2: '薄荷', 3: '檀香', 4: '甜橙'};
    engine = RecommendationService(
      db: db,
      configuration: () => config,
      clock: () => now,
    );
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<void> seed(
    String id,
    List<(int, String, int, int)> intervals, {
    String user = 'alice',
    String status = 'completed_unverified',
    String source = 'app_command_unverified',
    bool feedback = true,
    int liking = 5,
  }) async {
    final base = now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
    final start = intervals.map((r) => r.$3).reduce((a, b) => a < b ? a : b);
    final end = intervals.map((r) => r.$4).reduce((a, b) => a > b ? a : b);
    await db.insert('usage_sessions', {
      'id': id,
      'user_id': user,
      'start_time': base + start * 1000,
      'end_time': base + end * 1000,
      'duration': end - start,
      'scent_snapshot': '[]',
      'status': status,
      'source': source,
      'before_state': 2,
      'before_state_source': 'before_use',
      'created_at': base,
      'updated_at': base,
    });
    for (final interval in intervals) {
      await db.insert('usage_records', {
        'session_id': id,
        'fan_id': interval.$1,
        'scent_name': interval.$2,
        'start_time': base + interval.$3 * 1000,
        'end_time': base + interval.$4 * 1000,
        'duration': interval.$4 - interval.$3,
        'created_at': base,
        'status': status,
        'source': source,
      });
    }
    final rows = await db.query(
      'usage_records',
      where: 'session_id = ?',
      whereArgs: [id],
    );
    await db.update(
      'usage_sessions',
      {'scent_snapshot': jsonEncode(rows)},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (feedback) {
      await db.insert('usage_feedback', {
        'session_id': id,
        'liking': liking,
        'after_state': 4,
        'reuse_intent': 2,
        'created_at': base,
        'updated_at': base,
      });
    }
  }

  Recommendation item(RecommendationReport report, String key) =>
      report.recommendations.singleWhere((r) => r.candidate.id == key);

  test(
    'offline cold start uses only mounted scents and no invented score',
    () async {
      final report = await engine.recommend('alice');
      expect(report.exploration, hasLength(15));
      expect(report.verified, isEmpty);
      expect(
        report.recommendations.every(
          (r) => r.behaviorScore == null && r.aiScore == null,
        ),
        isTrue,
      );
      config = {};
      expect((await engine.recommend('alice')).recommendations, isEmpty);
    },
  );

  test(
    'real feedback edits change score, reason and ranking without AI',
    () async {
      await seed('a', [(1, '雪松', 0, 600)]);
      await seed('b', [(2, '薄荷', 0, 600)], liking: 3);
      final before = await engine.recommend('alice');
      expect(before.verified.first.candidate.id, 'cedar');
      final feedback = UsageSessionService(
        db: db,
        connected: () => false,
        send: (_) async => fail('推荐或反馈不能发送 BLE'),
        scentForFan: (_) => '',
        clock: () => now,
      );
      await feedback.saveFeedback(
        sessionId: 'a',
        userId: 'alice',
        beforeState: 2,
        afterState: 1,
        liking: 1,
        reuseIntent: 0,
        note: '太浓',
      );
      feedback.dispose();
      final after = await engine.recommend('alice');
      expect(after.verified.first.candidate.id, 'mint');
      expect(
        item(after, 'cedar').behaviorScore,
        lessThan(item(before, 'cedar').behaviorScore!),
      );
      expect(item(after, 'cedar').reason, isNot(item(before, 'cedar').reason));
      expect(item(after, 'cedar').useCount, 1);
      expect(item(after, 'cedar').feedbackCount, 1);
    },
  );

  test(
    'dedicated recommendation simulation participates but generic test data does not',
    () async {
      await seed('simulation', [
        (1, '雪松', 0, 600),
      ], source: 'recommendation_simulation');
      await seed('generic-test', [(2, '薄荷', 0, 600)], source: 'test');
      final report = await engine.recommend('alice');
      expect(item(report, 'cedar').useCount, 1);
      expect(item(report, 'mint').useCount, 0);
    },
  );

  test(
    'ready versioned AI scores rank candidates and expose dynamic fusion',
    () async {
      final aiScores = ScentCatalog.candidates(config)
          .map(
            (candidate) => {
              'candidate_id': candidate.id,
              'score': candidate.id == 'cedar' ? 91 : 10,
            },
          )
          .toList();
      await db.insert('preference_profiles', {
        'user_id': 'alice',
        'input_version': 2,
        'candidate_version': '2',
        'status': 'ready',
        'confidence': .8,
        'preferred_traits': '["木质"]',
        'disliked_traits': '[]',
        'candidate_scores': jsonEncode(aiScores),
        'reason': '偏好木质',
        'updated_at': now.millisecondsSinceEpoch,
      });
      final cold = await engine.recommend('alice');
      expect(cold.recommendations.first.candidate.id, 'cedar');
      expect(item(cold, 'cedar').aiScore, 91);
      expect(item(cold, 'cedar').overallScore, 91);
      expect(item(cold, 'cedar').behaviorShare, 0);

      await seed('used', [(1, '雪松', 0, 600)]);
      final fused = item(await engine.recommend('alice'), 'cedar');
      expect(fused.behaviorScore, isNotNull);
      expect(fused.overallScore, isNot(fused.behaviorScore));
      expect(fused.behaviorShare, inExclusiveRange(0, 1));
    },
  );

  test('separate single uses never verify an unused combination', () async {
    await seed('a', [(1, '雪松', 0, 600)]);
    await seed('b', [(2, '薄荷', 0, 600)]);
    final report = await engine.recommend('alice');
    expect(item(report, 'cedar').isVerified, isTrue);
    expect(item(report, 'mint').isVerified, isTrue);
    expect(item(report, 'cedar+mint').isVerified, isFalse);
  });

  test(
    'dominant combo gets feedback once, startup fragment gets exposure only',
    () async {
      await seed('combo', [(1, '雪松', 0, 120), (2, '薄荷', 2, 120)]);
      final report = await engine.recommend('alice');
      expect(item(report, 'cedar+mint').feedbackCount, 1);
      expect(item(report, 'cedar').useCount, 1);
      expect(item(report, 'cedar').feedbackCount, 0);
      expect(item(report, 'cedar').components['喜欢程度'], isNull);
      expect(item(report, 'mint').isVerified, isFalse);
    },
  );

  test(
    'long mixed-composition sessions do not assign feedback to any fragment',
    () async {
      await seed('mixed', [(1, '雪松', 0, 60), (2, '薄荷', 0, 120)]);
      final report = await engine.recommend('alice');
      expect(report.verified, hasLength(2));
      expect(report.verified.every((r) => r.feedbackCount == 0), isTrue);
    },
  );

  test(
    'uncertain, legacy, test, other-user and unlinked memories are excluded',
    () async {
      await seed('timer', [(1, '雪松', 0, 600)], status: 'completed_estimated');
      await seed('broken', [(1, '雪松', 0, 600)], status: 'interrupted');
      await seed('fake', [(1, '雪松', 0, 600)], source: 'test');
      await seed('old', [(1, '雪松', 0, 600)], source: 'legacy_unknown');
      await seed('bob', [(1, '雪松', 0, 600)], user: 'bob');
      await db.insert('smell_moment_record', {
        'title': '手动好评',
        'score': 5,
        'scent_combo': '雪松',
        'created_at': 0,
      });
      final report = await engine.recommend('alice');
      expect(report.verified, isEmpty);
      expect(report.excludedSessions, 4);
      expect((await engine.recommend('bob')).verified, hasLength(1));
    },
  );

  test(
    'channel remap retains scent evidence, replaced scent loses availability',
    () async {
      await seed('a', [(1, '雪松', 0, 600)]);
      final old = item(await engine.recommend('alice'), 'cedar').behaviorScore;
      config = {4: '雪松', 1: '薄荷'};
      final remapped = item(await engine.recommend('alice'), 'cedar');
      expect(remapped.behaviorScore, old);
      expect(remapped.candidate.fans.keys.single, 4);
      config = {1: '薄荷'};
      expect((await engine.recommend('alice')).verified, isEmpty);
    },
  );

  test(
    'deleting a combo component cannot transfer feedback to remaining scent',
    () async {
      await seed('combo', [(1, '雪松', 0, 600), (2, '薄荷', 0, 600)]);
      expect(
        (await engine.recommend('alice')).verified.single.candidate.id,
        'cedar+mint',
      );
      await db.delete(
        'usage_records',
        where: 'session_id = ? AND fan_id = ?',
        whereArgs: ['combo', 2],
      );
      final report = await engine.recommend('alice');
      expect(report.verified, isEmpty);
      expect(report.excludedSessions, 1);
    },
  );

  test(
    'duplicate overlapping channels and changed record timestamps are rejected',
    () async {
      await seed('duplicate', [(1, '雪松', 0, 600), (1, '雪松', 0, 600)]);
      await seed('changed', [(2, '薄荷', 0, 600)]);
      await db.update(
        'usage_records',
        {'duration': 100000},
        where: 'session_id = ?',
        whereArgs: ['changed'],
      );
      expect((await engine.recommend('alice')).verified, isEmpty);
    },
  );

  test(
    'actual session service records feed recommendations after finish and feedback',
    () async {
      var tick = now.subtract(const Duration(minutes: 10));
      final sessions = UsageSessionService(
        db: db,
        connected: () => true,
        send: (_) async {},
        scentForFan: (id) => config[id]!,
        clock: () => tick,
      );
      await sessions.startFan(1, userId: 'alice', beforeState: 2);
      expect((await engine.recommend('alice')).verified, isEmpty);
      tick = now;
      await sessions.stopAll();
      final usageOnly = item(await engine.recommend('alice'), 'cedar');
      expect(usageOnly.feedbackCount, 0);
      await sessions.saveFeedback(
        sessionId: sessions.lastFinished!,
        userId: 'alice',
        beforeState: 2,
        afterState: 4,
        liking: 5,
        reuseIntent: 2,
      );
      final updated = item(await engine.recommend('alice'), 'cedar');
      expect(updated.feedbackCount, 1);
      expect(updated.behaviorScore, greaterThan(usageOnly.behaviorScore!));
      sessions.dispose();
    },
  );
}
