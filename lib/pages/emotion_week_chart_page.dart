import 'dart:math';
import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../services/usage_record_service.dart';

/// 情绪周报曲线图页面
class EmotionWeekChartPage extends StatefulWidget {
  const EmotionWeekChartPage({Key? key}) : super(key: key);

  @override
  State<EmotionWeekChartPage> createState() => _EmotionWeekChartPageState();
}

class _EmotionWeekChartPageState extends State<EmotionWeekChartPage> {
  String _selectedPeriod = '本周';
  List<Map<String, dynamic>> _weekData = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;

  // 5个固定表情包对应关系
  final Map<String, Map<String, dynamic>> _emojiMap = {
    '1': {'emoji': '😌', 'label': '平静安稳', 'color': Colors.blue[100]!},
    '2': {'emoji': '😊', 'label': '愉悦轻松', 'color': Colors.green[100]!},
    '3': {'emoji': '😔', 'label': '低落难过', 'color': Colors.purple[100]!},
    '4': {'emoji': '😰', 'label': '焦虑压力', 'color': Colors.red[100]!},
    '5': {'emoji': '😴', 'label': '困倦想睡', 'color': Colors.yellow[100]!},
  };

  @override
  void initState() {
    super.initState();
    _loadWeekData();
  }

  /// 加载周报数据 - 从气味瞬间表读取心情数据
  Future<void> _loadWeekData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = await AppDatabase().database;

      // 计算本周和上周的时间范围
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfLastWeek = startOfWeek.subtract(Duration(days: 7));

      final startTimestamp = _selectedPeriod == '本周'
          ? startOfWeek.millisecondsSinceEpoch
          : startOfLastWeek.millisecondsSinceEpoch;
      final endTimestamp = _selectedPeriod == '本周'
          ? now.millisecondsSinceEpoch
          : startOfWeek.subtract(Duration(seconds: 1)).millisecondsSinceEpoch;

      // 从气味瞬间表查询数据（获取心情数据）
      final records = await db.query(
        'smell_moment_record',
        where: 'created_at >= ? AND created_at < ?',
        whereArgs: [startTimestamp, endTimestamp],
        orderBy: 'created_at ASC',
      );

      // 按日期分组
      final recordsByDate = <String, List<Map<String, dynamic>>>{};
      for (final record in records) {
        final timestamp = record['created_at'] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        recordsByDate.putIfAbsent(dateStr, () => []).add(record);
      }

      // 生成一周7天的数据
      final weekData = <Map<String, dynamic>>[];
      final dayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

      for (int i = 0; i < 7; i++) {
        final targetDate = _selectedPeriod == '本周'
            ? startOfWeek.add(Duration(days: i))
            : startOfLastWeek.add(Duration(days: i));
        final dateStr =
            '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
        final dayRecords = recordsByDate[dateStr] ?? [];

        // 统计当天情绪分布（从气味瞬间表的 emotion_emoji 字段）
        final emotionCount = <String, int>{};
        final scentCount = <String, int>{};

        for (final record in dayRecords) {
          final emotion = record['emotion_emoji'] as String?;
          if (emotion != null && emotion.isNotEmpty) {
            emotionCount[emotion] = (emotionCount[emotion] ?? 0) + 1;
          }
          final scent = record['scent_name'] as String?;
          if (scent != null && scent.isNotEmpty) {
            scentCount[scent] = (scentCount[scent] ?? 0) + 1;
          }
        }

        // 找出当天最常见的情绪（从气味瞬间表统计）
        String topEmotion = ''; // 无记录时为空
        int maxEmotionCount = 0;
        if (dayRecords.isNotEmpty) {
          emotionCount.forEach((emotion, count) {
            if (count > maxEmotionCount) {
              maxEmotionCount = count;
              topEmotion = emotion;
            }
          });
        }

        // 找出当天最常见的气味
        String topScent = '无';
        int maxScentCount = 0;
        scentCount.forEach((scent, count) {
          if (count > maxScentCount) {
            maxScentCount = count;
            topScent = scent;
          }
        });

        weekData.add({
          'date': dateStr,
          'displayDate': '${targetDate.month}.${targetDate.day}',
          'dayOfWeek': dayLabels[i],
          'count': dayRecords.length,
          'topEmotion': topEmotion,
          'topScent': topScent,
          'records': dayRecords,
        });
      }

      // 计算周报汇总
      // 使用 CardTriggerRecordService 获取本周卡片弹出次数（与 EmotionWeekReportPage 一致）
      int totalCount = await CardTriggerRecordService.getWeekRecordCount();

      // 获取本周最常用气味（与 EmotionWeekReportPage 一致）
      String mostCommonScent = '无';
      final weeklyScentStats = await UsageRecordService.getWeeklyScentStats();
      if (weeklyScentStats.isNotEmpty) {
        mostCommonScent = weeklyScentStats.first['scent_name'] as String;
      }

