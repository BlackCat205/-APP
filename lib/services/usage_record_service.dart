import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/usage_record.dart';
import 'fan_scent_service.dart';

/// 使用记录服务 — 自动记录单个风扇开关行为
class UsageRecordService {
  // ========== 活跃记录缓存 ==========
  static final Map<int, UsageRecord> _activeRecords = {};

  // ========== 表/字段常量 ==========
  static const String _table = 'usage_records';
  static const String _colStartTime = 'start_time';
  static const String _colEndTime = 'end_time';
  static const String _colDuration = 'duration';
  static const String _colFanId = 'fan_id';
  static const String _colScentName = 'scent_name';
  static const String _colCreatedAt = 'created_at';

  /// 获取数据库实例（统一使用 AppDatabase 单例）
  static Future<Database> get _database async => AppDatabase().database;

  // ---------- 记录生命周期 ----------

  /// 开始记录 — 风扇开启时调用
  static Future<void> startRecord(int fanId) async {
    if (fanId < 1 || fanId > 4) return;

    try {
      // 如果已有未结束的记录则先关闭
      if (_activeRecords.containsKey(fanId)) {
        await endRecord(fanId);
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final scentName = FanScentService.getFanScent(fanId);

      _activeRecords[fanId] = UsageRecord(
        startTime: now,
        fanId: fanId,
        scentName: scentName,
        createdAt: now,
      );
      debugPrint('📊 开始记录风扇$fanId: $scentName');
    } catch (e) {
      debugPrint('开始记录失败: $e');
    }
  }

  /// 结束记录 — 风扇关闭时调用，返回完整记录（含 id）
  static Future<UsageRecord?> endRecord(int fanId) async {
    if (!_activeRecords.containsKey(fanId)) return null;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final record = _activeRecords[fanId]!;
      final duration = ((now - record.startTime) / 1000).round();

      // 补全结束信息
      final completed = record.copyWith(endTime: now, duration: duration);

      // 持久化
      final db = await _database;
      final insertId = await db.insert(_table, completed.toMap());

      // 返回带有数据库 id 的记录
      final result = completed.copyWith(id: insertId);
      debugPrint('📊 结束记录风扇$fanId: 时长$duration秒, 气味:${record.scentName}');

      _activeRecords.remove(fanId);
      return result;
    } catch (e) {
      debugPrint('结束记录失败: $e');
      _activeRecords.remove(fanId);
      return null;
    }
  }

  /// 结束所有活跃记录并返回刚刚结束的记录列表
  static Future<List<UsageRecord>> endAllRecords() async {
    final completed = <UsageRecord>[];
    for (final fanId in List<int>.from(_activeRecords.keys)) {
      final record = await endRecord(fanId);
      if (record != null) completed.add(record);
    }
    return completed;
  }

  // ---------- 状态查询 ----------

  static bool hasActiveRecord() => _activeRecords.isNotEmpty;
  static bool hasActiveRecordForFan(int fanId) =>
      _activeRecords.containsKey(fanId);
  static List<UsageRecord> getActiveRecords() =>
      _activeRecords.values.toList();
  static UsageRecord? getActiveRecord(int fanId) => _activeRecords[fanId];
  static int get activeFanCount => _activeRecords.length;

  // ---------- 查询接口 ----------

  /// 查询今日记录
  static Future<List<UsageRecord>> getTodayRecords() async {
    try {
      final (start, end) = _getDayRange(DateTime.now());
      return await _queryRecords(start, end);
    } catch (e) {
      debugPrint('查询今日记录失败: $e');
      return [];
    }
  }

