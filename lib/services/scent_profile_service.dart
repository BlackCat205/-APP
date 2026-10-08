import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/scent_profile.dart';

class ScentProfileService {
  const ScentProfileService(this.db);
  final Database db;

  Future<ScentProfile> load(String userId) async {
    final data = await db.transaction(
      (txn) async => (
        await txn.rawQuery(
          '''SELECT s.id, s.end_time, s.duration, s.scent_snapshot,
        f.liking FROM usage_sessions s LEFT JOIN usage_feedback f
        ON f.session_id = s.id WHERE s.user_id = ?
        AND s.status = 'completed_unverified'
        AND s.source IN ('app_command_unverified', 'recommendation_simulation')
        ORDER BY s.end_time''',
          [userId],
        ),
        await txn.query(
          'preference_profiles',
          where: 'user_id = ?',
          whereArgs: [userId],
          limit: 1,
        ),
      ),
    );
    final combinations = <String, (int, int)>{};
    final trend = <PreferencePoint>[];
    var totalSeconds = 0;
    var validSessions = 0;
    for (final row in data.$1) {
      final duration = row['duration'];
      final end = row['end_time'];
      if (duration is! int || duration < 0 || end is! int) continue;
      final name = _combination(row['scent_snapshot']);
      if (name == null) continue;
      validSessions++;
      totalSeconds += duration;
      final old = combinations[name] ?? (0, 0);
      combinations[name] = (old.$1 + 1, old.$2 + duration);
      final liking = row['liking'];
      if (liking is int && liking >= 1 && liking <= 5) {
        trend.add(
          PreferencePoint(
            time: DateTime.fromMillisecondsSinceEpoch(end),
            liking: liking.toDouble(),
          ),
        );
      }
    }
    final common =
        combinations.entries
            .map(
              (e) => ScentUsageSummary(
                name: e.key,
                count: e.value.$1,
                seconds: e.value.$2,
              ),
            )
            .toList()
          ..sort((a, b) {
            final byCount = b.count.compareTo(a.count);
            return byCount != 0 ? byCount : b.seconds.compareTo(a.seconds);
          });
    final profile = data.$2.isEmpty ? null : data.$2.single;
    return ScentProfile(
      useCount: validSessions,
      totalSeconds: totalSeconds,
      commonCombinations: common.take(5).toList(),
      preferenceTrend: trend.length <= 8
          ? trend
          : trend.sublist(trend.length - 8),
      preferredTraits: _strings(profile?['preferred_traits']),
      dislikedTraits: _strings(profile?['disliked_traits']),
      aiStatus: profile?['status']?.toString() ?? 'empty',
      aiConfidence: profile?['confidence'] is num
          ? (profile!['confidence'] as num).toDouble()
          : null,
      aiReason: profile?['reason']?.toString(),
      aiUpdatedAt: profile?['updated_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(profile!['updated_at'] as int)
          : null,
    );
  }

  static List<String> _strings(Object? raw) {
    try {
      final value = jsonDecode(raw?.toString() ?? '[]');
      return value is List ? value.whereType<String>().toList() : const [];
    } catch (_) {
      return const [];
    }
  }

  static String? _combination(Object? raw) {
    try {
      final decoded = jsonDecode(raw?.toString() ?? '[]');
      if (decoded is! List) return null;
      final scentsByFan = <int, String>{};
      for (final item in decoded) {
        if (item is Map && item['status'] != 'failed') {
          final scent = item['scent_name']?.toString().trim();
          final fan = item['fan_id'];
          if (fan is int && scent != null && scent.isNotEmpty) {
            scentsByFan[fan] = scent;
          }
        }
      }
      final scents = scentsByFan.values.toList();
      if (scents.isEmpty) return null;
      scents.sort();
      return scents.join(' + ');
    } catch (_) {
      return null;
    }
  }
}
