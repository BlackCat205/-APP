import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 关怀服务
class CareService {
  static const String _usageKey = 'smell_usage_records';
  static const String _careKey = 'care_records';
  static const String _lastCareKey = 'last_care_date';

  /// 记录气味使用行为
  static Future<void> recordUsage({
    required String scene,
    required String emotion,
    required int duration,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usageRecords = prefs.getStringList(_usageKey) ?? [];

      final record = {
        'timestamp': DateTime.now().toIso8601String(),
        'scene': scene,
        'emotion': emotion,
        'duration': duration,
      };

      usageRecords.add(json.encode(record));
      await prefs.setStringList(_usageKey, usageRecords);
    } catch (e) {
      print('记录使用行为失败: $e');
    }
  }

  /// 检查是否需要触发关怀
  static Future<Map<String, dynamic>?> checkCare() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 检查是否已经在本周触发过
      final lastCareStr = prefs.getString(_lastCareKey);
      if (lastCareStr != null) {
        final lastCare = DateTime.parse(lastCareStr);
        final now = DateTime.now();
        if (lastCare.year == now.year &&
            lastCare.weekOfYear == now.weekOfYear) {
          return null; // 本周已经触发过
        }
      }

      // 检查是否到达触发时间（周日 20:00）
      final now = DateTime.now();
      if (now.weekday != DateTime.sunday || now.hour != 20 || now.minute != 0) {
        return null; // 未到达触发时间
      }

      // 加载使用记录
      final usageRecords = prefs.getStringList(_usageKey) ?? [];
      if (usageRecords.isEmpty) {
        return null; // 无使用记录
      }

      // 解析使用记录
      final records = usageRecords
          .map((str) {
            try {
              return json.decode(str) as Map<String, dynamic>;
            } catch (e) {
              return null;
            }
          })
          .where((r) => r != null)
          .toList();

      if (records.isEmpty) {
        return null;
      }

      // 规则引擎判断
      final careResult = _evaluateRules(records.cast<Map<String, dynamic>>());
      if (careResult != null) {
        // 记录关怀触发
        await _recordCare(careResult);
        // 更新最后关怀时间
        await prefs.setString(_lastCareKey, DateTime.now().toIso8601String());
        return careResult;
      }