  /// 查询本周记录
  static Future<List<UsageRecord>> getWeekRecords() async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final (start, end) = _getWeekRange(weekStart);
      return await _queryRecords(start, end);
    } catch (e) {
      debugPrint('查询本周记录失败: $e');
      return [];
    }
  }

  /// 查询最近 [limit] 条记录（默认 100）
  static Future<List<UsageRecord>> getAllRecords({int limit = 100}) async {
    try {
      final db = await _database;
      final maps = await db.query(
        _table,
        orderBy: '$_colStartTime DESC',
        limit: limit,
      );
      return maps.map(UsageRecord.fromMap).toList();
    } catch (e) {
      debugPrint('查询所有记录失败: $e');
      return [];
    }
  }

  /// 根据 ID 列表查询
  static Future<List<UsageRecord>> getRecordsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    try {
      final db = await _database;
      final placeholders = List.filled(ids.length, '?').join(',');
      final maps = await db.query(
        _table,
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
      return maps.map(UsageRecord.fromMap).toList();
    } catch (e) {
      debugPrint('根据ID查询记录失败: $e');
      return [];
    }
  }

  /// 删除指定记录
  static Future<void> deleteRecord(int id) async {
    try {
      final db = await _database;
      await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('删除记录失败: $e');
    }
  }

  // ---------- 统计接口 ----------

  /// 今日总使用时长（秒）
  static Future<int> getTodayTotalDuration() async {
    try {
      final records = await getTodayRecords();
      return records.fold<int>(0, (sum, r) => sum + (r.duration ?? 0));
    } catch (e) {
      debugPrint('获取今日总时长失败: $e');
      return 0;
    }
  }

  /// 本周总使用时长（秒）
  static Future<int> getWeekTotalDuration() async {
    try {
      final records = await getWeekRecords();
      return records.fold<int>(0, (sum, r) => sum + (r.duration ?? 0));
    } catch (e) {
      debugPrint('获取本周总时长失败: $e');
      return 0;
    }
  }

  /// 本周每种气味的使用时长统计（按总时长降序）
  static Future<List<Map<String, dynamic>>> getWeeklyScentStats() async {
    try {
      final db = await _database;
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final (start, end) = _getWeekRange(weekStart);

      final records = await db.query(
        _table,
        where:
        '$_colCreatedAt >= ? AND $_colCreatedAt < ? AND $_colDuration IS NOT NULL AND $_colDuration > 0',
        whereArgs: [start, end],
      );

      final scentDuration = <String, int>{};
      for (final row in records) {
        final name = row[_colScentName] as String?;
        final dur = row[_colDuration] as int?;
        if (name != null && name.isNotEmpty && dur != null && dur > 0) {
          scentDuration[name] = (scentDuration[name] ?? 0) + dur;
        }
      }

      final result = scentDuration.entries
          .map((e) => {'scent_name': e.key, 'total_duration': e.value})
          .toList()
        ..sort((a, b) =>
            (b['total_duration'] as int).compareTo(a['total_duration'] as int));

      return result;
    } catch (e) {
      debugPrint('统计本周气味使用时长失败: $e');
      return [];
    }
  }

  // ---------- 工具方法 ----------

  /// 根据时间区间查询记录（按开始时间倒序）
  static Future<List<UsageRecord>> _queryRecords(int startMs, int endMs) async {
    final db = await _database;
    final maps = await db.query(
      _table,
      where: '$_colStartTime >= ? AND $_colStartTime < ?',
      whereArgs: [startMs, endMs],
      orderBy: '$_colStartTime DESC',
    );
    return maps.map(UsageRecord.fromMap).toList();
  }

  /// 获取某天的起止毫秒时间戳
  static (int start, int end) _getDayRange(DateTime date) {
    final start = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    return (start, start + const Duration(days: 1).inMilliseconds);
  }

  /// 获取从 [weekStart] 开始的一周起止毫秒时间戳
  static (int start, int end) _getWeekRange(DateTime weekStart) {
    final startOfWeek = DateTime(weekStart.year, weekStart.month, weekStart.day)
        .millisecondsSinceEpoch;
    return (startOfWeek, startOfWeek + const Duration(days: 7).inMilliseconds);
  }
}

// ============================================================
// 气味瞬间记录服务
// ============================================================

class SmellMomentRecordService {
  static const String _table = 'smell_moment_record';
  static const String _colCreatedAt = 'created_at';

  static Future<Database> get _database async => AppDatabase().database;

