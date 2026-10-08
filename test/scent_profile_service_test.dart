import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:perfume_app/database/app_database.dart';
import 'package:perfume_app/services/scent_profile_service.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late Database db;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('scent_profile_');
    db = await AppDatabase().openAt(
      '${directory.path}/test.db',
      factory: databaseFactoryFfi,
    );
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  test(
    'profile contains only reliable user data and current AI state',
    () async {
      final now = DateTime(2026, 1, 2).millisecondsSinceEpoch;
      Future<void> session(
        String id,
        String user,
        String status, {
        String source = 'app_command_unverified',
      }) async {
        final snapshot = jsonEncode([
          {'fan_id': 1, 'scent_name': '雪松', 'status': 'completed_unverified'},
          {'fan_id': 2, 'scent_name': '薄荷', 'status': 'completed_unverified'},
        ]);
        await db.insert('usage_sessions', {
          'id': id,
          'user_id': user,
          'start_time': now - 600000,
          'end_time': now,
          'duration': 600,
          'scent_snapshot': snapshot,
          'status': status,
          'source': source,
          'created_at': now,
          'updated_at': now,
        });
      }

      await session('good', 'alice', 'completed_unverified');
      await session('other', 'bob', 'completed_unverified');
      await session('bad', 'alice', 'interrupted');
      await session(
        'simulation',
        'alice',
        'completed_unverified',
        source: 'recommendation_simulation',
      );
      await db.insert('usage_feedback', {
        'session_id': 'good',
        'liking': 5,
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('preference_profiles', {
        'user_id': 'alice',
        'preferred_traits': '["清爽","木质"]',
        'disliked_traits': '["甜"]',
        'candidate_scores': '[]',
        'confidence': .8,
        'reason': '近期反馈稳定',
        'status': 'ready',
        'updated_at': now,
      });
      final profile = await ScentProfileService(db).load('alice');
      expect(profile.useCount, 2);
      expect(profile.totalSeconds, 1200);
      expect(profile.commonCombinations.single.count, 2);
      expect(profile.commonCombinations.single.name, '薄荷 + 雪松');
      expect(profile.preferenceTrend.single.liking, 5);
      expect(profile.preferredTraits, ['清爽', '木质']);
      expect(profile.dislikedTraits, ['甜']);
      expect(profile.aiConfidence, .8);
    },
  );
}