      final allEmotionCount = <String, int>{};

      for (final record in records) {
        final emotion = record['emotion_emoji'] as String?;
        if (emotion != null && emotion.isNotEmpty) {
          allEmotionCount[emotion] = (allEmotionCount[emotion] ?? 0) + 1;
        }
      }

      // 找出本周最常见的情绪（从气味瞬间表统计）
      String mostCommonEmotion = '😌';
      int maxEmotion = 0;
      allEmotionCount.forEach((emotion, count) {
        if (count > maxEmotion) {
          maxEmotion = count;
          mostCommonEmotion = emotion;
        }
      });

      // 生成智能分析结论
      String analysisConclusion = _generateAnalysisConclusion(
        allEmotionCount,
        totalCount,
      );

      setState(() {
        _weekData = weekData;
        _summary = {
          'totalCount': totalCount,
          'mostCommonEmotion': mostCommonEmotion,
          'mostCommonScent': mostCommonScent,
          'analysisConclusion': analysisConclusion,
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

  /// 生成智能分析结论（使用 emoji 格式的情绪数据）
  String _generateAnalysisConclusion(
    Map<String, int> emotionCount,
    int totalCount,
  ) {
    if (totalCount == 0) {
      return '本周暂无使用记录，记得给自己一点疗愈时间';
    }

    // 计算各情绪占比（使用 emoji 格式）
    final negativeEmotions = ['😔', '😰', '😤', '😭', '😡', '😖']; // 负面情绪
    int negativeCount = 0;
    negativeEmotions.forEach((emotion) {
      negativeCount += emotionCount[emotion] ?? 0;
    });

    final positiveEmotions = ['😌', '😊']; // 平静安稳、愉悦轻松
    int positiveCount = 0;
    positiveEmotions.forEach((emotion) {
      positiveCount += emotionCount[emotion] ?? 0;
    });

    if (negativeCount / totalCount >= 0.5) {
      return '本周情绪偏低落，建议多使用舒缓类香氛，给自己更多放松时间';
    } else if (positiveCount / totalCount >= 0.7) {
      return '本周心情愉悦，继续保持良好状态';
    } else if (emotionCount['😴'] != null && emotionCount['😴']! >= 3) {
      return '本周较为困倦，建议调整作息时间，使用提神类香氛';
    } else {
      return '本周情绪稳定，继续保持规律的使用习惯';
    }
  }

  /// 切换周期间隔
  void _togglePeriod() {
    setState(() {
      _selectedPeriod = _selectedPeriod == '本周' ? '上周' : '本周';
    });
    _loadWeekData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题和周期选择
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 返回按钮
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA8D8B9).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.arrow_back,
                                size: 18,
                                color: Color(0xFF2D2D2D),
                              ),
                              SizedBox(width: 4),
                              Text(
                                '返回',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF2D2D2D),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 页面标题
                      const Expanded(
                        child: Text(
                          '情绪周报',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D2D2D),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 周期切换按钮
                      GestureDetector(
                        onTap: _togglePeriod,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA8D8B9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _selectedPeriod == '本周' ? '查看上周' : '查看本周',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 周报汇总卡片
                  Container(
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
                        Text(
                          '本周心情曲线',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2D2D2D),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '本周最常见心情',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: const Color(0xFF8C8C8C),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_summary['mostCommonEmotion'] ?? '😌'}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF2D2D2D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '本周最常用气味',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: const Color(0xFF8C8C8C),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _summary['mostCommonScent'] ?? '无',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF2D2D2D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '本周使用次数',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: const Color(0xFF8C8C8C),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_summary['totalCount'] ?? 0} 次',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF2D2D2D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Text(
                          '智能分析结论',
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF8C8C8C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _summary['analysisConclusion'] ?? '暂无数据',
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF2D2D2D),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 心情变化曲线图
                  Container(
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
                      children: [
                        Text(
                          '心情变化曲线',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2D2D2D),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // 心情变化曲线图 - 正方形自适应
                        AspectRatio(
                          aspectRatio: 1.0,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            child: CustomPaint(
                              painter: _EmotionChartPainter(
                                weekData: _weekData,
                                emojiMap: _emojiMap,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

/// 情绪曲线图绘制器
class _EmotionChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> weekData;
  final Map<String, Map<String, dynamic>> emojiMap;

  _EmotionChartPainter({required this.weekData, required this.emojiMap});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    // 正方形布局：左右边距给竖轴标签留空间
    final leftPadding = 70.0;
    final rightPadding = 12.0;
    final topPadding = 12.0;
    final bottomPadding = 50.0;
    final chartWidth = width - leftPadding - rightPadding;
    final chartHeight = height - topPadding - bottomPadding;

    // 绘制网格
    final gridPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 1;

    // 竖轴网格（5条水平线）
    for (int i = 0; i < 6; i++) {
      final y = topPadding + i * (chartHeight / 5);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(width - rightPadding, y),
        gridPaint,
      );
    }

    // 横轴网格（7条垂直线 + 边界线）
    for (int i = 0; i < 8; i++) {
      final x = leftPadding + i * (chartWidth / 7);
      canvas.drawLine(
        Offset(x, topPadding),
        Offset(x, height - bottomPadding),
        gridPaint,
      );
    }

    // 绘制竖轴标签（左侧）- 文字标签在左，表情包在右
    final labelTextStyle = TextStyle(
      fontSize: 11,
      color: const Color(0xFF2D2D2D),
    );

    // 竖轴顺序：从上到下依次为：焦虑压力(4)、低落难过(3)、困倦想睡(5)、愉悦轻松(2)、平静安稳(1)
    final emotions = ['4', '3', '5', '2', '1'];
    for (int i = 0; i < emotions.length; i++) {
      final emotion = emotions[i];
      final y = topPadding + i * (chartHeight / 5) + (chartHeight / 10);

      // 先绘制文字标签（最左侧）
      final labelSpan = TextSpan(
        text: emojiMap[emotion]?['label'],
        style: labelTextStyle,
      );
      final labelPainter = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(4, y - labelPainter.height / 2));

      // 再绘制表情包（文字标签右侧，保持间距）
      final emojiSpan = TextSpan(
        text: emojiMap[emotion]?['emoji'],
        style: TextStyle(fontSize: 14),
      );
      final emojiPainter = TextPainter(
        text: emojiSpan,
        textDirection: TextDirection.ltr,
      );
      emojiPainter.layout();
      emojiPainter.paint(
        canvas,
        Offset(4 + labelPainter.width + 6, y - emojiPainter.height / 2),
      );
    }

    // 绘制横轴标签（底部）
    for (int i = 0; i < weekData.length; i++) {
      final dayData = weekData[i];
      final x = leftPadding + i * (chartWidth / 7) + (chartWidth / 14);

      // 绘制日期（如 4.26）
      final dateSpan = TextSpan(
        text: dayData['displayDate'],
        style: TextStyle(fontSize: 10, color: const Color(0xFF2D2D2D)),
      );
      final datePainter = TextPainter(
        text: dateSpan,
        textDirection: TextDirection.ltr,
      );
      datePainter.layout();
      datePainter.paint(
        canvas,
        Offset(x - datePainter.width / 2, height - bottomPadding + 5),
      );

      // 绘制星期（如 周一）
      final daySpan = TextSpan(
        text: dayData['dayOfWeek'],
        style: TextStyle(fontSize: 9, color: const Color(0xFF8C8C8C)),
      );
      final dayPainter = TextPainter(
        text: daySpan,
        textDirection: TextDirection.ltr,
      );
      dayPainter.layout();
      dayPainter.paint(
        canvas,
        Offset(x - dayPainter.width / 2, height - bottomPadding + 18),
      );
    }

    // 绘制曲线
    if (weekData.isNotEmpty) {
      final curvePaint = Paint()
        ..color = const Color(0xFFA8D8B9)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      // 情绪值到竖轴位置的映射（基于竖轴顺序）
      final emotionToY = (String emotion) {
        if (emotion == '4') return 0; // 焦虑压力
        if (emotion == '3') return 1; // 低落难过
        if (emotion == '5') return 2; // 困倦想睡
        if (emotion == '2') return 3; // 愉悦轻松
        if (emotion == '1') return 4; // 平静安稳
        return 4; // 默认平静安稳
      };

      Offset? lastPoint;

      for (int i = 0; i < weekData.length; i++) {
        final dayData = weekData[i];
        final topEmotion = dayData['topEmotion'] as String;
        final x = leftPadding + i * (chartWidth / 7) + (chartWidth / 14);

        if (topEmotion.isNotEmpty) {
          // 有数据的天
          final yIndex = emotionToY(topEmotion);
          final y =
              topPadding + yIndex * (chartHeight / 5) + (chartHeight / 10);
          final currentPoint = Offset(x, y);

          // 绘制线段（如果上一个点存在）
          if (lastPoint != null) {
            canvas.drawLine(lastPoint, currentPoint, curvePaint);
          }

          // 绘制数据点
          canvas.drawCircle(
            currentPoint,
            5,
            Paint()..color = const Color(0xFFA8D8B9),
          );

          // 在点上方绘制表情包
          final emoji = emojiMap[topEmotion]?['emoji'] ?? '😌';
          final emojiSpan = TextSpan(
            text: emoji,
            style: TextStyle(fontSize: 18),
          );
          final emojiPainter = TextPainter(
            text: emojiSpan,
            textDirection: TextDirection.ltr,
          );
          emojiPainter.layout();
          emojiPainter.paint(
            canvas,
            Offset(x - emojiPainter.width / 2, y - 24),
          );

          lastPoint = currentPoint;
        } else {
          // 无数据的天，曲线断开
          lastPoint = null;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
