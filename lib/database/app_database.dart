import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// 统一的数据库管理类 - 单例模式
/// 合并 scent_memory.db、usage_records.db、scent_db.db 为 scent_app.db
class AppDatabase {
  // ---------- 单例实现 ----------
  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;

  factory AppDatabase() => _instance;
  AppDatabase._internal();

  // ---------- 常量 ----------
  static const String _dbName = 'scent_app.db';
  static const int _dbVersion = 9;

  static const String _tableScentDiaryNote = 'scent_diary_note';
  static const String _tableUsageRecords = 'usage_records';
  static const String _tableSmellMomentRecord = 'smell_moment_record';
  static const String _tableFanScentConfig = 'fan_scent_config';
  static const String _tableCardTriggerRecords = 'card_trigger_records';

  // 默认风扇配置数据
  static const List<Map<String, dynamic>> _defaultFanConfigs = [
    {'fan_id': 1, 'scent_name': '薰衣草'},
    {'fan_id': 2, 'scent_name': '檀香'},
    {'fan_id': 3, 'scent_name': '雪松'},
    {'fan_id': 4, 'scent_name': '甜橙'},
  ];

  // ---------- 数据库访问 ----------
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ---------- 建表 ----------
  Future<void> _onCreate(Database db, int version) async {
    await _createScentDiaryNoteTable(db);
    await _createUsageRecordsTable(db);
    await _createFanScentConfigTable(db);
    await _createSmellMomentRecordTable(db);
    await _createCardTriggerRecordsTable(db);
    await _insertDefaultFanScentConfig(db);
  }

  Future<void> _createScentDiaryNoteTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableScentDiaryNote (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mood TEXT,
        used_scent TEXT,
        scene TEXT,
        note_content TEXT,
        created_at INTEGER
      )
    ''');
  }

  Future<void> _createUsageRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableUsageRecords (
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

  Future<void> _createSmellMomentRecordTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableSmellMomentRecord (
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

  Future<void> _createFanScentConfigTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableFanScentConfig (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fan_id INTEGER UNIQUE,
        scent_name TEXT,
        updated_at INTEGER
      )
    ''');
  }

  Future<void> _createCardTriggerRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableCardTriggerRecords (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  /// 插入默认风扇气味配置
  Future<void> _insertDefaultFanScentConfig(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final config in _defaultFanConfigs) {
      await db.insert(_tableFanScentConfig, {
        'fan_id': config['fan_id'],
        'scent_name': config['scent_name'],
        'updated_at': now,
      });
    }
  }

  // ---------- 数据库升级 ----------
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) await _migrateV2toV3(db);
    if (oldVersion < 4) await _migrateV3toV4(db);
    if (oldVersion < 5) await _migrateV4toV5(db);
    if (oldVersion < 6) await _migrateV5toV6(db);
    if (oldVersion < 7) await _migrateV6toV7(db);
    if (oldVersion < 8) await _migrateV7toV8(db);
    if (oldVersion < 9) await _migrateV8toV9(db);
  }

  Future<void> _migrateV2toV3(Database db) async {
    await db.execute('DROP TABLE IF EXISTS user_scene_preference');
    await db.execute('DROP TABLE IF EXISTS custom_scent_plan');
    await db.execute('DROP TABLE IF EXISTS user_emotion_record');
    await db.execute('DROP TABLE IF EXISTS scent_config');
  }

  Future<void> _migrateV3toV4(Database db) async {
    await db.execute('ALTER TABLE usage_records RENAME TO usage_records_old');
    await _createUsageRecordsTable(db);
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
    await db.execute('DROP TABLE IF EXISTS usage_records_old');
    await _createSmellMomentRecordTable(db);
  }

  Future<void> _migrateV4toV5(Database db) async {
    await db.execute('DROP TABLE IF EXISTS emotion_scent_memory');
  }

  Future<void> _migrateV5toV6(Database db) async {
    await db.execute('ALTER TABLE smell_moment_record ADD COLUMN title TEXT');
    await db.execute('ALTER TABLE smell_moment_record ADD COLUMN scent_combo TEXT');
  }

  Future<void> _migrateV6toV7(Database db) async {
    // SQLite 不支持直接删除列，重建表
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
    await db.execute('''
      INSERT INTO smell_moment_record_new (id, title, scene_tag, emotion_emoji, note, scent_combo, created_at)
      SELECT id, title, scene_tag, emotion_emoji, note, scent_combo, created_at FROM smell_moment_record
    ''');
    await db.execute('DROP TABLE IF EXISTS smell_moment_record');
    await db.execute('ALTER TABLE smell_moment_record_new RENAME TO smell_moment_record');
  }

  Future<void> _migrateV7toV8(Database db) async {
    await db.execute('ALTER TABLE smell_moment_record ADD COLUMN score INTEGER');
  }

  Future<void> _migrateV8toV9(Database db) async {
    await _createCardTriggerRecordsTable(db);
  }

  // ---------- 通用查询方法 ----------
  Future<List<String>> getAllTableNames() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
      );
      return result.map((e) => e['name'] as String).toList();
    } catch (e) {
      debugPrint('获取表名失败: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> queryTable(String tableName) async {
    try {
      final db = await database;
      return await db.query(tableName);
    } catch (e) {
      debugPrint('查询表 $tableName 失败: $e');
      return [];
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}