import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import 'scent_catalog.dart';

/// 风扇气味配置服务（数据缓存 + 数据库持久化）
class FanScentService {
  // ---------- 可选气味列表 ----------
  static final List<String> availableScents = List.unmodifiable(ScentCatalog.idsByName.keys);
  static final ValueNotifier<int> revision = ValueNotifier(0);

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

  /// 数据库提交成功后才更新缓存和通知推荐，避免展示未保存的配置。
  static Future<void> setFanScent(int fanId, String scentName) =>
      setAllFanScents({fanId: scentName});

  static Future<void> setAllFanScents(Map<int, String> scents) async {
    final next = Map<int, String>.of(scents);
    if (next.entries.any((e) => e.key < 1 || e.key > 4 || !availableScents.contains(e.value))) {
      throw ArgumentError('风扇编号或气味无效');
    }
    if (next.isEmpty) return;
    final db = await AppDatabase().database;
    await db.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final entry in next.entries) {
        await _upsertFanConfig(txn, entry.key, entry.value, now);
      }
    });
    _config.addAll(next);
    revision.value++;
  }

  /// 插入或更新风扇气味配置（抽象重复逻辑）
  static Future<void> _upsertFanConfig(
      DatabaseExecutor db,
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