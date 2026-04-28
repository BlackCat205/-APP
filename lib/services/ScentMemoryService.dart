import 'package:hive/hive.dart';
import '../models/ScentMemory.dart';

class ScentMemoryService {
  static const String _boxName = 'scent_memory';
  late Box<ScentMemory> _box;

  // 初始化数据库
  Future<void> init() async {
    // 注册适配器
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ScentMemoryAdapter());
    }
    // 打开盒子
    _box = await Hive.openBox<ScentMemory>(_boxName);
  }

  // 保存一条记忆
  Future<void> saveMemory(ScentMemory memory) async {
    await _box.put(memory.id, memory);
  }

  // 查询所有历史记忆（按时间倒序）
  List<ScentMemory> getAllMemories() {
    final memories = _box.values.toList();
    memories.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return memories;
  }

  // 删除单条记忆
  Future<void> deleteMemory(String id) async {
    await _box.delete(id);
  }

  // 清空所有记忆
  Future<void> clearAllMemories() async {
    await _box.clear();
  }

  // 关闭数据库
  Future<void> close() async {
    await _box.close();
  }
}
