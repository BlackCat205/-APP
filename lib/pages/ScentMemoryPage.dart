import 'package:flutter/material.dart';
import '../models/ScentMemory.dart';
import '../services/ScentMemoryService.dart';

/// 气味记忆列表页面（Hive 存储）
class ScentMemoryPage extends StatefulWidget {
  const ScentMemoryPage({super.key});

  @override
  State<ScentMemoryPage> createState() => _ScentMemoryPageState();
}

class _ScentMemoryPageState extends State<ScentMemoryPage> {
  final ScentMemoryService _memoryService = ScentMemoryService();
  List<ScentMemory> _memories = [];
  bool _isLoading = true;

  // ========== 常量 ==========
  static const String _title = '我的气味记忆';
  static const Color _deleteBackground = Colors.red;
  static const TextStyle _emotionStyle = TextStyle(fontWeight: FontWeight.bold);
  static const TextStyle _timestampStyle =
  TextStyle(color: Colors.grey, fontSize: 12);

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      await _memoryService.init();
      _loadMemories();
    } catch (e) {
      debugPrint('初始化数据库失败: $e');
      setState(() => _isLoading = false);
    }
  }

  void _loadMemories() {
    setState(() {
      _memories = _memoryService.getAllMemories();
      _isLoading = false;
    });
  }

  Future<void> _deleteMemory(String id) async {
    try {
      await _memoryService.deleteMemory(id);
      _loadMemories();
      _showSnackBar('记忆已删除');
    } catch (e) {
      _showSnackBar('删除失败，请重试');
    }
  }

  Future<void> _clearAllMemories() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空记忆'),
        content: const Text('确定要清空所有气味记忆吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _memoryService.clearAllMemories();
      _loadMemories();
      _showSnackBar('所有记忆已清空');
    } catch (e) {
      _showSnackBar('清空失败，请重试');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(_title),
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
        onRefresh: () async => _loadMemories(),
        child: _memories.isEmpty
            ? const Center(child: Text('暂无气味记忆'))
            : ListView.builder(
          itemCount: _memories.length,
          itemBuilder: (_, index) => _buildMemoryItem(_memories[index]),
        ),
      ),
    );
  }

  Widget _buildMemoryItem(ScentMemory memory) {
    return Dismissible(
      key: Key(memory.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: _deleteBackground,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteMemory(memory.id),
      child: ListTile(
        title: Text('情绪: ${memory.emotion}', style: _emotionStyle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('推荐气味: ${memory.scent}'),
            Text('原话: ${memory.userInput}'),
            Text(_formatDateTime(memory.timestamp), style: _timestampStyle),
          ],
        ),
      ),
    );
  }
}