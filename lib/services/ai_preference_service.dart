import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../models/recommendation.dart';

abstract class PreferenceSemanticClient {
  Future<String> analyze(String prompt);
}

class SparkPreferenceClient implements PreferenceSemanticClient {
  SparkPreferenceClient({
    required this.apiPassword,
    required this.modelName,
    required this.baseUrl,
    http.Client? client,
  }) : client = client ?? http.Client();
  final String apiPassword, modelName, baseUrl;
  final http.Client client;

  @override
  Future<String> analyze(String prompt) async {
    final response = await client
        .post(
          Uri.parse(baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiPassword',
          },
          body: jsonEncode({
            'model': modelName,
            'messages': [
              {
                'role': 'system',
                'content': '你只负责理解用户对气味的语义偏好。严格输出请求指定的 JSON，不输出 Markdown。',
              },
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.2,
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('AI HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body);
    final choices = body is Map ? body['choices'] : null;
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('AI 响应缺少 choices');
    }
    final message = choices.first is Map ? choices.first['message'] : null;
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw const FormatException('AI 响应为空');
    }
    return content;
  }
}

class AiPreferenceService {
  AiPreferenceService({
    required this.db,
    required this.client,
    required this.candidates,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final Database db;
  final PreferenceSemanticClient client;
  final List<ScentCandidate> Function() candidates;
  final DateTime Function() clock;
  final Set<String> _running = {};
  final Map<String, DateTime> _retryAfter = {};

  Future<bool> updateIfPending(String userId) async {
    if (_running.contains(userId)) return false;
    final retry = _retryAfter[userId];
    if (retry != null && clock().isBefore(retry)) return false;
    final profiles = await db.query(
      'preference_profiles',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (profiles.isEmpty) return false;
    final profile = profiles.single;
    final inputVersion = profile['input_version'] as int;
    final available = candidates();
    if (available.isEmpty) return false;
    final currentIds = available.map((item) => item.id).toSet();
    final storedIds = _storedCandidateIds(profile['candidate_scores']);
    if (profile['status'] == 'ready' && _sameIds(storedIds, currentIds)) {
      return false;
    }
    if (profile['status'] == 'ready') {
      await db.update(
        'preference_profiles',
        {'status': 'pending', 'updated_at': clock().millisecondsSinceEpoch},
        where: 'user_id = ? AND input_version = ?',
        whereArgs: [userId, inputVersion],
      );
    } else if (profile['status'] != 'pending') {
      return false;
    }
    final feedback = await db.rawQuery(
      '''SELECT s.id, s.scene, s.before_state, s.before_state_source,
      s.scent_snapshot, f.after_state, f.liking, f.reuse_intent, f.note
      FROM usage_sessions s JOIN usage_feedback f ON f.session_id = s.id
      WHERE s.user_id = ? AND s.status = 'completed_unverified'
      AND s.source IN ('app_command_unverified', 'recommendation_simulation')
      ORDER BY f.updated_at DESC LIMIT 30''',
      [userId],
    );
    if (feedback.isEmpty) return false;
    _running.add(userId);
    try {
      final raw = await client.analyze(_prompt(feedback, available));
      final parsed = _validate(raw, available);
      final now = clock().millisecondsSinceEpoch;
      final changed = await db.update(
        'preference_profiles',
        {
          'preferred_traits': jsonEncode(parsed.preferred),
          'disliked_traits': jsonEncode(parsed.disliked),
          'candidate_scores': jsonEncode(parsed.scores),
          'confidence': parsed.confidence,
          'reason': parsed.reason,
          'candidate_version': '$inputVersion',
          'status': 'ready',
          'updated_at': now,
        },
        where: "user_id = ? AND input_version = ? AND status = 'pending'",
        whereArgs: [userId, inputVersion],
      );
      _retryAfter.remove(userId);
      return changed == 1;
    } catch (_) {
      _retryAfter[userId] = clock().add(const Duration(minutes: 2));
      return false;
    } finally {
      _running.remove(userId);
    }
  }

  String _prompt(
    List<Map<String, Object?>> feedback,
    List<ScentCandidate> available,
  ) {
    final experiences = feedback
        .map(
          (row) => {
            'combination': _snapshotName(row['scent_snapshot']),
            'scene': row['scene'],
            'before_state': row['before_state'],
            'before_state_source': row['before_state_source'],
            'after_state': row['after_state'],
            'liking': row['liking'],
            'reuse_intent': row['reuse_intent'],
            'comment': row['note'],
          },
        )
        .toList();
    final options = available
        .map((c) => {'candidate_id': c.id, 'name': c.name})
        .toList();
    return '''分析用户对气味特征的语义偏好。数值行为分由程序计算，你不要复算行为评分。
候选组合：${jsonEncode(options)}
用户体验：${jsonEncode(experiences)}
只输出：
{"preferred_traits":["特征"],"disliked_traits":["特征"],"candidate_scores":[{"candidate_id":"候选ID","score":0到100}],"confidence":0到1,"reason":"一句话依据"}
candidate_scores 必须包含每个候选且只能使用给出的 candidate_id。标签各不超过 8 个，reason 不超过 200 字。''';
  }

  _ParsedPreference _validate(String raw, List<ScentCandidate> available) {
    final cleaned = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    final value = jsonDecode(cleaned);
    if (value is! Map) throw const FormatException('AI JSON 不是对象');
    final preferred = _traits(value['preferred_traits']);
    final disliked = _traits(value['disliked_traits']);
    final confidence = value['confidence'];
    final reason = value['reason'];
    final rawScores = value['candidate_scores'];
    if (confidence is! num ||
        confidence < 0 ||
        confidence > 1 ||
        reason is! String ||
        reason.trim().isEmpty ||
        reason.length > 200 ||
        rawScores is! List) {
      throw const FormatException('AI 字段不合法');
    }
    final allowed = {for (final item in available) item.id};
    final seen = <String>{};
    final scores = <Map<String, Object>>[];
    for (final item in rawScores) {
      if (item is! Map ||
          item['candidate_id'] is! String ||
          item['score'] is! num) {
        throw const FormatException('候选分格式不合法');
      }
      final id = item['candidate_id'] as String;
      final score = (item['score'] as num).toDouble();
      if (!allowed.contains(id) || !seen.add(id) || score < 0 || score > 100) {
        throw const FormatException('候选分内容不合法');
      }
      scores.add({'candidate_id': id, 'score': score});
    }
    if (seen.length != allowed.length) throw const FormatException('候选分不完整');
    return _ParsedPreference(
      preferred,
      disliked,
      scores,
      confidence.toDouble(),
      reason.trim(),
    );
  }

  static List<String> _traits(Object? value) {
    if (value is! List || value.length > 8 || value.any((e) => e is! String)) {
      throw const FormatException('偏好标签不合法');
    }
    final result = value
        .cast<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.length <= 20)
        .toSet()
        .toList();
    if (result.length != value.length) {
      throw const FormatException('偏好标签为空、重复或过长');
    }
    return result;
  }

  static Set<String>? _storedCandidateIds(Object? raw) {
    try {
      final list = jsonDecode(raw?.toString() ?? '[]');
      if (list is! List) return null;
      final result = <String>{};
      for (final item in list) {
        if (item is! Map ||
            item['candidate_id'] is! String ||
            !result.add(item['candidate_id'] as String)) {
          return null;
        }
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  static bool _sameIds(Set<String>? a, Set<String> b) =>
      a != null && a.length == b.length && a.containsAll(b);

  static String _snapshotName(Object? raw) {
    try {
      final list = jsonDecode(raw?.toString() ?? '[]');
      if (list is! List) return '';
      final byFan = <int, String>{};
      for (final item in list) {
        if (item is Map &&
            item['fan_id'] is int &&
            item['scent_name'] is String) {
          byFan[item['fan_id'] as int] = item['scent_name'] as String;
        }
      }
      return byFan.values.join(' + ');
    } catch (_) {
      return '';
    }
  }
}

class _ParsedPreference {
  const _ParsedPreference(
    this.preferred,
    this.disliked,
    this.scores,
    this.confidence,
    this.reason,
  );
  final List<String> preferred, disliked;
  final List<Map<String, Object>> scores;
  final double confidence;
  final String reason;
}
