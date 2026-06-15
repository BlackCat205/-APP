import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../services/usage_record_service.dart';

/// 情绪周报曲线图页面（带自定义绘制）
class EmotionWeekChartPage extends StatefulWidget {
  const EmotionWeekChartPage({super.key});

  @override
  State<EmotionWeekChartPage> createState() => _EmotionWeekChartPageState();
}

class _EmotionWeekChartPageState extends State<EmotionWeekChartPage> {
  String _selectedPeriod = '本周';
  List<Map<String, dynamic>> _weekData = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;

  // 表情与标签、颜色的映射
  static const Map<String, Map<String, dynamic>> _emojiMap = {
    '😌': {'label': '平静安稳', 'color': Color(0xFFBBDEFB)},
    '🥰': {'label': '愉悦轻松', 'color': Color(0xFFC8E6C9)},
    '😭': {'label': '低落难过', 'color': Color(0xFFE1BEE7)},
    '😤': {'label': '焦虑压力', 'color': Color(0xFFFFCDD2)},
    '😴': {'label': '困倦想睡', 'color': Color(0xFFFFF9C4)},
  };

  // ========== 样式常量 ==========
  static const Color _bgColor = Color(0xFFF5F0EB);
  static const Color _textColor = Color(0xFF2D2D2D);
  static const Color _greyTextColor = Color(0xFF8C8C8C);
  static const Color _accentGreen = Color(0xFFA8D8B9);
  static const double _defaultRadius = 8.0;
  static const double _cardRadius = 12.0;

  @override
  void initState() {
    super.initState();
    _loadWeekData();
  }

  Future<void> _loadWeekData() async {
    setState(() => _isLoading = true);
    try {
      final db = await AppDatabase().database;
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfLastWeek = startOfWeek.subtract(const Duration(days: 7));

      final startTimestamp = _selectedPeriod == '本周'
          ? DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day).millisecondsSinceEpoch
          : DateTime(startOfLastWeek.year, startOfLastWeek.month, startOfLastWeek.day).millisecondsSinceEpoch;
      final endTimestamp = _selectedPeriod == '本周'
          ? now.millisecondsSinceEpoch
          : DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day).subtract(const Duration(seconds: 1)).millisecondsSinceEpoch;

      final records = await db.query(
        'smell_moment_record',
        where: 'created_at >= ? AND created_at < ?',
        whereArgs: [startTimestamp, endTimestamp],
        orderBy: 'created_at ASC',
      );

      // 按日期分组
      final recordsByDate = <String, List<Map<String, dynamic>>>{};
      for (final record in records) {
        final ts = record['created_at'] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(ts);
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        recordsByDate.putIfAbsent(dateStr, () => []).add(record);
      }

      // 生成一周7天的数据
      final weekData = <Map<String, dynamic>>[];
      const dayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

