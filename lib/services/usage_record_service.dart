import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/usage_record.dart';
import 'fan_scent_service.dart';

/// 使用记录服务 - 自动记录单个风扇开关行为
/// 使用统一的 AppDatabase
class UsageRecordService {
  // 存储每个风扇的活跃记录 {fanId: UsageRecord}
  static Map<int, UsageRecord> _activeRecords = {};

  /// 获取数据库
  static Future<Database> get _database async => AppDatabase().database;

  /// 开始记录 - 开启单个风扇时调用
  static Future<void> startRecord(int fanId) async {
    if (fanId < 1 || fanId > 4) return;

    try {
      // 如果该风扇已有未结束的记录，先结束它
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

      print('📊 开始记录风扇$fanId: $scentName');
    } catch (e) {
      print('开始记录失败: $e');
    }
  }

  /// 结束记录 - 关闭单个风扇时调用
  static Future<UsageRecord?> endRecord(int fanId) async {
    if (!_activeRecords.containsKey(fanId)) return null;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final record = _activeRecords[fanId]!;
      final duration = ((now - record.startTime) / 1000).round();

      // 补全记录
      final completedRecord = record.copyWith(endTime: now, duration: duration);

      // 保存到数据库
      final db = await _database;
      final insertId = await db.insert(
        'usage_records',
        completedRecord.toMap(),
      );

      // 设置返回记录的id
      final result = completedRecord.copyWith(id: insertId);

      print('📊 结束记录风扇$fanId: 时长${duration}秒, 气味:${record.scentName}');

      _activeRecords.remove(fanId);
      return result;
    } catch (e) {
      print('结束记录失败: $e');
      _activeRecords.remove(fanId);
      return null;
    }
  }

  /// 结束所有活跃记录
  static Future<List<UsageRecord>> endAllRecords() async {
    final completedRecords = <UsageRecord>[];

    for (final fanId in List.from(_activeRecords.keys)) {
      final record = await endRecord(fanId);
      if (record != null) {
        completedRecords.add(record);
      }
    }

    return completedRecords;
  }

  /// 检查是否有进行中的记录
  static bool hasActiveRecord() => _activeRecords.isNotEmpty;

  /// 检查指定风扇是否有进行中的记录
  static bool hasActiveRecordForFan(int fanId) =>
      _activeRecords.containsKey(fanId);

  /// 获取所有进行中的记录
  static List<UsageRecord> getActiveRecords() => _activeRecords.values.toList();

  /// 获取指定风扇的进行中记录
  static UsageRecord? getActiveRecord(int fanId) => _activeRecords[fanId];

  /// 获取活跃风扇数量
  static int get activeFanCount => _activeRecords.length;

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

      return maps.map((e) => UsageRecord.fromMap(e)).toList();
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

      return maps.map((e) => UsageRecord.fromMap(e)).toList();
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

      return maps.map((e) => UsageRecord.fromMap(e)).toList();
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

  /// 根据ID列表查询记录
  static Future<List<UsageRecord>> getRecordsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    try {
      final db = await _database;
      final placeholders = ids.map((_) => '?').join(',');
      final maps = await db.query(
        'usage_records',
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );

      return maps.map((e) => UsageRecord.fromMap(e)).toList();
    } catch (e) {
      print('根据ID查询记录失败: $e');
      return [];
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

  /// 统计本周每种气味的总使用时长
  static Future<List<Map<String, dynamic>>> getWeeklyScentStats() async {
    try {
      final db = await _database;
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeek = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      ).millisecondsSinceEpoch;
      final endOfWeek = startOfWeek + 7 * 24 * 60 * 60 * 1000;
      final records = await db.query(
        'usage_records',
        where:
            'created_at >= ? AND created_at < ? AND duration IS NOT NULL AND duration > 0',
        whereArgs: [startOfWeek, endOfWeek],
      );
      final scentDurationMap = <String, int>{};
      for (final record in records) {
        final scentName = record['scent_name'] as String?;
        final duration = record['duration'] as int?;
        if (scentName != null &&
            scentName.isNotEmpty &&
            duration != null &&
            duration > 0) {
          scentDurationMap[scentName] =
              (scentDurationMap[scentName] ?? 0) + duration;
        }
      }
      final result =
          scentDurationMap.entries
              .map(
                (entry) => {
                  'scent_name': entry.key,
                  'total_duration': entry.value,
                },
              )
              .toList()
            ..sort(
              (a, b) => (b['total_duration'] as int).compareTo(
                a['total_duration'] as int,
              ),
            );
      return result;
    } catch (e) {
      print('统计本周气味使用时长失败: $e');
      return [];
    }
  }
}

