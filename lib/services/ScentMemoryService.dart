import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/ScentMemory.dart';

/// 气味记忆服务（基于 Hive 的本地存储）
class ScentMemoryService {
  static const String _boxName = 'scent_memory';
  late Box<ScentMemory> _box;
  bool _isInitialized = false;

  /// 初始化 Hive 盒子并注册适配器（如果尚未初始化）
  Future<void> init() async {
    if (_isInitialized) return;
    if (!Hive.isAdapterRegistered(ScentMemoryAdapter().typeId)) {
      Hive.registerAdapter(ScentMemoryAdapter());
    }
    _box = await Hive.openBox<ScentMemory>(_boxName);
    _isInitialized = true;
  }

  /// 确保已初始化，否则执行初始化
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  /// 保存一条气味记忆
  Future<void> saveMemory(ScentMemory memory) async {
    await _ensureInitialized();
    await _box.put(memory.id, memory);
  }

  /// 获取所有记忆，按时间倒序排列
  List<ScentMemory> getAllMemories() {
    if (!_isInitialized) return [];
    final memories = _box.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return memories;
  }

  /// 删除指定 ID 的记忆
  Future<void> deleteMemory(String id) async {
    await _ensureInitialized();
    await _box.delete(id);
  }

  /// 清空所有记忆
  Future<void> clearAllMemories() async {
    await _ensureInitialized();
    await _box.clear();
  }

  /// 关闭数据库盒子
  Future<void> close() async {
    if (_isInitialized) {
      await _box.close();
      _isInitialized = false;
    }
  }
}