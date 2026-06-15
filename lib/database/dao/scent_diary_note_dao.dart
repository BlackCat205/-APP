import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../models/scent_diary_note.dart';

/// 气味日记笔记数据访问对象
class ScentDiaryNoteDAO {
  /// 获取数据库实例（每次调用可能访问新的 AppDatabase 实例，但实际为单例）
  Future<Database> get _db => AppDatabase().database;

  /// 获取所有气味日记笔记，按创建时间倒序排列
  Future<List<ScentDiaryNote>> getAllScentDiaryNotes() async {
    try {
      final db = await _db;
      final List<Map<String, dynamic>> maps = await db.query(
        'scent_diary_note',
        orderBy: 'created_at DESC',
      );
      return maps.map(ScentDiaryNote.fromMap).toList();
    } catch (e) {
      debugPrint('获取所有气味日记笔记失败: $e');
      return [];
    }
  }

  /// 根据 ID 获取单条日记笔记
  Future<ScentDiaryNote?> getScentDiaryNoteById(int id) async {
    try {
      final db = await _db;
      final List<Map<String, dynamic>> maps = await db.query(
        'scent_diary_note',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return ScentDiaryNote.fromMap(maps.first);
      }
    } catch (e) {
      debugPrint('获取气味日记笔记失败: $e');
    }
    return null;
  }

  /// 插入一条日记笔记，自动设置 createdAt
  Future<int> insert(ScentDiaryNote note) async {
    try {
      final db = await _db;
      // 注意：这里直接修改 note 的 createdAt（假设模型允许）
      note.createdAt = DateTime.now().millisecondsSinceEpoch;
      return await db.insert('scent_diary_note', note.toMap());
    } catch (e) {
      debugPrint('插入日记笔记失败: $e');
      return -1;
    }
  }

  /// 更新日记笔记
  Future<int> update(ScentDiaryNote note) async {
    try {
      final db = await _db;
      return await db.update(
        'scent_diary_note',
        note.toMap(),
        where: 'id = ?',
        whereArgs: [note.id],
      );
    } catch (e) {
      debugPrint('更新日记笔记失败: $e');
      return -1;
    }
  }

  /// 删除指定 ID 的日记笔记
  Future<int> delete(int id) async {
    try {
      final db = await _db;
      return await db.delete(
        'scent_diary_note',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('删除日记笔记失败: $e');
      return -1;
    }
  }
}