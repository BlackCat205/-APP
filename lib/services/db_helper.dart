import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

/// 数据库助手类 - 兼容层
/// 现在使用统一的 AppDatabase，保留此类以保持向后兼容
class DBHelper {
  static final DBHelper _instance = DBHelper._private();

  factory DBHelper() => _instance;
  DBHelper._private();

  /// 获取数据库实例（来自 AppDatabase）
  Future<Database> get database async => AppDatabase().database;

  /// 插入情绪记录
  Future<int> insertEmotionRecord({
    required String userId,
    required String emotionLabel,
    required int emotionStrength,
    required String recommendedScent,
    required int timestamp,
    required String scene,
  }) async {
    try {
      final db = await database;
      return await db.insert('user_emotion_record', {
        'user_id': userId,
        'emotion_label': emotionLabel,
        'emotion_strength': emotionStrength,
        'recommended_scent': recommendedScent,
        'timestamp': timestamp,
        'scene': scene,
      });
    } catch (e) {
      print('插入情绪记录失败: $e');
      return -1;
    }
  }

  /// 插入或更新香氛配置
  Future<int> insertScentConfig({
    required int scentId,
    required String scentName,
    required String applicableEmotions,
    required String reason,
    required String scene,
  }) async {
    try {
      final db = await database;
      final existing = await db.query(
        'scent_config',
        where: 'scent_id = ?',
        whereArgs: [scentId],
      );

      if (existing.isNotEmpty) {
        return await db.update(
          'scent_config',
          {
            'scent_name': scentName,
            'applicable_emotions': applicableEmotions,
            'reason': reason,
            'scene': scene,
          },
          where: 'scent_id = ?',
          whereArgs: [scentId],
        );
      } else {
        return await db.insert('scent_config', {
          'scent_id': scentId,
          'scent_name': scentName,
          'applicable_emotions': applicableEmotions,
          'reason': reason,
          'scene': scene,
        });
      }
    } catch (e) {
      print('插入香氛配置失败: $e');
      return -1;
    }
  }

  /// 查询所有情绪记录
  Future<List<Map<String, dynamic>>> getAllEmotionRecords() async {
    try {
      final db = await database;
      return await db.query('user_emotion_record', orderBy: 'timestamp DESC');
    } catch (e) {
      print('查询情绪记录失败: $e');
      return [];
    }
  }

  /// 查询所有香氛配置
  Future<List<Map<String, dynamic>>> getAllScentConfigs() async {
    try {
      final db = await database;
      return await db.query('scent_config');
    } catch (e) {
      print('查询香氛配置失败: $e');
      return [];
    }
  }

  /// 根据场景查询香氛配置
  Future<List<Map<String, dynamic>>> getScentConfigsByScene(
    String scene,
  ) async {
    try {
      final db = await database;
      return await db.query(
        'scent_config',
        where: 'scene = ?',
        whereArgs: [scene],
      );
    } catch (e) {
      print('根据场景查询香氛配置失败: $e');
      return [];
    }
  }

  /// 关闭数据库
  Future<void> close() async {
    await AppDatabase().close();
  }
}
