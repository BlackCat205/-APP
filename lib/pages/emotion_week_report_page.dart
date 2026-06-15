import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../services/usage_record_service.dart';
import 'AIScentAssistantPage.dart';
import 'emotion_week_chart_page.dart';
import 'diary_edit_page.dart';

/// 情绪周报内容组件（由 CareHistoryPage 内嵌使用，非独立页面）
class EmotionWeekReportPage extends StatefulWidget {
  const EmotionWeekReportPage({super.key});

  @override
  State<EmotionWeekReportPage> createState() => _EmotionWeekReportPageState();
}

class _EmotionWeekReportPageState extends State<EmotionWeekReportPage>
    with WidgetsBindingObserver {
  String _selectedPeriod = '本周';
  List<Map<String, dynamic>> _weekData = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;
  String _topScent = '无';
  bool _hasBuilt = false;

  static const Color _textColor = Color(0xFF2D2D2D);
  static const Color _greyTextColor = Color(0xFF8C8C8C);
  static const Color _accentGreen = Color(0xFFA8D8B9);
  static const Color _lightBg = Color(0xFFF5F0EB);
  static const double _defaultRadius = 8.0;
  static const double _cardRadius = 12.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWeekData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadWeekData();
  }

  Future<void> _loadWeekData() async {
    setState(() => _isLoading = true);
    try {
      final db = await AppDatabase().database;
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final startTimestamp = DateTime(weekStart.year, weekStart.month, weekStart.day).millisecondsSinceEpoch;
      final endTimestamp = now.millisecondsSinceEpoch;

      final records = await db.query(
        'smell_moment_record',
        where: 'created_at >= ? AND created_at < ?',
        whereArgs: [startTimestamp, endTimestamp],
        orderBy: 'created_at DESC',
      );

      final weeklyScentStats = await UsageRecordService.getWeeklyScentStats();
      final topScent = (weeklyScentStats.isNotEmpty)
          ? weeklyScentStats.first['scent_name'] as String
          : '无';

      final recordsByDate = _groupRecordsByDate(records);
      final weekData = _buildWeekData(recordsByDate);
      final totalCount = await CardTriggerRecordService.getWeekRecordCount();
      final (topScene, mostCommonEmotion, conclusion) = _computeSummary(weekData, totalCount);

      setState(() {
        _weekData = weekData;
        _summary = {
          'totalCount': totalCount,
          'topScene': topScene,
          'mostCommonEmotion': mostCommonEmotion,
          'conclusion': conclusion,
        };
        _topScent = topScent;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载周报数据失败: $e');
      setState(() => _isLoading = false);
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupRecordsByDate(List<Map<String, dynamic>> records) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final r in records) {
      final ts = r['created_at'] as int;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  List<Map<String, dynamic>> _buildWeekData(Map<String, List<Map<String, dynamic>>> recordsByDate) {
    const dayLabels = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    final sortedDates = recordsByDate.keys.toList()..sort((a, b) => b.compareTo(a));
    final list = <Map<String, dynamic>>[];

    for (final dateStr in sortedDates) {
      final dayRecords = recordsByDate[dateStr]!;
      final date = DateTime.parse(dateStr);
      final displayDate = '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
      final dayOfWeek = dayLabels[date.weekday % 7];

      final sceneCount = <String, int>{};
      final emotionCount = <String, int>{};
      for (final r in dayRecords) {
        _safeIncrement(sceneCount, r['scene_tag'] as String?);
        _safeIncrement(emotionCount, r['emotion_emoji'] as String?);
      }

      list.add({
        'date': displayDate,
        'dayOfWeek': dayOfWeek,
        'count': dayRecords.length,
        'topScene': _mostFrequent(sceneCount, defaultVal: '无'),
        'emotion': _mostFrequent(emotionCount, defaultVal: '😌'),
        'diary': (dayRecords.isNotEmpty) ? dayRecords.first['note'] as String? : null,
        'memories': dayRecords,
      });
    }
    return list;
  }

  void _safeIncrement(Map<String, int> map, String? key) {
    if (key != null && key.isNotEmpty) map[key] = (map[key] ?? 0) + 1;
  }

  String _mostFrequent(Map<String, int> map, {String defaultVal = ''}) {
    if (map.isEmpty) return defaultVal;
    return map.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  (String, String, String) _computeSummary(List<Map<String, dynamic>> weekData, int totalCount) {
    final allSceneCount = <String, int>{};
    final allEmotionCount = <String, int>{};
    int negativeCount = 0;
    const negativeEmojis = ['😤', '😭', '😡', '😔', '😖'];

    for (final day in weekData) {
      final dayMemories = day['memories'] as List<Map<String, dynamic>>;
      for (final memory in dayMemories) {
        final scene = memory['scene_tag'] as String?;
        if (scene != null && scene.isNotEmpty) allSceneCount[scene] = (allSceneCount[scene] ?? 0) + 1;
        final emoji = memory['emotion_emoji'] as String?;
        if (emoji != null && emoji.isNotEmpty) {
          allEmotionCount[emoji] = (allEmotionCount[emoji] ?? 0) + 1;
          if (negativeEmojis.contains(emoji)) negativeCount++;
        }
      }
    }

    final topScene = _mostFrequent(allSceneCount, defaultVal: '无');
    final mostCommonEmotion = _mostFrequent(allEmotionCount, defaultVal: '😌');
    final conclusion = _buildConclusion(totalCount, allSceneCount, negativeCount);
    return (topScene, mostCommonEmotion, conclusion);
  }

  String _buildConclusion(int totalCount, Map<String, int> sceneCount, int negativeCount) {
    if (totalCount < 3) return '最近很少使用，别忘了给自己一点疗愈时间';
    if ((sceneCount['下班回家'] ?? 0) >= 3) return '本周工作较忙，下班后多给自己一些放松时间';
    if ((sceneCount['睡前'] ?? 0) >= 3) return '本周睡眠质量一般，试试延长疗愈时长';
    if (totalCount > 0 && negativeCount / totalCount >= 0.5) return '本周情绪偏低落，多给自己一点时间';
    return '本周情绪稳定，继续保持';
  }

  void _togglePeriod() {
    setState(() {
      _selectedPeriod = _selectedPeriod == '本周' ? '上周' : '本周';
    });
    _loadWeekData();
  }

  void _writeDiary(int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DiaryEditPage()),
    );
    if (result == true) _loadWeekData();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasBuilt) {
      _hasBuilt = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadWeekData();
      });
    }

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodHeader(),
          const SizedBox(height: 24),
          _buildSummaryCard(),
          const SizedBox(height: 24),
          const Text(
            '每日详情',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textColor),
          ),
          const SizedBox(height: 16),
          ..._weekData.map((day) => _buildDayCard(day)),
          const SizedBox(height: 32),
          _buildAIChatButton(),
        ],
      ),
    );
  }

  Widget _buildPeriodHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(_selectedPeriod,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _textColor)),
        ElevatedButton(
          onPressed: _togglePeriod,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_defaultRadius)),
          ),
          child: Text(
            _selectedPeriod == '本周' ? '查看上周' : '查看本周',
            style: const TextStyle(color: _textColor),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmotionWeekChartPage())),
      child: Container(
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
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('本周汇总',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textColor)),
                Icon(Icons.arrow_forward_ios, size: 16, color: _accentGreen),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('本周最常见心情', '${_summary['mostCommonEmotion'] ?? '😌'}'),
                _summaryItem('最常用气味', _topScent),
                _summaryItem('本周使用次数', '${_summary['totalCount'] ?? 0} 次'),
              ],
            ),
            const SizedBox(height: 12),
            _conclusionItem('系统结论', '${_summary['conclusion'] ?? '无'}'),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _greyTextColor)),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textColor)),
      ],
    );
  }

  Widget _conclusionItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _greyTextColor)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: Text(value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textColor),
              textAlign: TextAlign.center,
              softWrap: true),
        ),
      ],
    );
  }

  Widget _buildDayCard(Map<String, dynamic> dayData) {
    final count = dayData['count'] as int;
    final topScene = dayData['topScene'] as String;
    final emotion = dayData['emotion'] as String;
    final diary = dayData['diary'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${dayData['date']} ${dayData['dayOfWeek']}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textColor)),
              Text(count > 0 ? '使用 $count 次' : '无记录',
                  style: TextStyle(
                      fontSize: 12,
                      color: count > 0 ? _greyTextColor : const Color(0xFFCCCCCC))),
            ],
          ),
          if (count > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (topScene != '无')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8D5B7),
                      borderRadius: BorderRadius.circular(_defaultRadius),
                    ),
                    child: Text(topScene, style: const TextStyle(fontSize: 12, color: _textColor)),
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
                color: _lightBg,
                borderRadius: BorderRadius.circular(_defaultRadius),
              ),
              child: Text(diary, style: const TextStyle(fontSize: 14, color: _textColor)),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.bottomRight,
            child: TextButton(
              onPressed: () => _writeDiary(0),
              child: const Text('✏️ 写今日心情', style: TextStyle(color: _accentGreen)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIChatButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AIScentAssistantPage()),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_defaultRadius)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        icon: const Text('💬'),
        label: const Text('和我聊一聊 · AI情绪陪伴', style: TextStyle(color: _textColor)),
      ),
    );
  }
}