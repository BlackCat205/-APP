import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../models/emotion_scent_memory.dart';

/// 情绪气味记忆数据访问对象
class EmotionScentMemoryDAO {
  /// 获取数据库实例
  Future<Database> get _db async => AppDatabase().database;

  /// 获取所有情绪气味记忆
  Future<List<EmotionScentMemory>> getAllEmotionScentMemories() async {
    try {
      final db = await _db;
      final List<Map<String, dynamic>> maps = await db.query(
        'emotion_scent_memory',
      );
      return List.generate(
        maps.length,
        (i) => EmotionScentMemory.fromMap(maps[i]),
      );
    } catch (e) {
      print('获取所有情绪气味记忆失败: $e');
      return [];
    }
  }

  /// 根据情绪类型获取记忆
  Future<EmotionScentMemory?> getEmotionScentMemoryByEmotion(
    String emotion,
  ) async {
    try {
      final db = await _db;
      final List<Map<String, dynamic>> maps = await db.query(
        'emotion_scent_memory',
        where: 'emotion = ?',
        whereArgs: [emotion],
      );
      if (maps.isNotEmpty) {
        return EmotionScentMemory.fromMap(maps.first);
      }
    } catch (e) {
      print('获取情绪气味记忆失败: $e');
    }
    return null;
  }

  /// 插入或更新情绪气味记忆
  Future<int> insertOrUpdate(EmotionScentMemory memory) async {
    try {
      final db = await _db;

      final existing = await getEmotionScentMemoryByEmotion(memory.emotion);
      if (existing != null) {
        existing.useCount += 1;
        return await db.update(
          'emotion_scent_memory',
          existing.toMap(),
          where: 'emotion = ?',
          whereArgs: [memory.emotion],
        );
      } else {
        memory.createdAt = DateTime.now().millisecondsSinceEpoch;
        return await db.insert('emotion_scent_memory', memory.toMap());
      }
    } catch (e) {
      print('插入或更新情绪气味记忆失败: $e');
      return -1;
    }
  }

  /// 删除情绪气味记忆
  Future<int> delete(String emotion) async {
    try {
      final db = await _db;
      return await db.delete(
        'emotion_scent_memory',
        where: 'emotion = ?',
        whereArgs: [emotion],
      );
    } catch (e) {
      print('删除情绪气味记忆失败: $e');
      return -1;
    }
  }
}
