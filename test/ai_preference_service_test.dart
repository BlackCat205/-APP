import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:perfume_app/database/app_database.dart';
import 'package:perfume_app/models/recommendation.dart';
import 'package:perfume_app/services/ai_preference_service.dart';

class _Client implements PreferenceSemanticClient {
  _Client(this.response);
  String response;
  int calls = 0;
  String? prompt;
  @override
  Future<String> analyze(String prompt) async {
    calls++;
    this.prompt = prompt;
    return response;
  }
}

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late Database db;
  final candidate = ScentCandidate(id: 'cedar', fans: {1: '雪松'});

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ai_preference_');
    db = await AppDatabase().openAt(
      '${directory.path}/test.db',
      factory: databaseFactoryFfi,
    );
    final now = DateTime(2026).millisecondsSinceEpoch;
    await db.insert('usage_sessions', {
      'id': 's1',
      'user_id': 'alice',
      'start_time': now - 600000,
      'end_time': now,
      'duration': 600,
      'scent_snapshot': jsonEncode([
        {'fan_id': 1, 'scent_name': '雪松'},
      ]),
      'status': 'completed_unverified',
      'source': 'app_command_unverified',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('usage_feedback', {
      'session_id': 's1',
      'liking': 5,
      'after_state': 4,
      'reuse_intent': 2,
      'note': '清爽木质，不要太甜',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('preference_profiles', {
      'user_id': 'alice',
      'input_version': 1,
      'status': 'pending',
      'updated_at': now,
    });
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  test('valid structured result is versioned and cached in SQLite', () async {
    final client = _Client(
      jsonEncode({
        'preferred_traits': ['清爽', '木质'],
        'disliked_traits': ['甜'],
        'candidate_scores': [
          {'candidate_id': 'cedar', 'score': 88},
        ],
        'confidence': .8,
        'reason': '用户喜欢清爽木质并排斥甜味',
      }),
    );
    final service = AiPreferenceService(
      db: db,
      client: client,
      candidates: () => [candidate],
    );
    expect(await service.updateIfPending('alice'), isTrue);
    final row = (await db.query('preference_profiles')).single;
    expect(row['status'], 'ready');
    expect(row['candidate_version'], '1');
    expect(row['confidence'], .8);
    expect(jsonDecode(row['preferred_traits'] as String), ['清爽', '木质']);
    expect(client.prompt, contains('清爽木质，不要太甜'));
    expect(await service.updateIfPending('alice'), isFalse);
    expect(client.calls, 1);
  });

  test('invalid candidate output never replaces pending profile', () async {
    final client = _Client(
      jsonEncode({
        'preferred_traits': ['清爽'],
        'disliked_traits': [],
        'candidate_scores': [
          {'candidate_id': 'unknown', 'score': 120},
        ],
        'confidence': .9,
        'reason': 'invalid',
      }),
    );
    final service = AiPreferenceService(
      db: db,
      client: client,
      candidates: () => [candidate],
    );
    expect(await service.updateIfPending('alice'), isFalse);
    final row = (await db.query('preference_profiles')).single;
    expect(row['status'], 'pending');
    expect(row['confidence'], isNull);
  });
}
