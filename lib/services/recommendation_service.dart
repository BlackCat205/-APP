import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/recommendation.dart';
import 'behavior_scoring_service.dart';
import 'scent_catalog.dart';

abstract class RecommendationSource {
  Future<RecommendationReport> recommend(String userId);
}

/// SQLite 快照 -> 可靠组合区间 -> 纯行为评分。没有网络或 BLE 依赖。
class RecommendationService implements RecommendationSource {
  RecommendationService({
    required this.db,
    required this.configuration,
    DateTime Function()? clock,
    this.scoring = const BehaviorScoringService(),
  }) : clock = clock ?? DateTime.now;
  final Database db;
  final Map<int, String> Function() configuration;
  final DateTime Function() clock;
  final BehaviorScoringService scoring;

  // 只容忍很短的逐路开关过渡；整次反馈最多归属一个组合。
  static const dominantCoverage = .9;
  static const maxTransitionMilliseconds = 10000;
  static const supportedSources = {
    'app_command_unverified',
    'recommendation_simulation',
  };

  @override
  Future<RecommendationReport> recommend(String userId) async {
    final candidates = ScentCatalog.candidates(Map.of(configuration()));
    final now = clock();
    final data = await db.transaction((txn) async {
      final sessions = await txn.rawQuery(
        '''SELECT s.*, f.liking, f.after_state,
        f.reuse_intent FROM usage_sessions s
        LEFT JOIN usage_feedback f ON f.session_id = s.id WHERE s.user_id = ?''',
        [userId],
      );
      final records = await txn.rawQuery(
        '''SELECT r.* FROM usage_records r
        JOIN usage_sessions s ON s.id = r.session_id WHERE s.user_id = ?
        ORDER BY r.start_time, r.id''',
        [userId],
      );
      final profiles = await txn.query(
        'preference_profiles',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      return (sessions, records, profiles);
    });
    final bySession = <String, List<Map<String, Object?>>>{};
    for (final row in data.$2) {
      bySession.putIfAbsent(row['session_id'] as String, () => []).add(row);
    }
    final observations = <String, List<BehaviorObservation>>{};
    var excluded = 0;
    for (final session in data.$1) {
      final rows = bySession[session['id']] ?? [];
      Map<String, int>? durations;
      try {
        durations = _durations(session, rows, now);
      } catch (_) {
        excluded++;
        continue;
      }
      if (durations == null) {
        excluded++;
        continue;
      }
      final total = durations.values.fold<int>(0, (a, b) => a + b);
      final dominant = durations.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      final coverage = dominant.value / total;
      final canAttribute =
          coverage >= dominantCoverage &&
          total - dominant.value <= maxTransitionMilliseconds;
      for (final entry in durations.entries) {
        observations
            .putIfAbsent(entry.key, () => [])
            .add(
              BehaviorObservation(
                sessionId: session['id'] as String,
                endTime: DateTime.fromMillisecondsSinceEpoch(
                  session['end_time'] as int,
                ),
                seconds: entry.value / 1000,
                feedbackCoverage: canAttribute && entry.key == dominant.key
                    ? coverage
                    : 0,
                liking: _integer(session['liking']),
                before: _integer(session['before_state']),
                after: _integer(session['after_state']),
                beforeSource: session['before_state_source']?.toString(),
                reuseIntent: _integer(session['reuse_intent']),
              ),
            );
      }
    }
    final ai = _aiProfile(
      data.$3.isEmpty ? null : data.$3.single,
      candidates.map((candidate) => candidate.id).toSet(),
    );
    final results = candidates.map((candidate) {
      final behavior = scoring.score(
        candidate,
        observations[candidate.id] ?? [],
        now,
      );
      return Recommendation(
        candidate: behavior.candidate,
        behaviorScore: behavior.behaviorScore,
        useCount: behavior.useCount,
        feedbackCount: behavior.feedbackCount,
        effectiveEvidence: behavior.effectiveEvidence,
        components: behavior.components,
        reason: behavior.reason,
        aiScore: ai?.scores[candidate.id],
        aiConfidence: ai?.confidence,
        aiReason: ai?.reason,
      );
    }).toList();
    results.sort((a, b) {
      if (a.isVerified != b.isVerified) return a.isVerified ? -1 : 1;
      final score = (b.overallScore ?? 0).compareTo(a.overallScore ?? 0);
      if (score != 0) return score;
      final count = a.candidate.fans.length.compareTo(b.candidate.fans.length);
      return count != 0 ? count : a.candidate.id.compareTo(b.candidate.id);
    });
    return RecommendationReport(
      userId: userId,
      generatedAt: now,
      recommendations: results,
      excludedSessions: excluded,
    );
  }

  static int? _integer(Object? value) => value is int ? value : null;

  static _AiProfile? _aiProfile(
    Map<String, Object?>? row,
    Set<String> expectedCandidates,
  ) {
    if (row == null ||
        row['status'] != 'ready' ||
        row['candidate_version']?.toString() !=
            row['input_version']?.toString() ||
        row['confidence'] is! num ||
        row['reason'] is! String) {
      return null;
    }
    try {
      final raw = jsonDecode(row['candidate_scores'] as String);
      if (raw is! List) return null;
      final scores = <String, double>{};
      for (final item in raw) {
        if (item is! Map ||
            item['candidate_id'] is! String ||
            item['score'] is! num) {
          return null;
        }
        final score = (item['score'] as num).toDouble();
        if (score < 0 || score > 100) return null;
        final id = item['candidate_id'] as String;
        if (scores.containsKey(id)) return null;
        scores[id] = score;
      }
      if (scores.keys.toSet().difference(expectedCandidates).isNotEmpty ||
          expectedCandidates.difference(scores.keys.toSet()).isNotEmpty) {
        return null;
      }
      return _AiProfile(
        scores,
        (row['confidence'] as num).toDouble(),
        row['reason'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  /// 扫描实际起止区间，不能把分别用过 A、B 当成用过 A+B。
  Map<String, int>? _durations(
    Map<String, Object?> session,
    List<Map<String, Object?>> rows,
    DateTime now,
  ) {
    // 删除或改写了其中一路记录时，不能把原组合的反馈归给剩下的气味。
    try {
      final snapshot = jsonDecode(session['scent_snapshot'] as String);
      if (snapshot is! List || snapshot.length != rows.length) return null;
      final indexed = {for (final row in rows) row['id']: row};
      final seen = <Object?>{};
      for (final entry in snapshot) {
        if (entry is! Map || !seen.add(entry['id'])) return null;
        final current = indexed[entry['id']];
        if (current == null) return null;
        for (final field in [
          'fan_id',
          'scent_name',
          'start_time',
          'end_time',
          'duration',
          'source',
          'status',
        ]) {
          if (entry[field] != current[field]) return null;
        }
      }
    } catch (_) {
      return null;
    }
    final start = session['start_time'] as int?;
    final end = session['end_time'] as int?;
    if (session['status'] != 'completed_unverified' ||
        !supportedSources.contains(session['source']) ||
        start == null ||
        end == null ||
        start < 0 ||
        end <= start ||
        end > now.millisecondsSinceEpoch ||
        session['duration'] != (end - start) ~/ 1000 ||
        rows.isEmpty) {
      return null;
    }
    final boundaries = <int>{start, end};
    for (final row in rows) {
      final a = row['start_time'] as int?;
      final b = row['end_time'] as int?;
      final fan = row['fan_id'] as int?;
      if (row['status'] != 'completed_unverified' ||
          row['source'] != session['source'] ||
          a == null ||
          b == null ||
          b <= a ||
          a < start ||
          b > end ||
          row['duration'] != (b - a) ~/ 1000 ||
          fan == null ||
          fan < 1 ||
          fan > 4 ||
          ScentCatalog.key([row['scent_name'] as String? ?? '']) == null) {
        return null;
      }
      boundaries.addAll([a, b]);
    }
    final sorted = boundaries.toList()..sort();
    final result = <String, int>{};
    for (var i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i], b = sorted[i + 1];
      final active = rows
          .where(
            (r) => (r['start_time'] as int) <= a && (r['end_time'] as int) >= b,
          )
          .toList();
      if (active.isEmpty ||
          active.map((r) => r['fan_id']).toSet().length != active.length) {
        return null;
      }
      final key = ScentCatalog.key(
        active.map((r) => r['scent_name'] as String),
      )!;
      result.update(key, (value) => value + b - a, ifAbsent: () => b - a);
    }
    return result.isEmpty ? null : result;
  }
}

class _AiProfile {
  const _AiProfile(this.scores, this.confidence, this.reason);
  final Map<String, double> scores;
  final double confidence;
  final String reason;
}
