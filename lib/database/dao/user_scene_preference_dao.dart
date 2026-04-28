import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../models/user_scene_preference.dart';

/// 用户场景偏好数据访问对象
class UserScenePreferenceDAO {
  /// 获取数据库实例
  Future<Database> get _db async => AppDatabase().database;

  /// 获取所有场景偏好
  Future<List<UserScenePreference>> getAllScenePreferences() async {
    try {
      final db = await _db;
      final List<Map<String, dynamic>> maps = await db.query(
        'user_scene_preference',
      );
      return List.generate(
        maps.length,
        (i) => UserScenePreference.fromMap(maps[i]),
      );
    } catch (e) {
      print('获取所有场景偏好失败: $e');
      return [];
    }
  }

  /// 根据场景类型获取偏好
  Future<UserScenePreference?> getScenePreferenceByType(
    String sceneType,
  ) async {
    try {
      final db = await _db;
      final List<Map<String, dynamic>> maps = await db.query(
        'user_scene_preference',
        where: 'scene_type = ?',
        whereArgs: [sceneType],
      );
      if (maps.isNotEmpty) {
        return UserScenePreference.fromMap(maps.first);
      }
    } catch (e) {
      print('获取场景偏好失败: $e');
    }
    return null;
  }

  /// 插入或更新场景偏好
  Future<int> insertOrUpdate(UserScenePreference preference) async {
    try {
      final db = await _db;
      preference.updatedAt = DateTime.now().millisecondsSinceEpoch;

      final existing = await getScenePreferenceByType(preference.sceneType);
      if (existing != null) {
        return await db.update(
          'user_scene_preference',
          preference.toMap(),
          where: 'scene_type = ?',
          whereArgs: [preference.sceneType],
        );
      } else {
        return await db.insert('user_scene_preference', preference.toMap());
      }
    } catch (e) {
      print('插入或更新场景偏好失败: $e');
      return -1;
    }
  }

  /// 删除场景偏好
  Future<int> delete(String sceneType) async {
    try {
      final db = await _db;
      return await db.delete(
        'user_scene_preference',
        where: 'scene_type = ?',
        whereArgs: [sceneType],
      );
    } catch (e) {
      print('删除场景偏好失败: $e');
      return -1;
    }
  }
}
