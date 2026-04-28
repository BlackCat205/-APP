import 'package:flutter/material.dart';
import '../../database/dao/emotion_scent_memory_dao.dart';
import '../../database/models/emotion_scent_memory.dart';

/// 情绪气味记忆页面
class EmotionScentPage extends StatefulWidget {
  const EmotionScentPage({super.key});

  @override
  State<EmotionScentPage> createState() => _EmotionScentPageState();
}

class _EmotionScentPageState extends State<EmotionScentPage> {
  final EmotionScentMemoryDAO _dao = EmotionScentMemoryDAO();
  List<EmotionScentMemory> _memories = [];
  bool _isLoading = true;

  final List<String> _emotions = ['开心', '疲惫', '焦虑', '压力', '失眠', '愤怒', '悲伤', '平静'];
  final List<String> _scents = ['薰衣草', '甜橙', '玫瑰', '柠檬', '茉莉', '薄荷', '檀香'];
  final List<String> _feedbacks = ['好用', '一般', '不好用'];

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  /// 加载情绪气味记忆
  Future<void> _loadMemories() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final memories = await _dao.getAllEmotionScentMemories();
      setState(() {
        _memories = memories;
      });
    } catch (e) {
      print('加载情绪气味记忆失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 添加情绪气味记忆
  void _addMemory() async {
    String? selectedEmotion;
    String? selectedScent;
    String? selectedFeedback;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加情绪气味记忆'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                // 情绪类型
                DropdownButtonFormField<String>(
                  value: selectedEmotion,
                  hint: const Text('选择情绪类型'),
                  items: _emotions.map((emotion) {
                    return DropdownMenuItem<String>(
                      value: emotion,
                      child: Text(emotion),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedEmotion = value;
                  },
                  decoration: const InputDecoration(labelText: '情绪类型'),
                ),
                const SizedBox(height: 16),
                // 有效香气
                DropdownButtonFormField<String>(
                  value: selectedScent,
                  hint: const Text('选择有效香气'),
                  items: _scents.map((scent) {
                    return DropdownMenuItem<String>(
                      value: scent,
                      child: Text(scent),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedScent = value;
                  },
                  decoration: const InputDecoration(labelText: '有效香气'),
                ),
                const SizedBox(height: 16),
                // 用户反馈
                DropdownButtonFormField<String>(
                  value: selectedFeedback,
                  hint: const Text('选择用户反馈'),
                  items: _feedbacks.map((feedback) {
                    return DropdownMenuItem<String>(
                      value: feedback,
                      child: Text(feedback),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedFeedback = value;
                  },
                  decoration: const InputDecoration(labelText: '用户反馈'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                if (selectedEmotion != null && selectedScent != null && selectedFeedback != null) {
                  final memory = EmotionScentMemory(
                    emotion: selectedEmotion!,
                    effectiveScent: selectedScent!,
                    userFeedback: selectedFeedback!,
                    useCount: 1,
                    createdAt: DateTime.now().millisecondsSinceEpoch,
                  );
                  await _dao.insertOrUpdate(memory);
                  _loadMemories();
                  Navigator.pop(context);
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  /// 删除情绪气味记忆
  void _deleteMemory(int id) async {
    await _dao.delete(id.toString());
    _loadMemories();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // 添加按钮
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _addMemory,
                  child: const Text('添加情绪气味记忆'),
                ),
              ),
              // 记忆列表
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _memories.length,
                  itemBuilder: (context, index) {
                    final memory = _memories[index];
                    return _buildMemoryCard(memory);
                  },
                ),
              ),
            ],
          );
  }

  /// 构建情绪气味记忆卡片
  Widget _buildMemoryCard(EmotionScentMemory memory) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 情绪类型
            Text(
              memory.emotion,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // 有效香气
            Row(
              children: [
                const Text('有效香气: ', style: TextStyle(color: Colors.grey)),
                Text(memory.effectiveScent),
              ],
            ),
            const SizedBox(height: 8),
            // 用户反馈
            Row(
              children: [
                const Text('用户反馈: ', style: TextStyle(color: Colors.grey)),
                Text(memory.userFeedback),
              ],
            ),
            const SizedBox(height: 8),
            // 使用次数
            Row(
              children: [
                const Text('使用次数: ', style: TextStyle(color: Colors.grey)),
                Text('${memory.useCount}次'),
              ],
            ),
            const SizedBox(height: 8),
            // 创建时间
            Row(
              children: [
                const Text('创建时间: ', style: TextStyle(color: Colors.grey)),
                Text(
                  DateTime.fromMillisecondsSinceEpoch(memory.createdAt)
                      .toString()
                      .substring(0, 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 删除按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => _deleteMemory(memory.id!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