      final baseDate = _selectedPeriod == '本周' ? startOfWeek : startOfLastWeek;
      for (int i = 0; i < 7; i++) {
        final targetDate = baseDate.add(Duration(days: i));
        final dateStr =
            '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
        final dayRecords = recordsByDate[dateStr] ?? [];

        final emotionCount = <String, int>{};
        final scentCount = <String, int>{};
        for (final r in dayRecords) {
          final emoji = r['emotion_emoji'] as String?;
          if (emoji != null && emoji.isNotEmpty) {
            emotionCount[emoji] = (emotionCount[emoji] ?? 0) + 1;
          }
          final scent = r['scent_name'] as String?;
          if (scent != null && scent.isNotEmpty) {
            scentCount[scent] = (scentCount[scent] ?? 0) + 1;
          }
        }

        String topEmotion = '';
        int maxEmotion = 0;
        emotionCount.forEach((emoji, count) {
          if (count > maxEmotion) {
            maxEmotion = count;
            topEmotion = emoji;
          }
        });

        String topScent = '无';
        int maxScent = 0;
        scentCount.forEach((scent, count) {
          if (count > maxScent) {
            maxScent = count;
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

      // 汇总统计
      final totalCount = await CardTriggerRecordService.getWeekRecordCount();
      final weeklyScentStats = await UsageRecordService.getWeeklyScentStats();
      final mostCommonScent = (weeklyScentStats.isNotEmpty)
          ? weeklyScentStats.first['scent_name'] as String
          : '无';

      final allEmotionCount = <String, int>{};
      for (final r in records) {
        final emoji = r['emotion_emoji'] as String?;
        if (emoji != null && emoji.isNotEmpty) {
          allEmotionCount[emoji] = (allEmotionCount[emoji] ?? 0) + 1;
        }
      }

      String mostCommonEmotion = '😌';
      int maxEmotionCount = 0;
      allEmotionCount.forEach((emoji, count) {
        if (count > maxEmotionCount) {
          maxEmotionCount = count;
          mostCommonEmotion = emoji;
        }
      });

      final analysisConclusion = _generateAnalysisConclusion(allEmotionCount, totalCount);

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
      debugPrint('加载周报数据失败: $e');
      setState(() => _isLoading = false);
    }
  }

  String _generateAnalysisConclusion(Map<String, int> emotionCount, int totalCount) {
    if (totalCount == 0) return '本周暂无使用记录，记得给自己一点疗愈时间';

    const negativeEmotions = ['😔', '😰', '😤', '😭', '😡', '😖'];
    int negativeCount = 0;
    for (final emotion in negativeEmotions) {
      negativeCount += emotionCount[emotion] ?? 0;
    }

    const positiveEmotions = ['😌', '😊'];
    int positiveCount = 0;
    for (final emotion in positiveEmotions) {
      positiveCount += emotionCount[emotion] ?? 0;
    }

    if (negativeCount / totalCount >= 0.5) {
      return '本周情绪偏低落，建议多使用舒缓类香氛，给自己更多放松时间';
    } else if (positiveCount / totalCount >= 0.7) {
      return '本周心情愉悦，继续保持良好状态';
    } else if ((emotionCount['😴'] ?? 0) >= 3) {
      return '本周较为困倦，建议调整作息时间，使用提神类香氛';
    } else {
      return '本周情绪稳定，继续保持规律的使用习惯';
    }
  }

  void _togglePeriod() {
    setState(() {
      _selectedPeriod = _selectedPeriod == '本周' ? '上周' : '本周';
    });
    _loadWeekData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSummaryCard(),
            const SizedBox(height: 32),
            _buildChartCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _accentGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(_defaultRadius),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, size: 18, color: _textColor),
                SizedBox(width: 4),
                Text(
                  '返回',
                  style: TextStyle(
                    fontSize: 14,
                    color: _textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Expanded(
          child: Text(
            '情绪周报',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _textColor),
            textAlign: TextAlign.center,
          ),
        ),
        GestureDetector(
          onTap: _togglePeriod,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: _accentGreen,
              borderRadius: BorderRadius.all(Radius.circular(_defaultRadius)),
            ),
            child: Text(
              _selectedPeriod == '本周' ? '查看上周' : '查看本周',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本周心情曲线',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textColor),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _summaryRow('本周最常见心情', '${_summary['mostCommonEmotion'] ?? '😌'}')),
              Expanded(child: _summaryRow('本周最常用气味', _summary['mostCommonScent'] ?? '无')),
            ],
          ),
          const SizedBox(height: 16),
          _summaryRow('本周使用次数', '${_summary['totalCount'] ?? 0} 次'),
          const SizedBox(height: 16),
          _conclusionRow('智能分析结论', _summary['analysisConclusion'] ?? '暂无数据'),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: _greyTextColor)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _textColor)),
      ],
    );
  }

  Widget _conclusionRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: _greyTextColor)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, color: _textColor, fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '心情变化曲线',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textColor),
          ),
          const SizedBox(height: 32),
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
    );
  }
}