  /// 插入一条气味瞬间记录
  static Future<int> insertRecord({
    String? title,
    String? sceneTag,
    String? emotionEmoji,
    String? note,
    String? scentCombo,
    int? score,
  }) async {
    try {
      final db = await _database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await db.insert(_table, {
        'title': title ?? '未命名',
        'scene_tag': sceneTag,
        'emotion_emoji': emotionEmoji,
        'note': note,
        'scent_combo': scentCombo,
        'score': score,
        _colCreatedAt: now,
      });
      debugPrint('📝 保存气味瞬间记录: title=$title, scentCombo=$scentCombo, score=$score');
      return id;
    } catch (e) {
      debugPrint('保存气味瞬间记录失败: $e');
      return -1;
    }
  }

  /// 查询所有气味瞬间记录（倒序）
  static Future<List<Map<String, dynamic>>> getAllRecords() async {
    try {
      final db = await _database;
      return await db.query(_table, orderBy: '$_colCreatedAt DESC');
    } catch (e) {
      debugPrint('查询气味瞬间记录失败: $e');
      return [];
    }
  }

  /// 根据使用记录 ID 查询关联的气味瞬间记录（模糊查询 usage_record_ids）
  static Future<List<Map<String, dynamic>>> getByUsageRecordId(
      int usageRecordId,
      ) async {
    try {
      final db = await _database;
      return await db.query(
        _table,
        where: 'usage_record_ids LIKE ?',
        whereArgs: ['%$usageRecordId%'],
        orderBy: '$_colCreatedAt DESC',
      );
    } catch (e) {
      debugPrint('查询气味瞬间记录失败: $e');
      return [];
    }
  }

  /// 获取最近一次气味瞬间记录的时间戳，若无则返回 0
  static Future<int> getLastMomentRecordTimestamp() async {
    try {
      final db = await _database;
      final result = await db.query(
        _table,
        columns: [_colCreatedAt],
        orderBy: '$_colCreatedAt DESC',
        limit: 1,
      );
      if (result.isNotEmpty) {
        return result.first[_colCreatedAt] as int;
      }
      return 0;
    } catch (e) {
      debugPrint('获取上次气味瞬间记录时间戳失败: $e');
      return 0;
    }
  }

  /// 查询今日气味瞬间记录
  static Future<List<Map<String, dynamic>>> getTodayRecords() async {
    try {
      final db = await _database;
      final now = DateTime.now();
      final start =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final end = start + const Duration(days: 1).inMilliseconds;
      return await db.query(
        _table,
        where: '$_colCreatedAt >= ? AND $_colCreatedAt < ?',
        whereArgs: [start, end],
        orderBy: '$_colCreatedAt DESC',
      );
    } catch (e) {
      debugPrint('查询今日气味瞬间记录失败: $e');
      return [];
    }
  }
}

// ============================================================
// 卡片触发记录服务
// ============================================================

class CardTriggerRecordService {
  static const String _table = 'card_trigger_records';
  static const String _colCreatedAt = 'created_at';

  static Future<Database> get _database async => AppDatabase().database;

  /// 插入一条卡片弹出事件
  static Future<int> insertRecord() async {
    try {
      final db = await _database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await db.insert(_table, {_colCreatedAt: now});
      debugPrint('📝 记录卡片弹出事件成功: id=$id');
      return id;
    } catch (e) {
      debugPrint('记录卡片弹出事件失败: $e');
      return -1;
    }
  }

  /// 查询本周卡片触发次数
  static Future<int> getWeekRecordCount() async {
    try {
      final db = await _database;
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final start =
          DateTime(weekStart.year, weekStart.month, weekStart.day)
              .millisecondsSinceEpoch;
      final end = start + const Duration(days: 7).inMilliseconds;

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_table WHERE $_colCreatedAt >= ? AND $_colCreatedAt < ?',
        [start, end],
      );

      if (result.isNotEmpty) {
        return result.first['count'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('查询本周卡片触发记录失败: $e');
      return 0;
    }
  }
}