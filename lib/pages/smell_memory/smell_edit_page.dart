import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../services/usage_record_service.dart';

/// 气味瞬间编辑页
class SmellEditPage extends StatefulWidget {
  final List<int> usageRecordIds; // 使用记录ID列表（外键关联）
  final List<String>? scentList; // 去重后的气味列表（直接传入，避免重新查询）

  const SmellEditPage({
    Key? key,
    this.usageRecordIds = const [],
    this.scentList,
  }) : super(key: key);

  @override
  State<SmellEditPage> createState() => _SmellEditPageState();
}

class _SmellEditPageState extends State<SmellEditPage> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedEmoji;
  String? _selectedScene; // 场景标签
  String _scentCombo = ''; // 气味组合
  final List<String> _emojis = ['😌', '🥰', '😭', '😤', '😴'];
  final List<String> _scenes = ['下班回家', '工作学习', '睡前', '周末放松', '其他'];

  // 从体验页传入的数据
  final String _duration = '00:30:00';
  final List<String> _recipe = ['薰衣草', '檀香', '雪松'];

  @override
  void initState() {
    super.initState();
    _selectedScene = '下班回家'; // 默认场景
    _loadFanScents(); // 加载风扇气味配置
  }

  /// 加载风扇气味配置（优先使用传入的去重后列表）
  void _loadFanScents() async {
    // 如果已传入去重后的气味列表，直接使用
    if (widget.scentList != null && widget.scentList!.isNotEmpty) {
      setState(() {
        _scentCombo = widget.scentList!.join('/');
      });
      return;
    }

    // 否则从数据库加载（兼容旧的调用方式）
    try {
      final records = await UsageRecordService.getRecordsByIds(
        widget.usageRecordIds,
      );
      // 按风扇ID去重
      final scentMap = <int, String>{};
      for (final record in records) {
        if (record.scentName != null && record.scentName!.isNotEmpty) {
          scentMap.putIfAbsent(record.fanId, () => record.scentName!);
        }
      }
      setState(() {
        _scentCombo = scentMap.values.join('/');
      });
    } catch (e) {
      print('加载气味配置失败: $e');
      setState(() {
        _scentCombo = '薰衣草/檀香/雪松/甜橙';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EB),
      appBar: AppBar(
        title: Text(
          '编辑瞬间',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2D2D2D),
          ),
        ),
        backgroundColor: const Color(0xFFF5F0EB),
        elevation: 0,
        leading: TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('取消', style: TextStyle(color: const Color(0xFF2D2D2D))),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题输入
            Text(
              '为这个瞬间起个名字',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: '给你的瞬间起个名字',
                hintStyle: TextStyle(color: const Color(0xFF8C8C8C)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              style: TextStyle(fontSize: 16, color: const Color(0xFF2D2D2D)),
            ),
            const SizedBox(height: 24),

            // 场景标签选择
            Text(
              '场景标签',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedScene,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down),
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color(0xFF2D2D2D),
                  ),
                  items: _scenes.map((scene) {
                    return DropdownMenuItem<String>(
                      value: scene,
                      child: Text(scene),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedScene = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 本次气味（只读显示）
            Text(
              '本次气味',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8D5B7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _scentCombo.isEmpty ? '加载中...' : _scentCombo,
                style: TextStyle(fontSize: 16, color: const Color(0xFF2D2D2D)),
              ),
            ),
            const SizedBox(height: 24),

            // 心情选择
            Text(
              '此刻心情',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _emojis.map((emoji) {
                  bool isSelected = _selectedEmoji == emoji;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedEmoji = isSelected ? null : emoji;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFA8D8B9)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
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
            const SizedBox(height: 24),

            // 备注输入
            Text(
              '写下此刻的感受',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '此刻的感受值得被气味封存...',
                hintStyle: TextStyle(color: const Color(0xFF8C8C8C)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              style: TextStyle(fontSize: 16, color: const Color(0xFF2D2D2D)),
            ),
            const SizedBox(height: 24),

            // 自动记录卡片
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 日期时间
                  Row(
                    children: [
                      const Text('📅 '),
                      Text(
                        _getCurrentDateTime(),
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF2D2D2D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 场景标签
                  Row(
                    children: [
                      const Text('🏷 '),
                      Text(
                        _selectedScene ?? '未知',
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF2D2D2D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 时长
                  Row(
                    children: [
                      const Text('⏱ '),
                      Text(
                        _duration,
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF2D2D2D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 配方
                  Row(
                    children: [
                      const Text('🧪 '),
                      Text(
                        _recipe.join('/'),
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF2D2D2D),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFFF5F0EB),
          border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saveSmellMemory,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA8D8B9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              '保存',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2D2D2D),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 获取当前日期时间
  String _getCurrentDateTime() {
    final now = DateTime.now();
    return '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  /// 保存气味记忆到新表 smell_moment_record
  void _saveSmellMemory() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 获取现有记忆列表（保持原有逻辑兼容）
      final existingMemories = prefs.getStringList('smell_memories') ?? [];

      // 创建新记忆
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

      // 添加到列表
      existingMemories.add(json.encode(newMemory));

      // 保存到本地存储
      await prefs.setStringList('smell_memories', existingMemories);

      // 保存到新表 smell_moment_record
      await SmellMomentRecordService.insertRecord(
        title: _titleController.text.isEmpty ? '未命名' : _titleController.text,
        sceneTag: _selectedScene,
        emotionEmoji: _selectedEmoji,
        note: _noteController.text,
        scentCombo: _scentCombo,
      );

      // 直接返回首页
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      print('保存失败: $e');
      // 显示错误提示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
    }
  }
}
