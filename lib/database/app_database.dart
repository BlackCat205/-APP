import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// 统一的数据库管理类 - 单例模式
/// 合并 scent_memory.db、usage_records.db、scent_db.db 为 scent_app.db
class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;

  factory AppDatabase() => _instance;
  AppDatabase._internal();

  /// 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'scent_app.db');

    return await openDatabase(
      path,
      version: 2, // 版本升级：合并3个数据库
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 创建所有表
  Future<void> _onCreate(Database db, int version) async {
    await _createUserScenePreferenceTable(db);
    await _createEmotionScentMemoryTable(db);
    await _createScentDiaryNoteTable(db);
    await _createCustomScentPlanTable(db);
    await _createUsageRecordsTable(db);
    await _createFanScentConfigTable(db);
    await _createUserEmotionRecordTable(db);
    await _createScentConfigTable(db);

    // 插入默认数据
    await _insertDefaultFanScentConfig(db);
    await _insertDefaultScenePreferences(db);
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 版本1→2：添加缺失的表
      await _createUserEmotionRecordTable(db);
      await _createScentConfigTable(db);
    }
  }

  // ==================== 表创建方法 ====================

  /// 用户场景偏好表
  Future<void> _createUserScenePreferenceTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_scene_preference (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scene_type TEXT,
        preferred_scent TEXT,
        rejected_scents TEXT,
        default_speed INTEGER,
        default_timer INTEGER,
        updated_at INTEGER
      )
    ''');
  }

  /// 情绪气味记忆表
  Future<void> _createEmotionScentMemoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS emotion_scent_memory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        emotion TEXT,
        effective_scent TEXT,
        user_feedback TEXT,
        use_count INTEGER DEFAULT 0,
        created_at INTEGER
      )
    ''');
  }

  /// 气味日记表
  Future<void> _createScentDiaryNoteTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scent_diary_note (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mood TEXT,
        used_scent TEXT,
        scene TEXT,
        note_content TEXT,
        created_at INTEGER
      )
    ''');
  }

  /// 自定义香氛方案表
  Future<void> _createCustomScentPlanTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_scent_plan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_name TEXT,
        scene TEXT,
        fan1_scent TEXT,
        fan1_speed INTEGER,
        fan2_scent TEXT,
        fan2_speed INTEGER,
        fan3_scent TEXT,
        fan3_speed INTEGER,
        fan4_scent TEXT,
        fan4_speed INTEGER,
        timer_minutes INTEGER,
        created_at INTEGER
      )
    ''');
  }

  /// 使用记录表
  Future<void> _createUsageRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usage_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        duration INTEGER,
        fan_ids TEXT NOT NULL,
        scent_combo TEXT,
        scene_tag TEXT,
        emotion_emoji TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  /// 风扇气味配置表
  Future<void> _createFanScentConfigTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fan_scent_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fan_id INTEGER UNIQUE,
        scent_name TEXT,
        updated_at INTEGER
      )
    ''');
  }

  /// 用户情绪记录表（来自 scent_db.db）
  Future<void> _createUserEmotionRecordTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_emotion_record (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        emotion_label TEXT,
        emotion_strength INTEGER,
        recommended_scent TEXT,
        timestamp INTEGER,
        scene TEXT
      )
    ''');
  }

  /// 香氛配置表（来自 scent_db.db）
  Future<void> _createScentConfigTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scent_config (
        scent_id INTEGER PRIMARY KEY,
        scent_name TEXT,
        applicable_emotions TEXT,
        reason TEXT,
        scene TEXT
      )
    ''');
  }

  // ==================== 默认数据 ====================

  /// 插入默认风扇气味配置
  Future<void> _insertDefaultFanScentConfig(Database db) async {
    final defaultConfigs = [
      {'fan_id': 1, 'scent_name': '薰衣草'},
      {'fan_id': 2, 'scent_name': '檀香'},
      {'fan_id': 3, 'scent_name': '雪松'},
      {'fan_id': 4, 'scent_name': '甜橙'},
    ];

    final now = DateTime.now().millisecondsSinceEpoch;
    for (var config in defaultConfigs) {
      await db.insert('fan_scent_config', {
        'fan_id': config['fan_id'],
        'scent_name': config['scent_name'],
        'updated_at': now,
      });
    }
  }

  /// 插入默认场景偏好
  Future<void> _insertDefaultScenePreferences(Database db) async {
    final defaultScenes = [
      {
        'scene_type': '疲惫舒缓',
        'preferred_scent': '薰衣草',
        'rejected_scents': '',
        'default_speed': 1,
        'default_timer': 30,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'scene_type': '助眠安神',
        'preferred_scent': '薰衣草',
        'rejected_scents': '',
        'default_speed': 0,
        'default_timer': 90,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'scene_type': '提神醒脑',
        'preferred_scent': '柠檬',
        'rejected_scents': '',
        'default_speed': 2,
        'default_timer': 30,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
    ];

    for (var scene in defaultScenes) {
      await db.insert('user_scene_preference', scene);
    }
  }

  // ==================== 通用查询方法 ====================

  /// 获取所有表名
  Future<List<String>> getAllTableNames() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
      );
      return result.map((e) => e['name'] as String).toList();
    } catch (e) {
      print('获取表名失败: $e');
      return [];
    }
  }

  /// 查询指定表的所有数据
  Future<List<Map<String, dynamic>>> queryTable(String tableName) async {
    try {
      final db = await database;
      return await db.query(tableName);
    } catch (e) {
      print('查询表 $tableName 失败: $e');
      return [];
    }
  }

  /// 关闭数据库
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