/// 气味瞬间记录服务 - 存储弹窗收集的数据
class SmellMomentRecordService {
  /// 获取数据库
  static Future<Database> get _database async => AppDatabase().database;

  /// 保存气味瞬间记录
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

      final id = await db.insert('smell_moment_record', {
        'title': title ?? '未命名',
        'scene_tag': sceneTag,
        'emotion_emoji': emotionEmoji,
        'note': note,
        'scent_combo': scentCombo,
        'score': score,
        'created_at': now,
      });

      print('📝 保存气味瞬间记录: title=$title, scentCombo=$scentCombo, score=$score');
      return id;
    } catch (e) {
      print('保存气味瞬间记录失败: $e');
      return -1;
    }
  }

  /// 查询所有气味瞬间记录
  static Future<List<Map<String, dynamic>>> getAllRecords() async {
    try {
      final db = await _database;
      return await db.query('smell_moment_record', orderBy: 'created_at DESC');
    } catch (e) {
      print('查询气味瞬间记录失败: $e');
      return [];
    }
  }

  /// 根据使用记录ID查询气味瞬间记录
  static Future<List<Map<String, dynamic>>> getByUsageRecordId(
    int usageRecordId,
  ) async {
    try {
      final db = await _database;
      return await db.query(
        'smell_moment_record',
        where: 'usage_record_ids LIKE ?',
        whereArgs: ['%$usageRecordId%'],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      print('查询气味瞬间记录失败: $e');
      return [];
    }
  }

  /// 获取上次气味瞬间记录的时间戳（用于判定"本次使用"的起始时间）
  /// 如果没有历史记录，返回0（表示获取所有今日记录）
  static Future<int> getLastMomentRecordTimestamp() async {
    try {
      final db = await _database;
      final result = await db.query(
        'smell_moment_record',
        columns: ['created_at'],
        orderBy: 'created_at DESC',
        limit: 1,
      );
      if (result.isNotEmpty) {
        return result.first['created_at'] as int;
      }
      return 0;
    } catch (e) {
      print('获取上次气味瞬间记录时间戳失败: $e');
      return 0;
    }
  }

  /// 查询今日记录
  static Future<List<Map<String, dynamic>>> getTodayRecords() async {
    try {
      final db = await _database;
      final now = DateTime.now();
      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).millisecondsSinceEpoch;
      final endOfDay = startOfDay + 24 * 60 * 60 * 1000;

      return await db.query(
        'smell_moment_record',
        where: 'created_at >= ? AND created_at < ?',
        whereArgs: [startOfDay, endOfDay],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      print('查询今日气味瞬间记录失败: $e');
      return [];
    }
  }
}

/// 卡片触发记录服务
class CardTriggerRecordService {
  /// 获取数据库
  static Future<Database> get _database async => AppDatabase().database;

  /// 记录一次卡片弹出事件
  static Future<int> insertRecord() async {
    try {
      final db = await _database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await db.insert('card_trigger_records', {'created_at': now});
      print('📝 记录卡片弹出事件成功: id=$id');
      return id;
    } catch (e) {
      print('记录卡片弹出事件失败: $e');
      return -1;
    }
  }

  /// 查询本周的卡片触发记录数量
  static Future<int> getWeekRecordCount() async {
    try {
      final db = await _database;
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeek = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      ).millisecondsSinceEpoch;
      final endOfWeek = startOfWeek + 7 * 24 * 60 * 60 * 1000;

      final result = await db.rawQuery(
        '''
        SELECT COUNT(*) as count FROM card_trigger_records
        WHERE created_at >= ? AND created_at < ?
      ''',
        [startOfWeek, endOfWeek],
      );

      if (result.isNotEmpty) {
        return result.first['count'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      print('查询本周卡片触发记录失败: $e');
      return 0;
    }
  }
}
