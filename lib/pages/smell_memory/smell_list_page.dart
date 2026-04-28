import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 气味记忆列表页
class SmellListPage extends StatefulWidget {
  const SmellListPage({Key? key}) : super(key: key);

  @override
  State<SmellListPage> createState() => _SmellListPageState();
}

class _SmellListPageState extends State<SmellListPage>
    with AutomaticKeepAliveClientMixin {
  Map<String, List<Map<String, dynamic>>> _groupedMemories = {};
  List<String> _sortedDates = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 当页面可见时重新加载数据
    _loadMemories();
  }

  /// 加载记忆列表
  Future<void> _loadMemories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memoryStrings = prefs.getStringList('smell_memories') ?? [];

      // 解析记忆数据
      final memories = memoryStrings
          .map((str) {
            try {
              // 尝试解析为JSON
              return json.decode(str) as Map<String, dynamic>;
            } catch (e) {
              // 如果JSON解析失败，尝试解析旧的字符串格式
              try {
                return _parseOldMemoryString(str);
              } catch (e2) {
                print('解析记忆失败: $e2');
                return <String, dynamic>{};
              }
            }
          })
          .where((map) => map.isNotEmpty)
          .toList();

      // 按日期分组
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final memory in memories) {
        final timestamp = memory['timestamp'] as String?;
        if (timestamp != null) {
          final date = timestamp.split(' ')[0];
          if (!grouped.containsKey(date)) {
            grouped[date] = [];
          }
          grouped[date]!.add(memory);
        }
      }

      // 按日期倒序排列
      final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

      setState(() {
        _groupedMemories = grouped;
        _sortedDates = sortedDates;
        _isLoading = false;
      });
    } catch (e) {
      print('加载记忆失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 解析旧的记忆字符串格式
  Map<String, dynamic> _parseOldMemoryString(String str) {
    try {
      // 移除首尾的大括号
      final cleanStr = str.substring(1, str.length - 1);
      // 分割键值对
      final pairs = cleanStr.split(', ');
      final map = <String, dynamic>{};

      for (final pair in pairs) {
        final parts = pair.split(': ');
        if (parts.length == 2) {
          final key = parts[0].replaceAll("'", '');
          final value = parts[1].replaceAll("'", '');
          map[key] = value;
        }
      }

      return map;
    } catch (e) {
      print('解析旧格式记忆失败: $e');
      return {};
    }
  }

  /// 获取星期几
  String _getWeekday(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        final weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
        return weekdays[date.weekday % 7];
      }
    } catch (e) {
      print('解析日期失败: $e');
    }
    return '';
  }

  /// 显示记忆详情
  void _showMemoryDetail(Map<String, dynamic> memory) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            memory['title'] ?? '未命名',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2D2D2D),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (memory['emoji'] != null && memory['emoji']!.isNotEmpty)
                  Text(memory['emoji']!, style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('📅 '),
                    Text(memory['timestamp']?.split(' ')[0] ?? ''),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [const Text('🏷 '), Text(memory['scene'] ?? '未知')],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('⏱ '),
                    Text(memory['duration'] ?? '未知'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('🧪 '),
                    Text(memory['recipe']?.replaceAll(',', '/') ?? '未知'),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '笔记:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  memory['note']?.isNotEmpty ?? false
                      ? memory['note']!
                      : '(无笔记)',
                  style: TextStyle(color: const Color(0xFF2D2D2D)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('关闭'),
            ),
            TextButton(
              onPressed: () {
                _deleteMemory(memory);
                Navigator.pop(context);
              },
              child: Text(
                '删除',
                style: TextStyle(color: const Color(0xFFE07A5F)),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 删除记忆
  void _deleteMemory(Map<String, dynamic> memory) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memoryStrings = prefs.getStringList('smell_memories') ?? [];

      // 找到要删除的记忆
      final id = memory['id'] as String?;
      if (id != null) {
        final updatedMemories = memoryStrings.where((str) {
          try {
            // 尝试解析为JSON
            final map = json.decode(str) as Map<String, dynamic>;
            return map['id'] != id;
          } catch (e) {
            // 如果JSON解析失败，尝试解析旧的字符串格式
            try {
              final map = _parseOldMemoryString(str);
              return map['id'] != id;
            } catch (e2) {
              print('解析记忆失败: $e2');
              return true;
            }
          }
        }).toList();

        // 保存更新后的列表
        await prefs.setStringList('smell_memories', updatedMemories);

        // 重新加载数据
        _loadMemories();
      }
    } catch (e) {
      print('删除记忆失败: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EB),
      appBar: AppBar(
        title: Text(
          '气味记忆',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2D2D2D),
          ),
        ),
        backgroundColor: const Color(0xFFF5F0EB),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/');
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupedMemories.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🌿', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text(
                    '还没有气味瞬间，开始你的第一次气味之旅吧',
                    style: TextStyle(
                      fontSize: 16,
                      color: const Color(0xFF8C8C8C),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _sortedDates.length,
              itemBuilder: (context, dateIndex) {
                final date = _sortedDates[dateIndex];
                final memories = _groupedMemories[date]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 日期分组标题
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '📅 ${date.replaceAll('-', '.')} ${_getWeekday(date)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2D2D2D),
                        ),
                      ),
                    ),

                    // 记忆卡片
                    ...memories.map((memory) {
                      return GestureDetector(
                        onTap: () {
                          _showMemoryDetail(memory);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              // 大号emoji
                              Container(
                                margin: const EdgeInsets.only(right: 16),
                                child: Text(
                                  memory['emoji'] ?? '😌',
                                  style: const TextStyle(fontSize: 40),
                                ),
                              ),

                              // 右侧内容
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 记忆标题
                                    Text(
                                      memory['title'] ?? '未命名',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF2D2D2D),
                                      ),
                                    ),
                                    const SizedBox(height: 4),

                                    // 场景·时长
                                    Text(
                                      '${memory['scene'] ?? '未知'} · ${memory['duration'] ?? '未知'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: const Color(0xFF8C8C8C),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // 分割线
                                    Container(
                                      height: 1,
                                      color: const Color(0xFFF5F0EB),
                                    ),
                                    const SizedBox(height: 8),

                                    // 笔记预览
                                    Text(
                                      memory['note']?.isNotEmpty ?? false
                                          ? memory['note']!
                                          : '(无笔记)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: const Color(0xFF2D2D2D),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
    );
  }
}
