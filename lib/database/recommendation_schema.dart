import 'package:sqflite/sqflite.dart';

/// v10 的增量结构。旧记录不回填会话，也不冒充已验证行为。
class RecommendationSchema {
  static Future<void> migrate(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS usage_sessions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      start_time INTEGER NOT NULL,
      end_time INTEGER,
      duration INTEGER CHECK(duration IS NULL OR duration >= 0),
      scent_snapshot TEXT NOT NULL,
      combination_key TEXT,
      scene TEXT,
      before_state INTEGER CHECK(before_state BETWEEN 1 AND 5),
      before_state_source TEXT,
      status TEXT NOT NULL DEFAULT 'pending',
      source TEXT NOT NULL DEFAULT 'app_command_unverified',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS usage_feedback (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id TEXT NOT NULL UNIQUE REFERENCES usage_sessions(id) ON DELETE CASCADE,
      after_state INTEGER CHECK(after_state BETWEEN 1 AND 5),
      liking INTEGER CHECK(liking BETWEEN 1 AND 5),
      reuse_intent INTEGER CHECK(reuse_intent BETWEEN 0 AND 2),
      note TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS preference_profiles (
      user_id TEXT PRIMARY KEY,
      preferred_traits TEXT NOT NULL DEFAULT '[]',
      disliked_traits TEXT NOT NULL DEFAULT '[]',
      candidate_scores TEXT NOT NULL DEFAULT '[]',
      confidence REAL CHECK(confidence BETWEEN 0 AND 1),
      reason TEXT,
      input_version INTEGER NOT NULL DEFAULT 0,
      candidate_version TEXT,
      status TEXT NOT NULL DEFAULT 'pending',
      updated_at INTEGER NOT NULL
    )''');
    await _addColumn(
      db,
      'usage_records',
      'session_id',
      'TEXT REFERENCES usage_sessions(id) ON DELETE SET NULL',
    );
    await _addColumn(
      db,
      'usage_records',
      'source',
      "TEXT NOT NULL DEFAULT 'legacy_unknown'",
    );
    await _addColumn(
      db,
      'usage_records',
      'status',
      "TEXT NOT NULL DEFAULT 'legacy_unknown'",
    );
    await _addColumn(
      db,
      'smell_moment_record',
      'session_id',
      'TEXT REFERENCES usage_sessions(id) ON DELETE SET NULL',
    );
    await _addColumn(
      db,
      'smell_moment_record',
      'source',
      "TEXT NOT NULL DEFAULT 'legacy_unknown'",
    );
    await _addColumn(
      db,
      'smell_moment_record',
      'duration_seconds',
      'INTEGER CHECK(duration_seconds IS NULL OR duration_seconds >= 0)',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS moment_usage_records (
      moment_id INTEGER NOT NULL REFERENCES smell_moment_record(id) ON DELETE CASCADE,
      usage_record_id INTEGER NOT NULL REFERENCES usage_records(id) ON DELETE CASCADE,
      PRIMARY KEY(moment_id, usage_record_id)
    )''');
    // 删除收藏后仍保留导入凭据，防止下次启动从旧备份复活。
    await db.execute('''CREATE TABLE IF NOT EXISTS legacy_moment_imports (
      source_key TEXT PRIMARY KEY,
      moment_id INTEGER REFERENCES smell_moment_record(id) ON DELETE SET NULL
    )''');
    for (final sql in [
      'CREATE INDEX IF NOT EXISTS idx_usage_session ON usage_records(session_id)',
      'CREATE INDEX IF NOT EXISTS idx_session_user_time ON usage_sessions(user_id, start_time)',
      'CREATE INDEX IF NOT EXISTS idx_moment_session ON smell_moment_record(session_id)',
      'CREATE INDEX IF NOT EXISTS idx_moment_usage ON moment_usage_records(usage_record_id)',
      'CREATE INDEX IF NOT EXISTS idx_moment_time ON smell_moment_record(created_at)',
    ]) {
      await db.execute(sql);
    }
  }

  static Future<void> _addColumn(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (!columns.any((row) => row['name'] == column)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }
}
