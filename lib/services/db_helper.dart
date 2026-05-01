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

  /// 关闭数据库
  Future<void> close() async {
    await AppDatabase().close();
  }
}