/// 情绪曲线图绘制器（保持原有逻辑，仅提取常量）
class _EmotionChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> weekData;
  final Map<String, Map<String, dynamic>> emojiMap;

  _EmotionChartPainter({required this.weekData, required this.emojiMap});

  static const Color _gridColor = Color(0xFFE0E0E0);
  static const Color _textColor = Color(0xFF2D2D2D);
  static const Color _greyTextColor = Color(0xFF8C8C8C);
  static const Color _curveColor = Color(0xFFA8D8B9);
  static const double _leftPadding = 70.0;
  static const double _rightPadding = 12.0;
  static const double _topPadding = 12.0;
  static const double _bottomPadding = 50.0;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final chartWidth = width - _leftPadding - _rightPadding;
    final chartHeight = height - _topPadding - _bottomPadding;

    final gridPaint = Paint()
      ..color = _gridColor
      ..strokeWidth = 1;

    // 绘制网格
    for (int i = 0; i < 6; i++) {
      final y = _topPadding + i * (chartHeight / 5);
      canvas.drawLine(
        Offset(_leftPadding, y),
        Offset(width - _rightPadding, y),
        gridPaint,
      );
    }
    for (int i = 0; i < 8; i++) {
      final x = _leftPadding + i * (chartWidth / 7);
      canvas.drawLine(
        Offset(x, _topPadding),
        Offset(x, height - _bottomPadding),
        gridPaint,
      );
    }

    // 竖轴标签
    const labelStyle = TextStyle(fontSize: 11, color: _textColor);
    const emotions = ['😤', '😭', '😴', '🥰', '😌'];
    for (int i = 0; i < emotions.length; i++) {
      final emotion = emotions[i];
      final y = _topPadding + i * (chartHeight / 5) + (chartHeight / 10);

      final labelPainter = TextPainter(
        text: TextSpan(text: emojiMap[emotion]?['label'], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(4, y - labelPainter.height / 2));

      final emojiPainter = TextPainter(
        text: TextSpan(text: emotion, style: const TextStyle(fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout();
      emojiPainter.paint(
        canvas,
        Offset(4 + labelPainter.width + 6, y - emojiPainter.height / 2),
      );
    }

    // 横轴标签
    for (int i = 0; i < weekData.length; i++) {
      final dayData = weekData[i];
      final x = _leftPadding + i * (chartWidth / 7) + (chartWidth / 14);

      final datePainter = TextPainter(
        text: TextSpan(
          text: dayData['displayDate'],
          style: const TextStyle(fontSize: 10, color: _textColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      datePainter.paint(
        canvas,
        Offset(x - datePainter.width / 2, height - _bottomPadding + 5),
      );

      final dayPainter = TextPainter(
        text: TextSpan(
          text: dayData['dayOfWeek'],
          style: const TextStyle(fontSize: 9, color: _greyTextColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      dayPainter.paint(
        canvas,
        Offset(x - dayPainter.width / 2, height - _bottomPadding + 18),
      );
    }

    // 绘制曲线
    if (weekData.isNotEmpty) {
      final curvePaint = Paint()
        ..color = _curveColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      int emotionToY(String emotion) {
        if (emotion == '😤') return 0;
        if (emotion == '😭') return 1;
        if (emotion == '😴') return 2;
        if (emotion == '🥰') return 3;
        if (emotion == '😌') return 4;
        return 4;
      }

      Offset? lastPoint;
      for (int i = 0; i < weekData.length; i++) {
        final dayData = weekData[i];
        final topEmotion = dayData['topEmotion'] as String;
        final x = _leftPadding + i * (chartWidth / 7) + (chartWidth / 14);

        if (topEmotion.isNotEmpty) {
          final yIndex = emotionToY(topEmotion);
          final y = _topPadding + yIndex * (chartHeight / 5) + (chartHeight / 10);
          final currentPoint = Offset(x, y);

          if (lastPoint != null) {
            canvas.drawLine(lastPoint, currentPoint, curvePaint);
          }
          canvas.drawCircle(currentPoint, 5, Paint()..color = _curveColor);

          final emojiPainter = TextPainter(
            text: TextSpan(text: topEmotion, style: const TextStyle(fontSize: 18)),
            textDirection: TextDirection.ltr,
          )..layout();
          emojiPainter.paint(canvas, Offset(x - emojiPainter.width / 2, y - 24));

          lastPoint = currentPoint;
        } else {
          lastPoint = null;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}