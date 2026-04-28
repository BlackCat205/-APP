import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../models/custom_scent_plan.dart';

/// 自定义香氛方案数据访问对象
class CustomScentPlanDAO {
  /// 获取数据库实例
  Future<Database> get _db async => AppDatabase().database;

  /// 获取所有自定义香氛方案
  Future<List<CustomScentPlan>> getAllCustomScentPlans() async {
    try {
      final db = await _db;
      final List<Map<String, dynamic>> maps = await db.query(
        'custom_scent_plan',
      );
      return List.generate(
        maps.length,
        (i) => CustomScentPlan.fromMap(maps[i]),
      );
    } catch (e) {
      print('获取所有自定义香氛方案失败: $e');
      return [];
    }
  }

  /// 根据ID获取自定义香氛方案
  Future<CustomScentPlan?> getCustomScentPlanById(int id) async {
    try {
      final db = await _db;
      final List<Map<String, dynamic>> maps = await db.query(
        'custom_scent_plan',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return CustomScentPlan.fromMap(maps.first);
      }
    } catch (e) {
      print('获取自定义香氛方案失败: $e');
    }
    return null;
  }

  /// 插入自定义香氛方案
  Future<int> insert(CustomScentPlan plan) async {
    try {
      final db = await _db;
      plan.createdAt = DateTime.now().millisecondsSinceEpoch;
      return await db.insert('custom_scent_plan', plan.toMap());
    } catch (e) {
      print('插入自定义香氛方案失败: $e');
      return -1;
    }
  }

  /// 更新自定义香氛方案
  Future<int> update(CustomScentPlan plan) async {
    try {
      final db = await _db;
      return await db.update(
        'custom_scent_plan',
        plan.toMap(),
        where: 'id = ?',
        whereArgs: [plan.id],
      );
    } catch (e) {
      print('更新自定义香氛方案失败: $e');
      return -1;
    }
  }

  /// 删除自定义香氛方案
  Future<int> delete(int id) async {
    try {
      final db = await _db;
      return await db.delete(
        'custom_scent_plan',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('删除自定义香氛方案失败: $e');
      return -1;
    }
  }
}
