import 'package:flutter/material.dart';
import '../database/dao/scent_diary_note_dao.dart';
import '../database/models/scent_diary_note.dart';
import 'emotion_week_report_page.dart';

/// 气味关怀页面，提供情绪周报与心情日记两个标签页。
class CareHistoryPage extends StatefulWidget {
  const CareHistoryPage({super.key});

  @override
  State<CareHistoryPage> createState() => _CareHistoryPageState();
}

class _CareHistoryPageState extends State<CareHistoryPage> {
  final ScentDiaryNoteDAO _diaryDAO = ScentDiaryNoteDAO();

  // 日记相关状态
  List<ScentDiaryNote> _diaryNotes = [];
  bool _isDiaryLoading = false;

  // 当前选中的标签页索引 (0: 周报, 1: 日记)
  int _currentIndex = 0;

  // 通过 Key 刷新周报组件（切换到该标签时重建）
  Key _weekReportKey = UniqueKey();

  // ========== 本地常量 ==========
  static const Color _textColor = Color(0xFF2D2D2D);
  static const Color _greyTextColor = Color(0xFF8C8C8C);
  static const Color _lightGreyTextColor = Color(0xFFBDBDBD);
  static const Color _tabActiveColor = Color(0xFFA8D8B9);
  static const Color _cardBackground = Colors.white;
  static const double _tabHeight = 12.0;
  static const double _tabBorderRadius = 8.0;
  static const double _cardBorderRadius = 12.0;
  static const double _padding = 16.0;
  static const double _margin = 24.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '气味关怀',
          style: TextStyle(fontWeight: FontWeight.w600, color: _textColor),
        ),
        backgroundColor: _cardBackground,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // 标签切换区域
          Container(
            margin: const EdgeInsets.all(_margin),
            decoration: const BoxDecoration(
              color: _cardBackground,
              borderRadius: BorderRadius.all(Radius.circular(_tabBorderRadius)),
            ),
            child: Row(
              children: [
                _buildTab('情绪周报', 0),
                _buildTab('心情日记', 1),
              ],
            ),
          ),
          // 内容区域
          Expanded(
            child: _currentIndex == 0
                ? EmotionWeekReportPage(key: _weekReportKey)
                : _buildDiaryRecords(),
          ),
        ],
      ),
    );
  }

  /// 构建单个标签项
  Widget _buildTab(String title, int index) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabChanged(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: _tabHeight),
          decoration: BoxDecoration(
            color: isActive ? _tabActiveColor : Colors.transparent,
            borderRadius: isActive
                ? BorderRadius.circular(_tabBorderRadius)
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: _textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 标签切换处理
  void _onTabChanged(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 0) {
        _weekReportKey = UniqueKey(); // 强制重建周报
      } else {
        _loadDiaryNotes(); // 加载日记数据
      }
    });
  }

  // ========== 心情日记相关 ==========

  /// 从数据库加载心情日记
  Future<void> _loadDiaryNotes() async {
    setState(() => _isDiaryLoading = true);
    try {
      final notes = await _diaryDAO.getAllScentDiaryNotes();
      setState(() => _diaryNotes = notes);
    } catch (e) {
      debugPrint('加载心情日记失败: $e');
    } finally {
      setState(() => _isDiaryLoading = false);
    }
  }

  /// 构建心情日记列表（空状态 / 加载中 / 数据列表）
  Widget _buildDiaryRecords() {
    if (_isDiaryLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_diaryNotes.isEmpty) {
      return _buildEmptyDiary();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(_margin),
      itemCount: _diaryNotes.length,
      itemBuilder: (context, index) => _buildDiaryCard(_diaryNotes[index]),
    );
  }

  /// 空日记占位提示
  Widget _buildEmptyDiary() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📝', style: TextStyle(fontSize: 48)),
          const SizedBox(height: _padding),
          Text('暂无心情日记', style: TextStyle(fontSize: 16, color: _greyTextColor)),
          const SizedBox(height: 8),
          Text(
            '点击「写今日心情」开始记录',
            style: TextStyle(fontSize: 12, color: _lightGreyTextColor),
          ),
        ],
      ),
    );
  }

  /// 单条日记卡片
  Widget _buildDiaryCard(ScentDiaryNote note) {
    final date = DateTime.fromMillisecondsSinceEpoch(note.createdAt);
    final dateStr = _formatDate(date);

    return Container(
      margin: const EdgeInsets.only(bottom: _padding),
      padding: const EdgeInsets.all(_padding),
      decoration: const BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.all(Radius.circular(_cardBorderRadius)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日期与心情标签
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dateStr, style: const TextStyle(fontSize: 12, color: _greyTextColor)),
              _buildTag(
                note.mood,
                backgroundColor: _tabActiveColor.withOpacity(0.2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 香氛与场景标签
          Row(
            children: [
              _buildTag(note.usedScent, backgroundColor: const Color(0xFFE8D5B7)),
              const SizedBox(width: 8),
              _buildTag(note.scene, backgroundColor: const Color(0xFFD5E8D4)),
            ],
          ),
          // 日记内容（若有）
          if (note.noteContent.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              note.noteContent,
              style: const TextStyle(
                fontSize: 14,
                color: _textColor,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 格式化日期为 yyyy.MM.dd 字符串
  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  /// 构建通用圆角标签
  Widget _buildTag(String text, {required Color backgroundColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: _textColor),
      ),
    );
  }
}