import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

/// 风扇气味配置服务（数据缓存 + 数据库持久化）
class FanScentService {
  // ---------- 可选气味列表 ----------
  static const List<String> availableScents = [
    '薰衣草', '檀香', '雪松', '甜橙', '柠檬', '玫瑰', '茉莉', '桂花',
    '百合', '薄荷', '绿茶', '海洋', '木质', '香草', '白桃', '葡萄',
    '蓝莓', '沉香', '柑橘', '栀子花',
  ];

  // ---------- 默认配置 ----------
  static const Map<int, String> _defaultConfig = {
    1: '薰衣草',
    2: '檀香',
    3: '雪松',
    4: '甜橙',
  };

  // ---------- 内存缓存 ----------
  static final Map<int, String> _config = {};
  static bool _initialized = false;

  /// 初始化服务（加载数据库配置，补充默认值）
  static Future<void> init() async {
    if (_initialized) return;
    await _loadFromDatabase();
    // 为缺失的风扇补充默认配置
    for (final entry in _defaultConfig.entries) {
      _config.putIfAbsent(entry.key, () => entry.value);
    }
    _initialized = true;
  }

  /// 从数据库加载已保存的配置
  static Future<void> _loadFromDatabase() async {
    try {
      final db = await AppDatabase().database;
      final configs = await db.query('fan_scent_config');
      for (final config in configs) {
        final fanId = config['fan_id'] as int;
        final scentName = config['scent_name'] as String?;
        if (scentName != null && scentName.isNotEmpty) {
          _config[fanId] = scentName;
        }
      }
    } catch (e) {
      debugPrint('从数据库加载风扇配置失败: $e');
    }
  }

  /// 获取指定风扇当前的气味名称
  static String getFanScent(int fanId) {
    if (!_initialized) {
      return _defaultConfig[fanId] ?? availableScents.first;
    }
    return _config[fanId] ?? _defaultConfig[fanId] ?? availableScents.first;
  }

  /// 设置单个风扇的气味（有效气味才保存）
  static Future<void> setFanScent(int fanId, String scentName) async {
    if (!availableScents.contains(scentName)) return;
    _config[fanId] = scentName;
    await _saveToDatabase(fanId, scentName);
  }

  /// 批量设置所有风扇的气味（仅接受有效气味）
  static Future<void> setAllFanScents(Map<int, String> scents) async {
    for (final entry in scents.entries) {
      if (availableScents.contains(entry.value)) {
        _config[entry.key] = entry.value;
      }
    }
    await _saveAllToDatabase(scents);
  }

  /// 保存单一配置到数据库（插入或更新）
  static Future<void> _saveToDatabase(int fanId, String scentName) async {
    try {
      final db = await AppDatabase().database;
      await _upsertFanConfig(db, fanId, scentName);
      debugPrint('✅ 已保存风扇$fanId配置到数据库: $scentName');
    } catch (e) {
      debugPrint('保存风扇配置到数据库失败: $e');
    }
  }

  /// 批量保存配置（仅处理有效气味）
  static Future<void> _saveAllToDatabase(Map<int, String> scents) async {
    try {
      final db = await AppDatabase().database;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final entry in scents.entries) {
        if (!availableScents.contains(entry.value)) continue;
        await _upsertFanConfig(db, entry.key, entry.value, now);
      }
      debugPrint('✅ 已批量保存所有风扇配置到数据库');
    } catch (e) {
      debugPrint('批量保存风扇配置到数据库失败: $e');
    }
  }

  /// 插入或更新风扇气味配置（抽象重复逻辑）
  static Future<void> _upsertFanConfig(
      Database db,
      int fanId,
      String scentName, [
        int? timestamp,
      ]) async {
    final now = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final existing = await db.query(
      'fan_scent_config',
      where: 'fan_id = ?',
      whereArgs: [fanId],
    );
    if (existing.isNotEmpty) {
      await db.update(
        'fan_scent_config',
        {'scent_name': scentName, 'updated_at': now},
        where: 'fan_id = ?',
        whereArgs: [fanId],
      );
    } else {
      await db.insert('fan_scent_config', {
        'fan_id': fanId,
        'scent_name': scentName,
        'updated_at': now,
      });
    }
  }

  /// 获取当前所有配置的副本
  static Map<int, String> getAllConfig() => Map.of(_config);
}