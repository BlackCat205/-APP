import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// 串行管理用户操作、BLE 写入与数据库状态。不依赖 AI。
class UsageSessionService extends ChangeNotifier {
  UsageSessionService({
    required this.db,
    required this.send,
    required this.connected,
    required this.scentForFan,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final Database db;
  final Future<void> Function(String) send;
  final bool Function() connected;
  final String Function(int) scentForFan;
  final DateTime Function() clock;
  final Map<int, int> _active = {};
  final Map<int, Timer> _timers = {};
  final Map<int, int> _deadlines = {};
  Future<void> _queue = Future.value();
  String? _sessionId;
  String? _owner;
  String? lastFinished;
  String? lastError;
  bool busy = false;
  bool _disposed = false;
  Set<int> get activeFans => Set.unmodifiable(_active.keys);
  bool get hasActiveSession => _sessionId != null;
  int _now() => clock().millisecondsSinceEpoch;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _serial(Future<void> Function() action) {
    final result = _queue.then((_) async {
      busy = true;
      _changed();
      try {
        await action();
      } finally {
        busy = false;
        _changed();
      }
    });
    _queue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  /// 重启时不猜测风扇已关闭，也不把停留在后台的时间补成使用时长。
  Future<void> initialize() async {
    await db.transaction((txn) async {
      await txn.update(
        'usage_records',
        {'status': 'interrupted', 'duration': null},
        where:
            "status IN ('pending', 'active_unverified', 'active_uncertain') AND source != 'test'",
      );
      await txn.update('usage_sessions', {
        'status': 'interrupted',
        'duration': null,
        'updated_at': _now(),
      }, where: "status IN ('pending', 'active_unverified')");
    });
  }

  Future<void> startFan(
    int fan, {
    required String userId,
    int? beforeState,
    String? scene,
  }) => _serial(
    () =>
        _startFan(fan, userId: userId, beforeState: beforeState, scene: scene),
  );

  /// 一个推荐组合共用一次使用前状态；任一路启动失败时不把部分启动记为完成。
  Future<void> startCombination(
    Iterable<int> fans, {
    required String userId,
    int? beforeState,
    String? scene,
  }) => _serial(() async {
    final requested = fans.toSet().toList()..sort();
    if (requested.isEmpty) throw ArgumentError('推荐组合不能为空');
    for (final fan in requested) {
      _validateFan(fan);
      if (scentForFan(fan).trim().isEmpty) throw StateError('请先配置气味');
    }
    if (_sessionId != null) throw StateError('请先结束当前使用');
    try {
      for (final fan in requested) {
        await _startFan(
          fan,
          userId: userId,
          beforeState: beforeState,
          scene: scene,
        );
      }
    } catch (_) {
      if (_sessionId != null) {
        try {
          if (connected()) await send('alloff');
        } catch (_) {}
        await _interrupt('推荐组合未能完整启动，设备状态需要确认');
      }
      rethrow;
    }
  });

  /// 开发测试入口：生成一条明确标记的完整模拟会话，不发送 BLE。
  Future<String> createRecommendationSimulation(
    Iterable<int> fans, {
    required String userId,
    required int durationSeconds,
    int? beforeState,
    String? scene,
  }) {
    late String created;
    return _serial(() async {
      final requested = fans.toSet().toList()..sort();
      if (_sessionId != null || _active.isNotEmpty) {
        throw StateError('请先结束当前使用');
      }
      if (requested.isEmpty ||
          durationSeconds <= 0 ||
          durationSeconds > 86400) {
        throw ArgumentError('模拟组合或时长无效');
      }
      _validateScale(beforeState);
      for (final fan in requested) {
        _validateFan(fan);
        if (scentForFan(fan).trim().isEmpty) throw StateError('请先配置气味');
      }
      final end = _now();
      final start = end - durationSeconds * 1000;
      created = const Uuid().v4();
      await db.transaction((txn) async {
        await txn.insert('usage_sessions', {
          'id': created,
          'user_id': userId,
          'start_time': start,
          'end_time': end,
          'duration': durationSeconds,
          'scent_snapshot': '[]',
          'scene': scene,
          'before_state': beforeState,
          'before_state_source': beforeState == null ? null : 'before_use',
          'status': 'completed_unverified',
          'source': 'recommendation_simulation',
          'created_at': end,
          'updated_at': end,
        });
        for (final fan in requested) {
          await txn.insert('usage_records', {
            'session_id': created,
            'start_time': start,
            'end_time': end,
            'duration': durationSeconds,
            'fan_id': fan,
            'scent_name': scentForFan(fan).trim(),
            'created_at': end,
            'source': 'recommendation_simulation',
            'status': 'completed_unverified',
          });
        }
        await _snapshot(txn, created);
      });
      lastFinished = created;
    }).then((_) => created);
  }

  Future<void> _startFan(
    int fan, {
    required String userId,
    int? beforeState,
    String? scene,
  }) async {
    _validateFan(fan);
    _validateScale(beforeState);
    if (!connected()) throw StateError('请先连接蓝牙设备');
    if (_owner != null && _owner != userId) throw StateError('请先结束上一位用户的使用');
    if (_active.containsKey(fan)) return;
    final scent = scentForFan(fan).trim();
    if (scent.isEmpty) throw StateError('请先配置气味');
    final isNew = _sessionId == null;
    final session = _sessionId ?? const Uuid().v4();
    final start = _now();
    final record = await db.transaction((txn) async {
      if (isNew) {
        await txn.insert('usage_sessions', {
          'id': session,
          'user_id': userId,
          'start_time': start,
          'scent_snapshot': '[]',
          'scene': scene,
          'before_state': beforeState,
          'before_state_source': beforeState == null ? null : 'before_use',
          'status': 'pending',
          'created_at': start,
          'updated_at': start,
        });
      }
      return txn.insert('usage_records', {
        'session_id': session,
        'start_time': start,
        'fan_id': fan,
        'scent_name': scent,
        'created_at': start,
        'source': 'app_command_unverified',
        'status': 'pending',
      });
    });
    try {
      // 复用既有取消定时协议，避免上一轮硬件定时关闭本轮新使用。
      await send('fan${fan}_cancel');
      await send('fan${fan}on');
      if (!connected()) throw StateError('发送期间连接已断开');
      final activated = _now();
      await db.transaction((txn) async {
        await txn.update(
          'usage_records',
          {'status': 'active_unverified', 'start_time': activated},
          where: 'id = ?',
          whereArgs: [record],
        );
        await txn.update(
          'usage_sessions',
          {
            'status': 'active_unverified',
            'updated_at': activated,
            if (isNew) 'start_time': activated,
          },
          where: 'id = ?',
          whereArgs: [session],
        );
        await _snapshot(txn, session);
      });
      _sessionId = session;
      _owner = userId;
      _active[fan] = record;
    } catch (_) {
      // 写入异常不能证明硬件没有动作，保留失败尝试但不给成功时长。
      await db.transaction((txn) async {
        await txn.update(
          'usage_records',
          {'status': 'failed', 'duration': null},
          where: 'id = ?',
          whereArgs: [record],
        );
        if (isNew) {
          await txn.update(
            'usage_sessions',
            {'status': 'failed', 'updated_at': _now()},
            where: 'id = ?',
            whereArgs: [session],
          );
        }
      });
      rethrow;
    }
  }

  Future<void> stopFan(int fan) => _serial(() => _stop(fan));

  Future<void> _stop(int fan, {int? deadline}) async {
    _validateFan(fan);
    if (!connected()) throw StateError('连接已断开，无法确认关闭');
    try {
      await send('fan${fan}off');
      if (!connected()) throw StateError('发送期间连接已断开');
    } catch (_) {
      if (_active.containsKey(fan)) {
        await db.update(
          'usage_records',
          {'status': 'active_uncertain'},
          where: 'id = ?',
          whereArgs: [_active[fan]],
        );
      }
      rethrow;
    }
    final record = _active[fan];
    if (record == null) return;
    try {
      await _finishRecords([fan], deadline: deadline);
    } catch (_) {
      await _interrupt('关闭指令已发送，但保存失败，使用时长不确定');
      rethrow;
    }
  }

  /// 即使没有本地会话，也允许用户发送全部关闭以恢复设备状态。
  Future<void> stopAll() => _serial(() async {
    if (!connected()) throw StateError('请先连接蓝牙设备');
    try {
      await send('alloff');
      if (!connected()) throw StateError('发送期间连接已断开');
    } catch (_) {
      if (_sessionId != null) {
        await db.update(
          'usage_records',
          {'status': 'active_uncertain'},
          where: "session_id = ? AND status = 'active_unverified'",
          whereArgs: [_sessionId],
        );
      }
      rethrow;
    }
    if (_active.isNotEmpty) {
      try {
        await _finishRecords(_active.keys.toList());
      } catch (_) {
        await _interrupt('关闭指令已发送，但保存失败，使用时长不确定');
        rethrow;
      }
    }
  });

  Future<void> _finishRecords(List<int> fans, {int? deadline}) async {
    final session = _sessionId!;
    final now = _now();
    final finalFans = _active.length == fans.length;
    await db.transaction((txn) async {
      for (final fan in fans) {
        final record = (await txn.query(
          'usage_records',
          where: 'id = ?',
          whereArgs: [_active[fan]],
        )).single;
        final start = record['start_time'] as int;
        final uncertain = record['status'] != 'active_unverified';
        await txn.update(
          'usage_records',
          {
            'end_time': deadline ?? now,
            'duration': deadline == null && !uncertain
                ? ((now - start).clamp(0, now) ~/ 1000)
                : null,
            'status': deadline != null
                ? 'timer_elapsed_unverified'
                : uncertain
                ? 'completed_estimated'
                : 'completed_unverified',
            'timer_end_time': null,
          },
          where: 'id = ?',
          whereArgs: [_active[fan]],
        );
      }
      await _snapshot(txn, session);
      if (finalFans) {
        final rows = await txn.query(
          'usage_records',
          where: 'session_id = ?',
          whereArgs: [session],
        );
        final uncertain = rows.any(
          (r) => r['status'] != 'completed_unverified',
        );
        final sessionRow = (await txn.query(
          'usage_sessions',
          where: 'id = ?',
          whereArgs: [session],
        )).single;
        await txn.update(
          'usage_sessions',
          {
            'end_time': deadline ?? now,
            'duration': uncertain
                ? null
                : ((now - (sessionRow['start_time'] as int)) ~/ 1000),
            'status': uncertain
                ? 'completed_estimated'
                : 'completed_unverified',
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [session],
        );
      }
    });
    for (final fan in fans) {
      _active.remove(fan);
      _timers.remove(fan)?.cancel();
      _deadlines.remove(fan);
    }
    if (finalFans) {
      lastFinished = session;
      _sessionId = null;
      _owner = null;
    }
  }

  /// 快照保存每路气味与起止区间，组合变化不被抹平成一个配方。
  Future<void> _snapshot(DatabaseExecutor txn, String session) async {
    final rows = await txn.query(
      'usage_records',
      where: 'session_id = ? AND status != ?',
      whereArgs: [session, 'failed'],
      orderBy: 'start_time, id',
    );
    await txn.update(
      'usage_sessions',
      {
        'scent_snapshot': jsonEncode(rows),
        'combination_key': rows.length == 1 ? rows.first['scent_name'] : null,
        'updated_at': _now(),
      },
      where: 'id = ?',
      whereArgs: [session],
    );
  }

  Future<void> setTimer(int fan, int milliseconds) => _serial(() async {
    _validateFan(fan);
    if (!_active.containsKey(fan)) throw StateError('该风扇没有正在进行的使用');
    if (!connected()) throw StateError('请先连接蓝牙设备');
    if (milliseconds < 0 ||
        milliseconds > const Duration(hours: 24).inMilliseconds) {
      throw ArgumentError('定时时长超出范围');
    }
    try {
      await send(
        milliseconds == 0 ? 'fan${fan}_cancel' : 'fan${fan}_off_$milliseconds',
      );
      if (!connected()) throw StateError('发送期间连接已断开');
    } catch (_) {
      await db.update(
        'usage_records',
        {'status': 'active_uncertain'},
        where: 'id = ?',
        whereArgs: [_active[fan]],
      );
      rethrow;
    }
    final deadline = milliseconds == 0 ? null : _now() + milliseconds;
    try {
      await db.update(
        'usage_records',
        {'timer_end_time': deadline},
        where: 'id = ?',
        whereArgs: [_active[fan]],
      );
    } catch (_) {
      await _interrupt('定时指令已发送，但保存失败，使用时长不确定');
      rethrow;
    }
    _timers.remove(fan)?.cancel();
    _deadlines.remove(fan);
    if (deadline != null) {
      _deadlines[fan] = deadline;
      _timers[fan] = Timer(Duration(milliseconds: milliseconds), () {
        expireTimer(fan, deadline).catchError((Object e) {
          lastError = '$e';
          _changed();
        });
      });
    }
  });

  /// deadline 标识本次定时；被取消或替换的旧回调不能结束新的使用。
  Future<void> expireTimer(int fan, int deadline) => _serial(() async {
    if (_deadlines[fan] != deadline || !_active.containsKey(fan)) return;
    if (_now() < deadline) return;
    try {
      await _stop(fan, deadline: deadline);
    } catch (_) {
      await _interrupt('定时已到，无法确认设备关闭；请重新连接后手动关闭');
      rethrow;
    }
  });

  Future<void> interrupt(String reason) => _serial(() => _interrupt(reason));
  Future<void> _interrupt(String reason) async {
    if (_sessionId == null) return;
    final session = _sessionId!;
    await db.transaction((txn) async {
      await txn.update(
        'usage_records',
        {'status': 'interrupted', 'duration': null},
        where:
            "session_id = ? AND status IN ('pending', 'active_unverified', 'active_uncertain')",
        whereArgs: [session],
      );
      await _snapshot(txn, session);
      await txn.update(
        'usage_sessions',
        {'status': 'interrupted', 'duration': null, 'updated_at': _now()},
        where: 'id = ?',
        whereArgs: [session],
      );
    });
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _deadlines.clear();
    _active.clear();
    _sessionId = null;
    _owner = null;
    lastFinished = session;
    lastError = reason;
  }

  Future<List<Map<String, Object?>>> feedbackSessions(String userId) =>
      db.rawQuery(
        '''
    SELECT s.*, f.id AS feedback_id FROM usage_sessions s
    LEFT JOIN usage_feedback f ON f.session_id = s.id
    WHERE s.user_id = ? AND s.status IN ('completed_unverified', 'completed_estimated', 'interrupted')
    ORDER BY s.start_time DESC
  ''',
        [userId],
      );

  Future<Map<String, Object?>> feedbackDetail(
    String sessionId,
    String userId,
  ) async {
    final rows = await db.rawQuery(
      '''SELECT s.*, f.id AS feedback_id, f.after_state, f.liking,
      f.reuse_intent, f.note FROM usage_sessions s
      LEFT JOIN usage_feedback f ON f.session_id = s.id
      WHERE s.id = ? AND s.user_id = ?''',
      [sessionId, userId],
    );
    if (rows.isEmpty) throw StateError('没有此用户的使用记录');
    return rows.single;
  }

  Future<List<int>> recordIds(String sessionId, String userId) async {
    await feedbackDetail(sessionId, userId);
    final rows = await db.query(
      'usage_records',
      columns: ['id'],
      where: 'session_id = ? AND status != ?',
      whereArgs: [sessionId, 'failed'],
    );
    return rows.map((r) => r['id'] as int).toList();
  }

  Future<void> saveFeedback({
    required String sessionId,
    required String userId,
    int? beforeState,
    int? afterState,
    int? liking,
    int? reuseIntent,
    String? note,
  }) => _serial(() async {
    for (final value in [beforeState, afterState, liking]) {
      _validateScale(value);
    }
    if (reuseIntent != null && (reuseIntent < 0 || reuseIntent > 2)) {
      throw ArgumentError('再次使用意愿超出范围');
    }
    if ((note?.length ?? 0) > 500) throw ArgumentError('感受请控制在 500 字以内');
    await db.transaction((txn) async {
      final rows = await txn.query(
        'usage_sessions',
        where: 'id = ? AND user_id = ?',
        whereArgs: [sessionId, userId],
      );
      if (rows.isEmpty ||
          ![
            'completed_unverified',
            'completed_estimated',
            'interrupted',
          ].contains(rows.single['status'])) {
        throw StateError('无法为此会话保存反馈');
      }
      final session = rows.single;
      if (session['before_state_source'] == 'before_use' &&
          beforeState != session['before_state']) {
        throw StateError('使用前已记录的状态不能事后改写');
      }
      final now = _now();
      if (session['before_state_source'] != 'before_use') {
        await txn.update(
          'usage_sessions',
          {
            'before_state': beforeState,
            'before_state_source': beforeState == null ? null : 'recalled',
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [sessionId],
        );
      }
      final existing = await txn.query(
        'usage_feedback',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      final values = {
        'after_state': afterState,
        'liking': liking,
        'reuse_intent': reuseIntent,
        'note': note?.trim(),
        'updated_at': now,
      };
      if (existing.isEmpty) {
        await txn.insert('usage_feedback', {
          ...values,
          'session_id': sessionId,
          'created_at': now,
        });
      } else {
        await txn.update(
          'usage_feedback',
          values,
          where: 'session_id = ?',
          whereArgs: [sessionId],
        );
      }
      await txn.rawInsert(
        '''INSERT INTO preference_profiles (user_id, input_version, status, updated_at)
        VALUES (?, 1, 'pending', ?) ON CONFLICT(user_id) DO UPDATE SET
        input_version = input_version + 1, status = 'pending', updated_at = excluded.updated_at''',
        [userId, now],
      );
    });
  });

  static void _validateFan(int fan) {
    if (fan < 1 || fan > 4) throw ArgumentError('风扇编号无效');
  }

  static void _validateScale(int? value) {
    if (value != null && (value < 1 || value > 5)) {
      throw ArgumentError('状态或评分必须为 1～5');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
