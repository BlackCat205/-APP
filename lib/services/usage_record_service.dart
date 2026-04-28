import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/usage_record.dart';
import 'fan_scent_service.dart';

/// 使用记录服务 - 自动记录风扇开关行为
/// 使用统一的 AppDatabase
class UsageRecordService {
  static UsageRecord? _activeRecord;

  /// 获取数据库
  static Future<Database> get _database async => AppDatabase().database;

  /// 开始记录 - 开启风扇时调用
  static Future<void> startRecord(List<int> fanIds) async {
    if (fanIds.isEmpty) return;

    try {
      // 如果有未结束的记录，先结束它
      if (_activeRecord != null) {
        await endRecord();
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      _activeRecord = UsageRecord(
        startTime: now,
        fanIds: fanIds.join(','),
        createdAt: now,
      );

      print('📊 开始记录: 风扇${_activeRecord!.fanIds}');
    } catch (e) {
      print('开始记录失败: $e');
    }
  }

  /// 结束记录 - 关闭风扇时调用
  static Future<UsageRecord?> endRecord() async {
    if (_activeRecord == null) return null;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final duration = ((now - _activeRecord!.startTime) / 1000).round();

      // 获取气味组合
      final fanIdList = _activeRecord!.fanIds
          .split(',')
          .map(int.parse)
          .toList();
      final scents = fanIdList
          .map((id) => FanScentService.getFanScent(id))
          .toList();
      final scentCombo = scents.join('+');

      // 补全记录
      final completedRecord = _activeRecord!.copyWith(
        endTime: now,
        duration: duration,
        scentCombo: scentCombo,
      );

      // 保存到数据库
      final db = await _database;
      await db.insert('usage_records', completedRecord.toMap());

      print(
        '📊 结束记录: ${completedRecord.fanIds}, 时长${duration}秒, 气味:$scentCombo',
      );

      _activeRecord = null;
      return completedRecord;
    } catch (e) {
      print('结束记录失败: $e');
      _activeRecord = null;
      return null;
    }
  }

  /// 添加场景标签和情绪
  static Future<void> addSceneAndEmotion({
    required int recordId,
    String? sceneTag,
    String? emotionEmoji,
  }) async {
    try {
      final db = await _database;
      await db.update(
        'usage_records',
        {'scene_tag': sceneTag, 'emotion_emoji': emotionEmoji},
        where: 'id = ?',
        whereArgs: [recordId],
      );
    } catch (e) {
      print('添加场景和情绪失败: $e');
    }
  }

  /// 查询今日记录
  static Future<List<UsageRecord>> getTodayRecords() async {
    try {
      final db = await _database;
      final now = DateTime.now();
      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).millisecondsSinceEpoch;
      final endOfDay = startOfDay + 24 * 60 * 60 * 1000;

      final maps = await db.query(
        'usage_records',
        where: 'start_time >= ? AND start_time < ?',
        whereArgs: [startOfDay, endOfDay],
        orderBy: 'start_time DESC',
      );

      return maps.map((m) => UsageRecord.fromMap(m)).toList();
    } catch (e) {
      print('查询今日记录失败: $e');
      return [];
    }
  }

  /// 查询本周记录
  static Future<List<UsageRecord>> getWeekRecords() async {
    try {
      final db = await _database;
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeek = DateTime(
        monday.year,
        monday.month,
        monday.day,
      ).millisecondsSinceEpoch;
      final endOfWeek = startOfWeek + 7 * 24 * 60 * 60 * 1000;

      final maps = await db.query(
        'usage_records',
        where: 'start_time >= ? AND start_time < ?',
        whereArgs: [startOfWeek, endOfWeek],
        orderBy: 'start_time DESC',
      );

      return maps.map((m) => UsageRecord.fromMap(m)).toList();
    } catch (e) {
      print('查询本周记录失败: $e');
      return [];
    }
  }

  /// 查询所有记录
  static Future<List<UsageRecord>> getAllRecords({int limit = 100}) async {
    try {
      final db = await _database;
      final maps = await db.query(
        'usage_records',
        orderBy: 'start_time DESC',
        limit: limit,
      );

      return maps.map((m) => UsageRecord.fromMap(m)).toList();
    } catch (e) {
      print('查询所有记录失败: $e');
      return [];
    }
  }

  /// 删除记录
  static Future<void> deleteRecord(int id) async {
    try {
      final db = await _database;
      await db.delete('usage_records', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('删除记录失败: $e');
    }
  }

  /// 获取今日总使用时长（秒）
  static Future<int> getTodayTotalDuration() async {
    try {
      final records = await getTodayRecords();
      return records.fold<int>(0, (sum, r) => sum + (r.duration ?? 0));
    } catch (e) {
      print('获取今日总时长失败: $e');
      return 0;
    }
  }

  /// 获取本周总使用时长（秒）
  static Future<int> getWeekTotalDuration() async {
    try {
      final records = await getWeekRecords();
      return records.fold<int>(0, (sum, r) => sum + (r.duration ?? 0));
    } catch (e) {
      print('获取本周总时长失败: $e');
      return 0;
    }
  }

  /// 检查是否有进行中的记录
  static bool hasActiveRecord() => _activeRecord != null;

  /// 获取当前进行中的记录
  static UsageRecord? getActiveRecord() => _activeRecord;
}