      return null;
    } catch (e) {
      print('检查关怀失败: $e');
      return null;
    }
  }

  /// 规则引擎
  static Map<String, dynamic>? _evaluateRules(
    List<Map<String, dynamic>> records,
  ) {
    // 按日期分组
    final recordsByDate = <String, List<Map<String, dynamic>>>{};
    for (final record in records) {
      final timestamp = record['timestamp'] as String;
      final date = timestamp.split('T')[0];
      if (!recordsByDate.containsKey(date)) {
        recordsByDate[date] = [];
      }
      recordsByDate[date]!.add(record);
    }

    // 获取最近7天的日期
    final recentDates = _getRecentDates(7);
    final recentRecords = recentDates
        .where((date) => recordsByDate.containsKey(date))
        .map((date) => recordsByDate[date]!)
        .toList();

    // 规则1：连续3天情绪为 😤 或 😭
    if (_checkConsecutiveEmotion(recentRecords, ['😤', '😭'], 3)) {
      return {
        'type': 'emotion_low',
        'message': '最近是不是有不少烦心事？檀香和薰衣草在等你，它们很擅长倾听。',
        'scene': '疲惫舒缓',
      };
    }

    // 规则2：连续3天使用“疲惫舒缓”
    if (_checkConsecutiveScene(recentRecords, '疲惫舒缓', 3)) {
      return {
        'type': 'stress',
        'message': '你的肩膀扛了很多东西吧。给自己5分钟，让雪松替你撑一会儿。',
        'scene': '疲惫舒缓',
      };
    }

    // 规则3：一周内使用“助眠安神”≥5次
    if (_checkSceneCount(recentRecords, '助眠安神', 5)) {
      return {
        'type': 'sleep',
        'message': '你最近找它找得很勤，是不是睡眠不太安稳？今晚试试让它陪你久一点。',
        'scene': '助眠安神',
      };
    }

    // 规则4：本周使用总次数＜3次
    if (_getWeeklyCount(recentRecords) < 3) {
      return {
        'type': 'missing',
        'message': '你好几天没来了。别忘了，这里永远有一盏闻得到的温暖给你留着。',
        'scene': '疲惫舒缓',
      };
    }

    return null;
  }

  /// 检查连续情绪
  static bool _checkConsecutiveEmotion(
    List<List<Map<String, dynamic>>> records,
    List<String> emotions,
    int days,
  ) {
    if (records.length < days) return false;

    int consecutiveDays = 0;
    for (final dayRecords in records) {
      final hasEmotion = dayRecords.any((r) {
        final emotion = r['emotion'] as String?;
        return emotion != null && emotions.contains(emotion);
      });

      if (hasEmotion) {
        consecutiveDays++;
        if (consecutiveDays >= days) {
          return true;
        }
      } else {
        consecutiveDays = 0;
      }
    }

    return false;
  }

  /// 检查连续场景
  static bool _checkConsecutiveScene(
    List<List<Map<String, dynamic>>> records,
    String scene,
    int days,
  ) {
    if (records.length < days) return false;

    int consecutiveDays = 0;
    for (final dayRecords in records) {
      final hasScene = dayRecords.any((r) {
        final s = r['scene'] as String?;
        return s != null && s == scene;
      });

      if (hasScene) {
        consecutiveDays++;
        if (consecutiveDays >= days) {
          return true;
        }
      } else {
        consecutiveDays = 0;
      }
    }

    return false;
  }

  /// 检查场景使用次数
  static bool _checkSceneCount(
    List<List<Map<String, dynamic>>> records,
    String scene,
    int count,
  ) {
    int totalCount = 0;
    for (final dayRecords in records) {
      totalCount += dayRecords.where((r) {
        final s = r['scene'] as String?;
        return s != null && s == scene;
      }).length;
    }
    return totalCount >= count;
  }

  /// 获取本周使用总次数
  static int _getWeeklyCount(List<List<Map<String, dynamic>>> records) {
    return records.fold(0, (sum, dayRecords) => sum + dayRecords.length);
  }

  /// 获取最近N天的日期
  static List<String> _getRecentDates(int days) {
    final dates = <String>[];
    final now = DateTime.now();
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      dates.add(
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      );
    }
    return dates.reversed.toList();
  }

  /// 记录关怀触发
  static Future<void> _recordCare(Map<String, dynamic> care) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final careRecords = prefs.getStringList(_careKey) ?? [];

      final record = {
        'timestamp': DateTime.now().toIso8601String(),
        'type': care['type'],
        'message': care['message'],
        'scene': care['scene'],
      };

      careRecords.add(json.encode(record));
      await prefs.setStringList(_careKey, careRecords);
    } catch (e) {
      print('记录关怀失败: $e');
    }
  }

  /// 获取关怀历史记录
  static Future<List<Map<String, dynamic>>> getCareHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final careRecords = prefs.getStringList(_careKey) ?? [];

      return careRecords
          .map((str) {
            try {
              return json.decode(str) as Map<String, dynamic>;
            } catch (e) {
              return null;
            }
          })
          .where((r) => r != null)
          .cast<Map<String, dynamic>>()
          .toList()
          .reversed
          .toList();
    } catch (e) {
      print('获取关怀历史失败: $e');
      return [];
    }
  }
}

/// 扩展方法
extension DateTimeExtension on DateTime {
  int get weekOfYear {
    final firstDayOfYear = DateTime(year, 1, 1);
    final daysSinceFirstDay = difference(firstDayOfYear).inDays;
    return (daysSinceFirstDay ~/ 7) + 1;
  }
}
