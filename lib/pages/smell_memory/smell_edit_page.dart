import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/usage_record_service.dart';

/// 气味瞬间编辑页
class SmellEditPage extends StatefulWidget {
  final List<int> usageRecordIds;
  final List<String>? scentList;

  const SmellEditPage({
    super.key,
    this.usageRecordIds = const [],
    this.scentList,
  });

  @override
  State<SmellEditPage> createState() => _SmellEditPageState();
}

class _SmellEditPageState extends State<SmellEditPage> {
  // ========== 控制器与状态 ==========
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String? _selectedEmoji;
  String? _selectedScene;
  String _scentCombo = '';
  int? _selectedScore;

  // ========== 选项常量 ==========
  static const List<String> _emojis = ['😌', '🥰', '😭', '😤', '😴'];
  static const List<String> _scenes = ['下班回家', '工作学习', '睡前', '周末放松', '其他'];

  // ========== 固定数据（演示用） ==========
  static const String _duration = '00:30:00';
  static const List<String> _recipe = ['薰衣草', '檀香', '雪松'];

  // ========== 样式常量 ==========
  static const Color _bgColor = Color(0xFFF5F0EB);
  static const Color _textColor = Color(0xFF2D2D2D);
  static const Color _greyTextColor = Color(0xFF8C8C8C);
  static const Color _accentGreen = Color(0xFFA8D8B9);
  static const Color _starGold = Color(0xFFFFD700);
  static const Color _starGrey = Color(0xFFD0D0D0);
  static const Color _scentBgColor = Color(0xFFE8D5B7);
  static const double _defaultRadius = 8.0;
  static const double _cardRadius = 12.0;

  @override
  void initState() {
    super.initState();
    _selectedScene = _scenes.first; // 默认场景
    _loadFanScents();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// 加载风扇气味配置（优先使用传入列表，其次从数据库按 ID 查询）
  void _loadFanScents() async {
    if (widget.scentList != null && widget.scentList!.isNotEmpty) {
      setState(() => _scentCombo = widget.scentList!.join('/'));
      return;
    }

    try {
      final records = await UsageRecordService.getRecordsByIds(widget.usageRecordIds);
      final scentMap = <int, String>{};
      for (final record in records) {
        if (record.scentName != null && record.scentName!.isNotEmpty) {
          scentMap.putIfAbsent(record.fanId, () => record.scentName!);
        }
      }
      setState(() => _scentCombo = scentMap.values.join('/'));
    } catch (e) {
      debugPrint('加载气味配置失败: $e');
      setState(() => _scentCombo = '薰衣草/檀香/雪松/甜橙');
    }
  }

  // ========== 构建 UI ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitleSection(),
            const SizedBox(height: 24),
            _buildSceneDropdown(),
            const SizedBox(height: 24),
            _buildScentDisplay(),
            const SizedBox(height: 24),
            _buildEmojiSelector(),
            const SizedBox(height: 24),
            _buildNoteField(),
            const SizedBox(height: 24),
            _buildScoreSelector(),
            const SizedBox(height: 24),
            _buildInfoCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: _buildSaveButton(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        '编辑瞬间',
        style: TextStyle(fontWeight: FontWeight.w600, color: _textColor),
      ),
      backgroundColor: _bgColor,
      elevation: 0,
      leading: TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消', style: TextStyle(color: _textColor)),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '为这个瞬间起个名字',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textColor),
        ),
        const SizedBox(height: 8),
        _styledTextField(
          controller: _titleController,
          hintText: '给你的瞬间起个名字',
        ),
      ],
    );
  }

  Widget _buildSceneDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '场景标签',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textColor),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_defaultRadius),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedScene,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down),
              style: const TextStyle(fontSize: 16, color: _textColor),
              items: _scenes
                  .map((scene) => DropdownMenuItem(value: scene, child: Text(scene)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedScene = value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScentDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '本次气味',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textColor),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _scentBgColor,
            borderRadius: BorderRadius.circular(_defaultRadius),
          ),
          child: Text(
            _scentCombo.isEmpty ? '加载中...' : _scentCombo,
            style: const TextStyle(fontSize: 16, color: _textColor),
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '此刻心情',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textColor),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _emojis.map((emoji) {
              final isSelected = _selectedEmoji == emoji;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedEmoji = isSelected ? null : emoji;
                }),
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? _accentGreen : Colors.white,
                    borderRadius: BorderRadius.circular(_defaultRadius),
                  ),
                  child: Text(
                    emoji,
                    style: TextStyle(fontSize: isSelected ? 32 : 24),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '写下此刻的感受',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textColor),
        ),
        const SizedBox(height: 8),
        _styledTextField(
          controller: _noteController,
          hintText: '此刻的感受值得被气味封存...',
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildScoreSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '本次气味体验情绪效果',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textColor),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final score = index + 1;
            final isFilled = _selectedScore != null && _selectedScore! >= score;
            return GestureDetector(
              onTap: () => setState(() => _selectedScore = score),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  isFilled ? Icons.star : Icons.star_border,
                  size: 40,
                  color: isFilled ? _starGold : _starGrey,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _getScoreLabel(_selectedScore),
            style: const TextStyle(fontSize: 14, color: _greyTextColor),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('📅 ', _getCurrentDateTime()),
          const SizedBox(height: 8),
          _infoRow('🏷 ', _selectedScene ?? '未知'),
          const SizedBox(height: 8),
          _infoRow('⏱ ', _duration),
          const SizedBox(height: 8),
          _infoRow('🧪 ', _recipe.join('/')),
        ],
      ),
    );
  }

  Widget _infoRow(String icon, String text) {
    return Row(
      children: [
        Text(icon),
        Text(
          text,
          style: const TextStyle(fontSize: 14, color: _textColor),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: _bgColor,
        border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saveSmellMemory,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_defaultRadius)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text(
            '保存',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
        ),
      ),
    );
  }

  /// 创建统一样式的文本输入框
  Widget _styledTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: _greyTextColor),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_defaultRadius),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      style: const TextStyle(fontSize: 16, color: _textColor),
    );
  }

  // ========== 工具方法 ==========

  String _getCurrentDateTime() {
    final now = DateTime.now();
    return '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _getScoreLabel(int? score) {
    switch (score) {
      case 1:
        return '1分 - 效果不太好';
      case 2:
        return '2分 - 效果一般';
      case 3:
        return '3分 - 效果还可以';
      case 4:
        return '4分 - 效果不错';
      case 5:
        return '5分 - 效果非常好';
      default:
        return '请选择评分';
    }
  }

  // ========== 保存逻辑 ==========

  void _saveSmellMemory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingMemories = prefs.getStringList('smell_memories') ?? [];

      final newMemory = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': _titleController.text.isEmpty ? '未命名' : _titleController.text,
        'emoji': _selectedEmoji ?? '',
        'note': _noteController.text,
        'timestamp': DateTime.now().toString(),
        'scene': _selectedScene ?? '下班回家',
        'duration': _duration,
        'recipe': _recipe.join(','),
      };

      existingMemories.add(json.encode(newMemory));
      await prefs.setStringList('smell_memories', existingMemories);

      await SmellMomentRecordService.insertRecord(
        title: _titleController.text.isEmpty ? '未命名' : _titleController.text,
        sceneTag: _selectedScene,
        emotionEmoji: _selectedEmoji,
        note: _noteController.text,
        scentCombo: _scentCombo,
        score: _selectedScore,
      );

      if (mounted) Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      debugPrint('保存失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
        );
      }
    }
  }
}