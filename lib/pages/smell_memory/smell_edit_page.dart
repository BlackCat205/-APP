import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../services/usage_record_service.dart';
import '../../database/database_helper.dart';

/// 气味瞬间编辑页
class SmellEditPage extends StatefulWidget {
  const SmellEditPage({Key? key}) : super(key: key);

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

  /// 加载风扇气味配置
  void _loadFanScents() async {
    try {
      final dbHelper = DatabaseHelper();
      final configs = await dbHelper.getAllFanConfigs();
      if (configs.isNotEmpty) {
        final scents = configs.map((c) => c['scent_name'] as String?).toList();
        setState(() {
          _scentCombo = scents
              .where((s) => s != null && s.isNotEmpty)
              .join('/');
        });
      } else {
        // 使用默认配置
        setState(() {
          _scentCombo = '薰衣草/檀香/雪松/甜橙';
        });
      }
    } catch (e) {
      print('加载风扇配置失败: $e');
      // 使用默认配置
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

  /// 保存气味记忆
  void _saveSmellMemory() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 获取现有记忆列表
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

      // 同步更新 usage_records 表
      await _updateUsageRecord();

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

  /// 更新 usage_records 表
  Future<void> _updateUsageRecord() async {
    try {
      // 获取最新的使用记录
      final records = await UsageRecordService.getAllRecords(limit: 1);
      if (records.isNotEmpty) {
        final latestRecord = records.first;
        await UsageRecordService.addSceneAndEmotion(
          recordId: latestRecord.id!,
          sceneTag: _selectedScene,
          emotionEmoji: _selectedEmoji,
        );
        print(
          '✅ 已同步更新 usage_records: scene=$_selectedScene, emoji=$_selectedEmoji',
        );
      }
    } catch (e) {
      print('更新 usage_records 失败: $e');
    }
  }
}
