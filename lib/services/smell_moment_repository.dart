import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/usage_record.dart';

/// 气味瞬间的唯一读写入口；收藏不等于硬件使用证明。
class SmellMomentRepository {
  final Database db;
  SmellMomentRepository(this.db);

  Future<int> save({
    String? title,
    String? sceneTag,
    String? emotionEmoji,
    String? note,
    String? scentCombo,
    int? score,
    List<int> usageRecordIds = const [],
  }) async {
    if (score != null && (score < 1 || score > 5)) {
      throw ArgumentError.value(score, 'score', '评分必须为 1～5');
    }
    return db.transaction((txn) async {
      final ids = usageRecordIds.toSet().toList();
      final rows = ids.isEmpty
          ? <Map<String, Object?>>[]
          : await txn.query(
              'usage_records',
              where: 'id IN (${List.filled(ids.length, '?').join(',')})',
              whereArgs: ids,
              orderBy: 'start_time ASC, id ASC',
            );
      if (rows.length != ids.length) {
        throw StateError('使用记录已变化，请重新打开收藏页面');
      }
      final records = rows.map(UsageRecord.fromMap).toList();
      final sessions = records.map((r) => r.sessionId).toSet();
      final sessionId = sessions.length == 1 ? sessions.single : null;
      final actualScents = records
          .map((r) => r.scentName)
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet();
      final source = records.any((r) => r.source == 'test')
          ? 'test'
          : records.isEmpty
          ? 'manual'
          : 'linked_usage_unverified';
      final id = await txn.insert('smell_moment_record', {
        'title': title ?? '未命名',
        'scene_tag': sceneTag,
        'emotion_emoji': emotionEmoji,
        'note': note,
        'scent_combo': records.isEmpty ? scentCombo : actualScents.join('/'),
        'score': score,
        'session_id': sessionId,
        'source': source,
        'duration_seconds': source == 'test' ? null : elapsedSeconds(records),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      for (final recordId in ids) {
        await txn.insert('moment_usage_records', {
          'moment_id': id,
          'usage_record_id': recordId,
        });
      }
      return id;
    });
  }

  Future<List<Map<String, dynamic>>> getAll() =>
      db.query('smell_moment_record', orderBy: 'created_at DESC, id DESC');

  Future<List<Map<String, dynamic>>> getByUsageRecordId(int id) => db.rawQuery(
    'SELECT m.* FROM smell_moment_record m '
    'JOIN moment_usage_records r ON r.moment_id = m.id '
    'WHERE r.usage_record_id = ? ORDER BY m.created_at DESC',
    [id],
  );

  Future<void> delete(int id) async {
    await db.delete('smell_moment_record', where: 'id = ?', whereArgs: [id]);
  }

  /// 对时间区间取并集；并行风扇不重复计时，间隔不算使用时间。
  static int? elapsedSeconds(List<UsageRecord> records) {
    if (records.isEmpty ||
        records.any(
          (r) =>
              r.source == 'test' ||
              ['interrupted', 'failed', 'active_uncertain', 'completed_estimated', 'timer_elapsed_unverified'].contains(r.status) ||
              r.endTime == null ||
              r.endTime! < r.startTime,
        )) {
      return null;
    }
    final sorted = List<UsageRecord>.of(records)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    var start = sorted.first.startTime;
    var end = sorted.first.endTime!;
    var total = 0;
    for (final record in sorted.skip(1)) {
      if (record.startTime > end) {
        total += end - start;
        start = record.startTime;
        end = record.endTime!;
      } else if (record.endTime! > end) {
        end = record.endTime!;
      }
    }
    return ((total + end - start) / 1000).floor();
  }

  static String formatDuration(int? seconds) {
    if (seconds == null) return '未记录';
    return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:'
        '${(seconds % 3600 ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }

  /// 旧偏好存储保留为备份。只导入缺少的文本，不采纳演示 recipe/duration。
  /// 每条导入及凭据在同一事务中提交，失败可重试，删除后不会再次导入。
  Future<void> importLegacy(List<String> entries) async {
    await db.transaction((txn) async {
      for (final raw in entries.toSet()) {
        final key = base64Encode(utf8.encode(raw));
        if ((await txn.query(
          'legacy_moment_imports',
          where: 'source_key = ?',
          whereArgs: [key],
        )).isNotEmpty) {
          continue;
        }
        final legacy = _parseLegacy(raw);
        final time = DateTime.tryParse(legacy['timestamp']?.toString() ?? '');
        // 无法解析的原始数据继续保留在 SharedPreferences，不伪造日期。
        if (time == null) continue;
        final timestamp = time.millisecondsSinceEpoch;
        final title = legacy['title']?.toString() ?? '未命名';
        final note = legacy['note']?.toString() ?? '';
        final scene = legacy['scene']?.toString() ?? '';
        final emoji = legacy['emoji']?.toString() ?? '';
        // 旧版先写偏好存储、紧接着写 SQLite。仅匹配唯一、尚未认领的副本。
        final matches = await txn.rawQuery(
          '''SELECT m.id FROM smell_moment_record m
          WHERE m.source = 'legacy_unknown'
          AND m.created_at BETWEEN ? AND ?
          AND COALESCE(m.title, '') = ? AND COALESCE(m.note, '') = ?
          AND COALESCE(m.scene_tag, '') = ? AND COALESCE(m.emotion_emoji, '') = ?
          AND NOT EXISTS (SELECT 1 FROM legacy_moment_imports i WHERE i.moment_id = m.id)
        ''',
          [timestamp, timestamp + 5000, title, note, scene, emoji],
        );
        final id = matches.length == 1
            ? matches.single['id'] as int
            : await txn.insert('smell_moment_record', {
                'title': title,
                'note': note,
                'scene_tag': scene,
                'emotion_emoji': emoji,
                'created_at': timestamp,
                'source': 'legacy_preferences',
              });
        await txn.insert('legacy_moment_imports', {
          'source_key': key,
          'moment_id': id,
        });
      }
    });
  }

  static Map<String, dynamic> _parseLegacy(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic>) return value;
    } catch (_) {
      // 兼容早期 Dart Map.toString() 存储格式，只抽取已知字段。
      if (!raw.startsWith('{') || !raw.endsWith('}')) return {};
      final fields = RegExp(
        r"(?:^|, )'?([a-z_]+)'?: ",
      ).allMatches(raw.substring(1, raw.length - 1)).toList();
      final body = raw.substring(1, raw.length - 1);
      return {
        for (var i = 0; i < fields.length; i++)
          fields[i].group(1)!: body.substring(
            fields[i].end,
            i + 1 < fields.length ? fields[i + 1].start : body.length,
          ),
      };
    }
    return {};
  }
}
