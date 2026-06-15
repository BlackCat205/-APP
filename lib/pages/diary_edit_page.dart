import 'package:flutter/material.dart';
import '../database/dao/scent_diary_note_dao.dart';
import '../database/models/scent_diary_note.dart';

/// 日记编辑页面（新增今日心情日记）
class DiaryEditPage extends StatefulWidget {
  const DiaryEditPage({super.key});

  @override
  State<DiaryEditPage> createState() => _DiaryEditPageState();
}

class _DiaryEditPageState extends State<DiaryEditPage> {
  final ScentDiaryNoteDAO _dao = ScentDiaryNoteDAO();
  final TextEditingController _noteController = TextEditingController();

  String? _selectedMood;
  String? _selectedScent;
  String? _selectedScene;
  bool _isSaving = false;

  // ========== 选项常量 ==========
  static const List<String> _moods = [
    '好困', '疲惫', '焦虑', '平静', '愉悦', '难过', '压力', '失眠',
  ];
  static const List<String> _scents = [
    '薰衣草', '甜橙', '玫瑰', '柠檬', '茉莉', '薄荷', '檀香', '雪松',
  ];
  static const List<String> _scenes = [
    '工作学习', '下班回家', '睡前', '周末放松', '其他',
  ];

  // ========== 样式常量 ==========
  static const Color _bgColor = Color(0xFFF5F0EB);
  static const Color _textColor = Color(0xFF2D2D2D);
  static const Color _greyTextColor = Color(0xFF8C8C8C);
  static const Color _hintTextColor = Color(0xFFBDBDBD);
  static const Color _accentGreen = Color(0xFFA8D8B9);
  static const Color _selectedMoodTextColor = Colors.white;
  static const Color _unselectedBorderColor = Color(0xFFE0E0E0);
  static const Color _selectedScentBg = Color(0xFFE8D5B7);
  static const Color _selectedScentBorder = Color(0xFFE8D5B7);
  static const Color _selectedSceneBg = Color(0xFFD5E8D4);
  static const Color _selectedSceneBorder = Color(0xFF82B366);
  static const double _defaultPadding = 24.0;
  static const double _chipRadius = 20.0;
  static const double _cardRadius = 12.0;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// 获取今天日期字符串
  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
  }

  /// 保存日记
  Future<void> _saveDiary() async {
    if (_selectedMood == null || _selectedScent == null || _selectedScene == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请填写完整信息'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final note = ScentDiaryNote(
        mood: _selectedMood!,
        usedScent: _selectedScent!,
        scene: _selectedScene!,
        noteContent: _noteController.text,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final result = await _dao.insert(note);

      if (!mounted) return;

      if (result > 0) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('保存日记失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(_defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateDisplay(),
            const SizedBox(height: 24),
            _buildChipGroup(
              label: '今日心情',
              items: _moods,
              selectedItem: _selectedMood,
              onSelect: (value) => setState(() => _selectedMood = value),
              selectedBg: _accentGreen,
              selectedBorder: _accentGreen,
              selectedTextColor: _selectedMoodTextColor,
            ),
            const SizedBox(height: 24),
            _buildChipGroup(
              label: '使用香氛',
              items: _scents,
              selectedItem: _selectedScent,
              onSelect: (value) => setState(() => _selectedScent = value),
              selectedBg: _selectedScentBg,
              selectedBorder: _selectedScentBorder,
              selectedTextColor: _textColor,
            ),
            const SizedBox(height: 24),
            _buildChipGroup(
              label: '使用场景',
              items: _scenes,
              selectedItem: _selectedScene,
              onSelect: (value) => setState(() => _selectedScene = value),
              selectedBg: _selectedSceneBg,
              selectedBorder: _selectedSceneBorder,
              selectedTextColor: _textColor,
            ),
            const SizedBox(height: 24),
            _buildNoteField(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        '写今日心情',
        style: TextStyle(fontWeight: FontWeight.w600, color: _textColor),
      ),
      backgroundColor: _bgColor,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.close, color: _textColor),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : _saveDiary,
          child: _isSaving
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text(
            '保存',
            style: TextStyle(
              color: _accentGreen,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 20, color: _greyTextColor),
          const SizedBox(width: 12),
          Text(
            _getTodayDateString(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建通用的选择标签组（心情/香气/场景）
  Widget _buildChipGroup({
    required String label,
    required List<String> items,
    required String? selectedItem,
    required void Function(String) onSelect,
    required Color selectedBg,
    required Color selectedBorder,
    required Color selectedTextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((item) {
            final isSelected = selectedItem == item;
            return GestureDetector(
              onTap: () => onSelect(item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? selectedBg : Colors.white,
                  borderRadius: BorderRadius.circular(_chipRadius),
                  border: Border.all(
                    color: isSelected ? selectedBorder : _unselectedBorderColor,
                  ),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? selectedTextColor : _textColor,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNoteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '日记内容',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_cardRadius),
          ),
          child: TextField(
            controller: _noteController,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '记录你的心情和感受...',
              border: InputBorder.none,
              hintStyle: TextStyle(color: _hintTextColor),
            ),
            style: const TextStyle(
              fontSize: 14,
              color: _textColor,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveDiary,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentGreen,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_cardRadius),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : const Text(
          '保存日记',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}