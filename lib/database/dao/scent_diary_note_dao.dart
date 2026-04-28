import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../models/scent_diary_note.dart';

/// 气味日记笔记数据访问对象
class ScentDiaryNoteDAO {
  /// 获取数据库实例
  Future<Database> get _db async => AppDatabase().database;

  /// 获取所有气味日记笔记
  Future<List<ScentDiaryNote>> getAllScentDiaryNotes() async {
    try {
      final db = await _db;
      final List<Map<String, dynamic>> maps = await db.query(
        'scent_diary_note',
        orderBy: 'created_at DESC',
      );
      return List.generate(maps.length, (i) => ScentDiaryNote.fromMap(maps[i]));
    } catch (e) {
      print('获取所有气味日记笔记失败: $e');
      return [];
    }
  }

  /// 根据ID获取日记笔记
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
      print('获取气味日记笔记失败: $e');
    }
    return null;
  }

  /// 插入日记笔记
  Future<int> insert(ScentDiaryNote note) async {
    try {
      final db = await _db;
      note.createdAt = DateTime.now().millisecondsSinceEpoch;
      return await db.insert('scent_diary_note', note.toMap());
    } catch (e) {
      print('插入日记笔记失败: $e');
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
      print('更新日记笔记失败: $e');
      return -1;
    }
  }

  /// 删除日记笔记
  Future<int> delete(int id) async {
    try {
      final db = await _db;
      return await db.delete(
        'scent_diary_note',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('删除日记笔记失败: $e');
      return -1;
    }
  }
}
