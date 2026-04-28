import 'package:flutter/material.dart';
import '../../database/dao/scent_diary_note_dao.dart';
import '../../database/models/scent_diary_note.dart';

/// 气味日记页面
class ScentDiaryPage extends StatefulWidget {
  const ScentDiaryPage({super.key});

  @override
  State<ScentDiaryPage> createState() => _ScentDiaryPageState();
}

class _ScentDiaryPageState extends State<ScentDiaryPage> {
  final ScentDiaryNoteDAO _dao = ScentDiaryNoteDAO();
  List<ScentDiaryNote> _notes = [];
  bool _isLoading = true;

  final List<String> _moods = ['开心', '平静', '疲惫', '焦虑', '压力', '失眠', '愤怒', '悲伤'];
  final List<String> _scents = ['薰衣草', '甜橙', '玫瑰', '柠檬', '茉莉', '薄荷', '檀香'];
  final List<String> _scenes = ['疲惫舒缓', '愉悦治愈', '助眠安神', '提神醒脑', '工作', '学习', '运动', '休闲'];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  /// 加载气味日记笔记
  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final notes = await _dao.getAllScentDiaryNotes();
      setState(() {
        _notes = notes;
      });
    } catch (e) {
      print('加载气味日记笔记失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 添加或编辑日记笔记
  void _addOrEditNote([ScentDiaryNote? note]) async {
    final TextEditingController noteContentController = TextEditingController(
      text: note?.noteContent,
    );

    String? selectedMood = note?.mood;
    String? selectedScent = note?.usedScent;
    String? selectedScene = note?.scene;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(note == null ? '添加气味日记' : '编辑气味日记'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                // 心情
                DropdownButtonFormField<String>(
                  value: selectedMood,
                  hint: const Text('选择心情'),
                  items: _moods.map((mood) {
                    return DropdownMenuItem<String>(
                      value: mood,
                      child: Text(mood),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedMood = value;
                  },
                  decoration: const InputDecoration(labelText: '心情'),
                ),
                const SizedBox(height: 16),
                // 使用香气
                DropdownButtonFormField<String>(
                  value: selectedScent,
                  hint: const Text('选择使用香气'),
                  items: _scents.map((scent) {
                    return DropdownMenuItem<String>(
                      value: scent,
                      child: Text(scent),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedScent = value;
                  },
                  decoration: const InputDecoration(labelText: '使用香气'),
                ),
                const SizedBox(height: 16),
                // 场景
                DropdownButtonFormField<String>(
                  value: selectedScene,
                  hint: const Text('选择场景'),
                  items: _scenes.map((scene) {
                    return DropdownMenuItem<String>(
                      value: scene,
                      child: Text(scene),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedScene = value;
                  },
                  decoration: const InputDecoration(labelText: '场景'),
                ),
                const SizedBox(height: 16),
                // 感受文字
                TextField(
                  controller: noteContentController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '感受文字',
                    hintText: '记录你的感受...',
                  ),
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
                if (selectedMood != null && selectedScent != null && selectedScene != null) {
                  if (note == null) {
                    // 添加
                    final newNote = ScentDiaryNote(
                      mood: selectedMood!,
                      usedScent: selectedScent!,
                      scene: selectedScene!,
                      noteContent: noteContentController.text,
                      createdAt: DateTime.now().millisecondsSinceEpoch,
                    );
                    await _dao.insert(newNote);
                  } else {
                    // 编辑
                    note.mood = selectedMood!;
                    note.usedScent = selectedScent!;
                    note.scene = selectedScene!;
                    note.noteContent = noteContentController.text;
                    await _dao.update(note);
                  }
                  _loadNotes();
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

  /// 删除日记笔记
  void _deleteNote(int id) async {
    await _dao.delete(id);
    _loadNotes();
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
                  onPressed: () => _addOrEditNote(),
                  child: const Text('添加气味日记'),
                ),
              ),
              // 笔记列表
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return _buildNoteCard(note);
                  },
                ),
              ),
            ],
          );
  }

  /// 构建气味日记笔记卡片
  Widget _buildNoteCard(ScentDiaryNote note) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 心情
            Text(
              note.mood,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // 使用香气
            Row(
              children: [
                const Text('使用香气: ', style: TextStyle(color: Colors.grey)),
                Text(note.usedScent),
              ],
            ),
            const SizedBox(height: 8),
            // 场景
            Row(
              children: [
                const Text('场景: ', style: TextStyle(color: Colors.grey)),
                Text(note.scene),
              ],
            ),
            const SizedBox(height: 8),
            // 感受文字
            Text(
              note.noteContent,
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 8),
            // 创建时间
            Row(
              children: [
                const Text('创建时间: ', style: TextStyle(color: Colors.grey)),
                Text(
                  DateTime.fromMillisecondsSinceEpoch(note.createdAt)
                      .toString()
                      .substring(0, 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => _addOrEditNote(note),
                  child: const Text('编辑'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _deleteNote(note.id!),
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
