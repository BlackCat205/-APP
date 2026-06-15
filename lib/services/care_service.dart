import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';

/// 关怀服务：每周定时检查用户情绪记录，生成关怀提醒。
class CareService {
  static const String _lastCareKey = 'last_care_date';
  static const String _careRecordsKey = 'care_records';

  /// 检查是否需要触发关怀。每周最多触发一次。
  static Future<Map<String, dynamic>?> checkCare() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 本周已触发过则跳过
      final lastCareStr = prefs.getString(_lastCareKey);
      if (lastCareStr != null) {
        final lastCare = DateTime.parse(lastCareStr);
        final now = DateTime.now();
        if (lastCare.year == now.year && lastCare.weekOfYear == now.weekOfYear) {
          return null;
        }
      }

      final db = await AppDatabase().database;
      final records = await db.query(
        'smell_moment_record',
        orderBy: 'created_at DESC',
      );

      if (records.isEmpty) return null;

      final careResult = _evaluateRules(records);
      if (careResult != null) {
        await _recordCare(careResult);
        await prefs.setString(_lastCareKey, DateTime.now().toIso8601String());
        return careResult;
      }

      return null;
    } catch (e) {
      debugPrint('检查关怀失败: $e');
      return null;
    }
  }

  /// 根据最近7天的记录，按优先级返回匹配的关怀规则。
  static Map<String, dynamic>? _evaluateRules(
      List<Map<String, dynamic>> records,
      ) {
    final recordsByDate = _groupByDate(records);
    final recentDates = _getRecentDates(7);
    final recentRecords = recentDates
        .where((date) => recordsByDate.containsKey(date))
        .map((date) => recordsByDate[date]!)
        .toList();

    // 规则按优先级排序
    if (_checkConsecutiveEmotion(recentRecords, ['😤', '😭'], 3)) {
      return const {
        'type': 'emotion_low',
        'message': '最近是不是有不少烦心事？檀香和薰衣草在等你，它们很擅长倾听。',
        'scene': '疲惫舒缓',
      };
    }

    if (_checkConsecutiveScene(recentRecords, '疲惫舒缓', 3)) {
      return const {
        'type': 'stress',
        'message': '你的肩膀扛了很多东西吧。给自己5分钟，让雪松替你撑一会儿。',
        'scene': '疲惫舒缓',
      };
    }

    if (_checkSceneCount(recentRecords, '助眠安神', 5)) {
      return const {
        'type': 'sleep',
        'message': '你最近找它找得很勤，是不是睡眠不太安稳？今晚试试让它陪你久一点。',
        'scene': '助眠安神',
      };
    }

    if (_getWeeklyCount(recentRecords) < 3) {
      return const {
        'type': 'missing',
        'message': '你好几天没来了。别忘了，这里永远有一盏闻得到的温暖给你留着。',
        'scene': '疲惫舒缓',
      };
    }

    return null;
  }

  // ---------- 数据预处理 ----------

  /// 按日期（yyyy-MM-dd）分组记录
  static Map<String, List<Map<String, dynamic>>> _groupByDate(
      List<Map<String, dynamic>> records,
      ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final record in records) {
      final timestamp = record['created_at'] as int?;
      if (timestamp == null) continue;
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(record);
    }
    return grouped;
  }

  /// 获取最近 [days] 天的日期字符串列表，从最早到最新
  static List<String> _getRecentDates(int days) {
    final now = DateTime.now();
    final dates = <String>[];
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      dates.add(_formatDate(date));
    }
    return dates.reversed.toList();
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ---------- 规则判断 ----------

  /// 连续 [days] 天中每天都有出现在 [emotions] 中的情绪
  static bool _checkConsecutiveEmotion(
      List<List<Map<String, dynamic>>> records,
      List<String> emotions,
      int days,
      ) {
    if (records.length < days) return false;
    int consecutive = 0;
    for (final dayRecords in records) {
      final has = dayRecords.any((r) {
        final emoji = r['emotion_emoji'] as String?;
        return emoji != null && emotions.contains(emoji);
      });
      if (has) {
        consecutive++;
        if (consecutive >= days) return true;
      } else {
        consecutive = 0;
      }
    }
    return false;
  }

  /// 连续 [days] 天中每天都有指定的 [scene]
  static bool _checkConsecutiveScene(
      List<List<Map<String, dynamic>>> records,
      String scene,
      int days,
      ) {
    if (records.length < days) return false;
    int consecutive = 0;
    for (final dayRecords in records) {
      final has = dayRecords.any((r) {
        final s = r['scene_tag'] as String?;
        return s != null && s == scene;
      });
      if (has) {
        consecutive++;
        if (consecutive >= days) return true;
      } else {
        consecutive = 0;
      }
    }
    return false;
  }

  /// 最近7天内指定场景的总记录数是否达到 [count]
  static bool _checkSceneCount(
      List<List<Map<String, dynamic>>> records,
      String scene,
      int count,
      ) {
    int total = 0;
    for (final dayRecords in records) {
      total += dayRecords.where((r) {
        final s = r['scene_tag'] as String?;
        return s != null && s == scene;
      }).length;
    }
    return total >= count;
  }

  /// 最近7天的总记录数
  static int _getWeeklyCount(List<List<Map<String, dynamic>>> records) {
    return records.fold<int>(0, (sum, day) => sum + day.length);
  }

  // ---------- 持久化 ----------

  /// 将触发的关怀记录存储到本地
  static Future<void> _recordCare(Map<String, dynamic> care) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_careRecordsKey) ?? [];
      final entry = {
        'timestamp': DateTime.now().toIso8601String(),
        'type': care['type'],
        'message': care['message'],
        'scene': care['scene'],
      };
      rawList.add(json.encode(entry));
      await prefs.setStringList(_careRecordsKey, rawList);
    } catch (e) {
      debugPrint('记录关怀失败: $e');
    }
  }

  /// 获取所有历史关怀记录（倒序）
  static Future<List<Map<String, dynamic>>> getCareHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_careRecordsKey) ?? [];
      return rawList
          .map((str) {
        try {
          return json.decode(str) as Map<String, dynamic>;
        } catch (_) {
          return null;
        }
      })
          .whereType<Map<String, dynamic>>()
          .toList()
          .reversed
          .toList();
    } catch (e) {
      debugPrint('获取关怀历史失败: $e');
      return [];
    }
  }
}

extension DateTimeExtension on DateTime {
  /// 一年中的第几周（从1开始）
  int get weekOfYear {
    final firstDay = DateTime(year, 1, 1);
    final daysSince = difference(firstDay).inDays;
    return (daysSince ~/ 7) + 1;
  }
}