import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'app_database.dart';

/// 数据库助手类 - 兼容层
/// 现在使用统一的 AppDatabase，保留此类以保持向后兼容
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  /// 获取数据库实例（来自 AppDatabase）
  Future<Database> get database async => AppDatabase().database;

  /// 保存风扇气味配置
  Future<void> saveFanConfig(int fanId, String scentName) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

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
    } catch (e) {
      print('保存风扇配置失败: $e');
    }
  }

  /// 获取风扇气味配置
  Future<String?> getFanConfig(int fanId) async {
    try {
      final db = await database;
      final result = await db.query(
        'fan_scent_config',
        where: 'fan_id = ?',
        whereArgs: [fanId],
      );

      if (result.isNotEmpty) {
        return result.first['scent_name'] as String?;
      }
    } catch (e) {
      print('获取风扇配置失败: $e');
    }
    return null;
  }

  /// 获取所有风扇气味配置
  Future<List<Map<String, dynamic>>> getAllFanConfigs() async {
    try {
      final db = await database;
      return await db.query('fan_scent_config', orderBy: 'fan_id ASC');
    } catch (e) {
      print('获取所有风扇配置失败: $e');
      return [];
    }
  }

  /// 关闭数据库
  Future<void> close() async {
    await AppDatabase().close();
  }
}
