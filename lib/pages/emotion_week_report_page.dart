import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/care_service.dart';
import 'AIScentAssistantPage.dart';
import 'emotion_week_chart_page.dart';
import 'diary_edit_page.dart';

/// 情绪周报页面 - 100%读取真实气味记忆数据
class EmotionWeekReportPage extends StatefulWidget {
  const EmotionWeekReportPage({Key? key}) : super(key: key);

  @override
  State<EmotionWeekReportPage> createState() => _EmotionWeekReportPageState();
}

class _EmotionWeekReportPageState extends State<EmotionWeekReportPage> {
  String _selectedPeriod = '本周';
  List<Map<String, dynamic>> _weekData = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeekData();
  }

  /// 加载周报数据 - 从本地存储读取真实数据
  Future<void> _loadWeekData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final memoryStrings = prefs.getStringList('smell_memories') ?? [];

      // 解析所有气味记忆
      final allMemories = memoryStrings
          .map((str) {
            try {
              return json.decode(str) as Map<String, dynamic>;
            } catch (e) {
              print('解析记忆失败: $e');
              return null;
            }
          })
          .where((m) => m != null)
          .cast<Map<String, dynamic>>()
          .toList();

      // 【修改】不再限制本周，而是显示所有有记录的日期
      // 按日期分组（YYYY-MM-DD格式）
      final memoriesByDate = <String, List<Map<String, dynamic>>>{};
      for (final memory in allMemories) {
        final timestamp = memory['timestamp'] as String?;
        if (timestamp == null) continue;
        final dateStr = timestamp.split(' ')[0]; // "2026-04-24"
        memoriesByDate.putIfAbsent(dateStr, () => []).add(memory);
      }

      // 【修改】只显示有实际数据的日期，按日期倒序排列
      final dayLabels = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
      final weekData = <Map<String, dynamic>>[];

      // 获取所有有记录的日期，按日期倒序排列（最新的在前）
      final sortedDates = memoriesByDate.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      for (final dateStr in sortedDates) {
        final dayMemories = memoriesByDate[dateStr]!;
        final date = DateTime.parse(dateStr);
        final displayDate =
            '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
        final dayOfWeek = dayLabels[date.weekday % 7];

        // 统计当天场景和情绪
        final sceneCount = <String, int>{};
        final emotionCount = <String, int>{};
        for (final memory in dayMemories) {
          final scene = memory['scene'] as String?;
          if (scene != null && scene.isNotEmpty) {
            sceneCount[scene] = (sceneCount[scene] ?? 0) + 1;
          }
          final emoji = memory['emoji'] as String?;
          if (emoji != null && emoji.isNotEmpty) {
            emotionCount[emoji] = (emotionCount[emoji] ?? 0) + 1;
          }
        }

        // 找出当天高频场景
        String topScene = '无';
        int maxScene = 0;
        sceneCount.forEach((scene, count) {
          if (count > maxScene) {
            maxScene = count;
            topScene = scene;
          }
        });

        // 找出当天高频情绪
        String topEmotion = '😌';
        int maxEmotion = 0;
        emotionCount.forEach((emoji, count) {
          if (count > maxEmotion) {
            maxEmotion = count;
            topEmotion = emoji;
          }
        });

        // 获取第一条的笔记
        String? diary;
        if (dayMemories.isNotEmpty) {
          diary = dayMemories.first['note'] as String?;
        }

        weekData.add({
          'date': displayDate,
          'dayOfWeek': dayOfWeek,
          'count': dayMemories.length,
          'topScene': topScene,
          'emotion': topEmotion,
          'diary': diary,
          'memories': dayMemories,
        });
      }

      // 计算本周汇总
      int totalCount = 0;
      final allSceneCount = <String, int>{};
      final allEmotionCount = <String, int>{};
      final negativeEmojis = ['😤', '😭', '😡', '😔', '😖'];
      int negativeCount = 0;

      for (final day in weekData) {
        final count = day['count'] as int;
        totalCount += count;

        final dayMemories = day['memories'] as List<Map<String, dynamic>>;
        for (final memory in dayMemories) {
          final scene = memory['scene'] as String?;
          if (scene != null && scene.isNotEmpty) {
            allSceneCount[scene] = (allSceneCount[scene] ?? 0) + 1;
          }
          final emoji = memory['emoji'] as String?;
          if (emoji != null && emoji.isNotEmpty) {
            allEmotionCount[emoji] = (allEmotionCount[emoji] ?? 0) + 1;
            if (negativeEmojis.contains(emoji)) {
              negativeCount++;
            }
          }
        }
      }

      // 找出本周TOP1场景
      String topScene = '无';
      int maxSceneCount = 0;
      allSceneCount.forEach((scene, count) {
        if (count > maxSceneCount) {
          maxSceneCount = count;
          topScene = scene;
        }
      });

      // 生成系统结论
      String conclusion = '本周情绪稳定，继续保持';
      if (totalCount < 3) {
        conclusion = '最近很少使用，别忘了给自己一点疗愈时间';
      } else if (allSceneCount['疲惫舒缓'] != null && allSceneCount['疲惫舒缓']! >= 3) {
        conclusion = '本周压力偏高，需要关注休息';
      } else if (allSceneCount['助眠安神'] != null && allSceneCount['助眠安神']! >= 3) {
        conclusion = '本周睡眠质量一般，试试延长疗愈时长';
      } else if (totalCount > 0 && negativeCount / totalCount >= 0.5) {
        conclusion = '本周情绪偏低落，多给自己一点时间';
      }

      setState(() {
        _weekData = weekData;
        _summary = {
          'totalCount': totalCount,
          'topScene': topScene,
          'conclusion': conclusion,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('加载周报数据失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 切换周期间隔
  void _togglePeriod() {
    setState(() {
      _selectedPeriod = _selectedPeriod == '本周' ? '上周' : '本周';
    });
    _loadWeekData();
  }

  /// 写今日心情 - 跳转到日记编辑页面
  void _writeDiary(int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DiaryEditPage()),
    );
    // 如果保存成功，刷新数据
    if (result == true) {
      _loadWeekData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EB),
      appBar: AppBar(
        title: Text(
          '情绪周报',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2D2D2D),
          ),
        ),
        backgroundColor: const Color(0xFFF5F0EB),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 周期间隔切换
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedPeriod,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2D2D2D),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _togglePeriod,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA8D8B9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _selectedPeriod == '本周' ? '查看上周' : '查看本周',
                          style: TextStyle(color: const Color(0xFF2D2D2D)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 汇总卡片（点击跳转到曲线图页面）
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EmotionWeekChartPage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '本周汇总',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2D2D2D),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Color(0xFFA8D8B9),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildSummaryItem(
                                    '总使用次数',
                                    '${_summary['totalCount'] ?? 0}',
                                  ),
                                  _buildSummaryItem(
                                    'TOP1场景',
                                    '${_summary['topScene'] ?? '无'}',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildConclusionItem(
                                '系统结论',
                                '${_summary['conclusion'] ?? '无'}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 每日数据
                  Text(
                    '每日详情',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2D2D2D),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 遍历7天数据
                  for (int i = 0; i < _weekData.length; i++)
                    _buildDayCard(_weekData[i], i),

                  const SizedBox(height: 32),

                  // AI聊天入口
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AIScentAssistantPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA8D8B9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      icon: const Text('💬'),
                      label: Text(
                        '和我聊一聊 · AI情绪陪伴',
                        style: TextStyle(color: const Color(0xFF2D2D2D)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// 构建汇总项
  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: const Color(0xFF8C8C8C)),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2D2D2D),
          ),
        ),
      ],
    );
  }

  /// 构建系统结论项（支持文字换行）
  Widget _buildConclusionItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: const Color(0xFF8C8C8C)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2D2D2D),
            ),
            textAlign: TextAlign.center,
            softWrap: true,
          ),
        ),
      ],
    );
  }

  /// 构建每日卡片
  Widget _buildDayCard(Map<String, dynamic> dayData, int index) {
    final count = dayData['count'] as int;
    final topScene = dayData['topScene'] as String;
    final emotion = dayData['emotion'] as String;
    final diary = dayData['diary'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${dayData['date']} ${dayData['dayOfWeek']}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D2D2D),
                ),
              ),
              Text(
                count > 0 ? '使用 $count 次' : '无记录',
                style: TextStyle(
                  fontSize: 12,
                  color: count > 0
                      ? const Color(0xFF8C8C8C)
                      : const Color(0xFFCCCCCC),
                ),
              ),
            ],
          ),
          if (count > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (topScene != '无')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8D5B7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      topScene,
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF2D2D2D),
                      ),
                    ),
                  ),
                if (topScene != '无') const SizedBox(width: 8),
                Text(emotion, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ],
          if (diary != null && diary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F0EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                diary,
                style: TextStyle(fontSize: 14, color: const Color(0xFF2D2D2D)),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.bottomRight,
            child: TextButton(
              onPressed: () => _writeDiary(index),
              child: const Text(
                '✏️ 写今日心情',
                style: TextStyle(color: Color(0xFFA8D8B9)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
