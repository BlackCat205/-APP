import 'package:flutter/material.dart';
import '../../database/dao/scent_diary_note_dao.dart';
import '../../database/models/scent_diary_note.dart';

/// 气味日记页面，展示日记列表并提供新增、编辑、删除功能。
class ScentDiaryPage extends StatefulWidget {
  const ScentDiaryPage({super.key});

  @override
  State<ScentDiaryPage> createState() => _ScentDiaryPageState();
}

class _ScentDiaryPageState extends State<ScentDiaryPage> {
  final ScentDiaryNoteDAO _dao = ScentDiaryNoteDAO();

  List<ScentDiaryNote> _notes = [];
  bool _isLoading = true;

  // ========== 选项常量 ==========
  static const List<String> _moods = [
    '开心', '平静', '疲惫', '焦虑', '压力', '失眠', '愤怒', '悲伤',
  ];
  static const List<String> _scents = [
    '薰衣草', '甜橙', '玫瑰', '柠檬', '茉莉', '薄荷', '檀香',
  ];
  static const List<String> _scenes = [
    '疲惫舒缓', '愉悦治愈', '助眠安神', '提神醒脑', '工作', '学习', '运动', '休闲',
  ];

  // ========== 样式常量 ==========
  static const TextStyle _subtitleStyle = TextStyle(color: Colors.grey);
  static const double _defaultSpacing = 16.0;
  static const double _cardPadding = 16.0;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  /// 从数据库加载日记笔记
  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final notes = await _dao.getAllScentDiaryNotes();
      setState(() => _notes = notes);
    } catch (e) {
      debugPrint('加载气味日记笔记失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 打开新增或编辑日记对话框
  /// [existingNote] 为 null 时新增，否则为编辑已有笔记。
  void _addOrEditNote([ScentDiaryNote? existingNote]) async {
    // 可编辑字段的当前值
    String? selectedMood = existingNote?.mood;
    String? selectedScent = existingNote?.usedScent;
    String? selectedScene = existingNote?.scene;
    final TextEditingController noteController = TextEditingController(
      text: existingNote?.noteContent,
    );

    final bool isEdit = existingNote != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEdit ? '编辑气味日记' : '添加气味日记'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _buildDropdown(
                label: '心情',
                value: selectedMood,
                items: _moods,
                onChanged: (v) => selectedMood = v,
              ),
              const SizedBox(height: _defaultSpacing),
              _buildDropdown(
                label: '使用香气',
                value: selectedScent,
                items: _scents,
                onChanged: (v) => selectedScent = v,
              ),
              const SizedBox(height: _defaultSpacing),
              _buildDropdown(
                label: '场景',
                value: selectedScene,
                items: _scenes,
                onChanged: (v) => selectedScene = v,
              ),
              const SizedBox(height: _defaultSpacing),
              TextField(
                controller: noteController,
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              if (selectedMood != null && selectedScent != null && selectedScene != null) {
                if (isEdit) {
                  // 编辑：创建新对象并更新数据库
                  final updated = ScentDiaryNote(
                    id: existingNote!.id,
                    mood: selectedMood!,
                    usedScent: selectedScent!,
                    scene: selectedScene!,
                    noteContent: noteController.text,
                    createdAt: existingNote.createdAt,
                  );
                  await _dao.update(updated);
                } else {
                  // 新增
                  final newNote = ScentDiaryNote(
                    mood: selectedMood!,
                    usedScent: selectedScent!,
                    scene: selectedScene!,
                    noteContent: noteController.text,
                    createdAt: DateTime.now().millisecondsSinceEpoch,
                  );
                  await _dao.insert(newNote);
                }
                _loadNotes();
                if (mounted) Navigator.pop(dialogContext);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 构建下拉选择表单项
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }

  /// 删除指定 ID 的日记笔记
  void _deleteNote(int id) async {
    await _dao.delete(id);
    _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 新增按钮
        Padding(
          padding: const EdgeInsets.all(_defaultSpacing),
          child: ElevatedButton(
            onPressed: () => _addOrEditNote(),
            child: const Text('添加气味日记'),
          ),
        ),
        // 笔记列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(_defaultSpacing),
            itemCount: _notes.length,
            itemBuilder: (_, index) => _buildNoteCard(_notes[index]),
          ),
        ),
      ],
    );
  }

  /// 构建单条日记卡片
  Widget _buildNoteCard(ScentDiaryNote note) {
    final dateStr = DateTime.fromMillisecondsSinceEpoch(note.createdAt)
        .toString()
        .substring(0, 16);

    return Card(
      margin: const EdgeInsets.only(bottom: _defaultSpacing),
      child: Padding(
        padding: const EdgeInsets.all(_cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 心情（大号标题）
            Text(
              note.mood,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // 使用香气
            _buildInfoRow('使用香气: ', note.usedScent),
            const SizedBox(height: 8),
            // 场景
            _buildInfoRow('场景: ', note.scene),
            const SizedBox(height: 8),
            // 感受文字
            Text(note.noteContent, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 8),
            // 创建时间
            _buildInfoRow('创建时间: ', dateStr),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建标题+内容的行（用于固定提示文字）
  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: _subtitleStyle),
        Expanded(child: Text(value)),
      ],
    );
  }
}