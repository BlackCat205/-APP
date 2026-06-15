import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

/// 数据库助手兼容层（已由 AppDatabase 统一管理，保留用于向后兼容）
class DBHelper {
  static final DBHelper _instance = DBHelper._private();

  factory DBHelper() => _instance;
  DBHelper._private();

  /// 获取数据库实例（实际委托给 AppDatabase 单例）
  Future<Database> get database => AppDatabase().database;

  /// 关闭数据库（实际关闭 AppDatabase 实例）
  Future<void> close() async => AppDatabase().close();
}