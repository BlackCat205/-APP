import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/ScentMemory.dart';
import '../services/ScentMemoryService.dart';

class ScentMemoryPage extends StatefulWidget {
  const ScentMemoryPage({super.key});

  @override
  State<ScentMemoryPage> createState() => _ScentMemoryPageState();
}

class _ScentMemoryPageState extends State<ScentMemoryPage> {
  final ScentMemoryService _memoryService = ScentMemoryService();
  List<ScentMemory> _memories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  // 初始化数据库并加载数据
  Future<void> _initDatabase() async {
    try {
      await _memoryService.init();
      _loadMemories();
    } catch (e) {
      print('初始化数据库失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 加载记忆数据
  void _loadMemories() {
    setState(() {
      _memories = _memoryService.getAllMemories();
      _isLoading = false;
    });
  }

  // 删除记忆
  Future<void> _deleteMemory(String id) async {
    try {
      await _memoryService.deleteMemory(id);
      _loadMemories();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('记忆已删除')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除失败，请重试')),
      );
    }
  }

  // 清空所有记忆
  Future<void> _clearAllMemories() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空记忆'),
        content: const Text('确定要清空所有气味记忆吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _memoryService.clearAllMemories();
                _loadMemories();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('所有记忆已清空')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('清空失败，请重试')),
                );
              }
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 格式化时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的气味记忆'),
        actions: [
          if (_memories.isNotEmpty)
            IconButton(
              onPressed: _clearAllMemories,
              icon: const Icon(Icons.delete_sweep),
              tooltip: '清空所有记忆',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                _loadMemories();
              },
              child: _memories.isEmpty
                  ? const Center(
                      child: Text('暂无气味记忆'),
                    )
                  : ListView.builder(
                      itemCount: _memories.length,
                      itemBuilder: (context, index) {
                        final memory = _memories[index];
                        return Dismissible(
                          key: Key(memory.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) {
                            _deleteMemory(memory.id);
                          },
                          child: ListTile(
                            title: Text(
                              '情绪: ${memory.emotion}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('推荐气味: ${memory.scent}'),
                                Text('原话: ${memory.userInput}'),
                                Text(
                                  _formatDateTime(memory.timestamp),
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
