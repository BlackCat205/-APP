import 'package:flutter/material.dart';
import '../database/dao/scent_diary_note_dao.dart';
import '../database/models/scent_diary_note.dart';

/// 日记编辑页面
class DiaryEditPage extends StatefulWidget {
  const DiaryEditPage({Key? key}) : super(key: key);

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

  final List<String> _moods = ['好困', '疲惫', '焦虑', '平静', '愉悦', '难过', '压力', '失眠'];
  final List<String> _scents = ['薰衣草', '甜橙', '玫瑰', '柠檬', '茉莉', '薄荷', '檀香', '雪松'];
  final List<String> _scenes = ['工作学习', '下班回家', '睡前', '周末放松', '其他'];

  @override
  void initState() {
    super.initState();
    // 获取今天的日期作为默认值
    final now = DateTime.now();
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写完整信息'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 创建日记笔记
      final note = ScentDiaryNote(
        mood: _selectedMood!,
        usedScent: _selectedScent!,
        scene: _selectedScene!,
        noteContent: _noteController.text,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      // 保存到数据库
      final result = await _dao.insert(note);

      if (result > 0) {
        // 保存成功，返回上一页
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存失败'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print('保存日记失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EB),
      appBar: AppBar(
        title: Text(
          '写今日心情',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2D2D2D),
          ),
        ),
        backgroundColor: const Color(0xFFF5F0EB),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF2D2D2D)),
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
                      color: Color(0xFFA8D8B9),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期显示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20, color: Color(0xFF8C8C8C)),
                  const SizedBox(width: 12),
                  Text(
                    _getTodayDateString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 心情选择
            const Text(
              '今日心情',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _moods.map((mood) {
                final isSelected = _selectedMood == mood;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMood = mood;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFA8D8B9) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFA8D8B9) : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Text(
                      mood,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? Colors.white : const Color(0xFF2D2D2D),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 使用香氛
            const Text(
              '使用香氛',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _scents.map((scent) {
                final isSelected = _selectedScent == scent;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedScent = scent;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE8D5B7) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFE8D5B7) : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Text(
                      scent,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? const Color(0xFF2D2D2D) : const Color(0xFF8C8C8C),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 使用场景
            const Text(
              '使用场景',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _scenes.map((scene) {
                final isSelected = _selectedScene == scene;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedScene = scene;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFD5E8D4) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF82B366) : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Text(
                      scene,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? const Color(0xFF2D2D2D) : const Color(0xFF8C8C8C),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 日记内容
            const Text(
              '日记内容',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _noteController,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: '记录你的心情和感受...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Color(0xFFBDBDBD)),
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2D2D2D),
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveDiary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA8D8B9),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
            ),
          ],
        ),
      ),
    );
  }
}
