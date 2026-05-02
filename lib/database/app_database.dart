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
      version: 9, // 版本9：添加card_trigger_records表，记录卡片弹出事件
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 创建所有表
  Future<void> _onCreate(Database db, int version) async {
    await _createScentDiaryNoteTable(db);
    await _createUsageRecordsTable(db);
    await _createFanScentConfigTable(db);
    await _createSmellMomentRecordTable(db);
    await _createCardTriggerRecordsTable(db);

    // 插入默认数据
    await _insertDefaultFanScentConfig(db);
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 版本2→3：删除 user_scene_preference, custom_scent_plan, user_emotion_record, scent_config 表
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS user_scene_preference');
      await db.execute('DROP TABLE IF EXISTS custom_scent_plan');
      await db.execute('DROP TABLE IF EXISTS user_emotion_record');
      await db.execute('DROP TABLE IF EXISTS scent_config');
    }

    // 版本3→4：修改usage_records表结构，新增smell_moment_record表
    if (oldVersion < 4) {
      // 重命名旧表
      await db.execute('ALTER TABLE usage_records RENAME TO usage_records_old');

      // 创建新的usage_records表（单风扇记录）
      await _createUsageRecordsTable(db);

      // 迁移数据（将多风扇记录拆分为单风扇记录）
      final oldRecords = await db.query('usage_records_old');
      for (final record in oldRecords) {
        final fanIds = (record['fan_ids'] as String).split(',');
        final scentCombo = (record['scent_combo'] as String?)?.split('+') ?? [];

        for (int i = 0; i < fanIds.length; i++) {
          await db.insert('usage_records', {
            'start_time': record['start_time'],
            'end_time': record['end_time'],
            'duration': record['duration'],
            'fan_id': int.parse(fanIds[i]),
            'scent_name': i < scentCombo.length ? scentCombo[i] : '',
            'created_at': record['created_at'],
          });
        }
      }

      // 删除旧表
      await db.execute('DROP TABLE IF EXISTS usage_records_old');

      // 创建气味瞬间记录表
      await _createSmellMomentRecordTable(db);
    }

    // 版本4→5：删除 emotion_scent_memory 表
    if (oldVersion < 5) {
      await db.execute('DROP TABLE IF EXISTS emotion_scent_memory');
    }

    // 版本5→6：为 smell_moment_record 表添加 title 和 scent_combo 字段
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE smell_moment_record ADD COLUMN title TEXT');
      await db.execute(
        'ALTER TABLE smell_moment_record ADD COLUMN scent_combo TEXT',
      );
    }

    // 版本6→7：从 smell_moment_record 表移除 usage_record_ids 字段
    if (oldVersion < 7) {
      // SQLite不支持直接删除列，需要重建表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS smell_moment_record_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          scene_tag TEXT,
          emotion_emoji TEXT,
          note TEXT,
          scent_combo TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
      // 复制数据（排除 usage_record_ids）
      await db.execute('''
        INSERT INTO smell_moment_record_new (id, title, scene_tag, emotion_emoji, note, scent_combo, created_at)
        SELECT id, title, scene_tag, emotion_emoji, note, scent_combo, created_at FROM smell_moment_record
      ''');
      // 删除旧表
      await db.execute('DROP TABLE IF EXISTS smell_moment_record');
      // 重命名新表
      await db.execute(
        'ALTER TABLE smell_moment_record_new RENAME TO smell_moment_record',
      );
    }

    // 版本7→8：添加score评分字段
    if (oldVersion < 8) {
      await db.execute(
        'ALTER TABLE smell_moment_record ADD COLUMN score INTEGER',
      );
    }

    // 版本8→9：添加card_trigger_records表，记录卡片弹出事件
    if (oldVersion < 9) {
      await _createCardTriggerRecordsTable(db);
    }
  }

  // ==================== 表创建方法 ====================

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

  /// 使用记录表（单风扇记录）
  Future<void> _createUsageRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usage_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        duration INTEGER,
        fan_id INTEGER NOT NULL,
        scent_name TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  /// 气味瞬间记录表（存储弹窗收集的数据）
  Future<void> _createSmellMomentRecordTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS smell_moment_record (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        scene_tag TEXT,
        emotion_emoji TEXT,
        note TEXT,
        scent_combo TEXT,
        score INTEGER,
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

  /// 卡片触发表（记录每次弹出卡片的事件）
  Future<void> _createCardTriggerRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS card_trigger_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at INTEGER NOT NULL
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
