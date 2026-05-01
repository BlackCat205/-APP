import 'package:flutter/material.dart';
import '../services/care_service.dart';
import '../database/dao/scent_diary_note_dao.dart';
import '../database/models/scent_diary_note.dart';
import 'emotion_week_report_page.dart';

/// 气味关怀页面
class CareHistoryPage extends StatefulWidget {
  const CareHistoryPage({Key? key}) : super(key: key);

  @override
  State<CareHistoryPage> createState() => _CareHistoryPageState();
}

class _CareHistoryPageState extends State<CareHistoryPage> {
  final ScentDiaryNoteDAO _diaryDAO = ScentDiaryNoteDAO();
  List<ScentDiaryNote> _diaryNotes = [];
  bool _isDiaryLoading = false;
  int _currentIndex = 0; // 0: 情绪周报, 1: 心情日记
  Key _weekReportKey = UniqueKey(); // 用于刷新周报页面

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EB),
      appBar: AppBar(
        title: Text(
          '气味关怀',
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
      body: Column(
        children: [
          // 标签页
          Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [_buildTab('情绪周报', 0), _buildTab('心情日记', 1)]),
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

  /// 构建标签
  Widget _buildTab(String title, int index) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
            // 切换到周报标签时，刷新周报数据
            if (index == 0) {
              _weekReportKey = UniqueKey();
            }
            // 切换到日记标签时，加载日记数据
            if (index == 1) {
              _loadDiaryNotes();
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _currentIndex == index
                ? const Color(0xFFA8D8B9)
                : Colors.transparent,
            borderRadius: _currentIndex == index
                ? BorderRadius.circular(8)
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: _currentIndex == index
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: const Color(0xFF2D2D2D),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 加载心情日记数据
  Future<void> _loadDiaryNotes() async {
    setState(() {
      _isDiaryLoading = true;
    });
    try {
      final notes = await _diaryDAO.getAllScentDiaryNotes();
      setState(() {
        _diaryNotes = notes;
      });
    } catch (e) {
      print('加载心情日记失败: $e');
    } finally {
      setState(() {
        _isDiaryLoading = false;
      });
    }
  }

  /// 构建心情日记记录
  Widget _buildDiaryRecords() {
    if (_isDiaryLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_diaryNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📝', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              '暂无心情日记',
              style: TextStyle(
                fontSize: 16,
                color: const Color(0xFF8C8C8C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击「写今日心情」开始记录',
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFFBDBDBD),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _diaryNotes.length,
      itemBuilder: (context, index) {
        final note = _diaryNotes[index];
        final date = DateTime.fromMillisecondsSinceEpoch(note.createdAt);
        final dateStr = '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

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
              // 日期和心情标签
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF8C8C8C),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA8D8B9).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      note.mood,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 香氛和场景
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8D5B7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      note.usedScent,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD5E8D4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      note.scene,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 日记内容
              if (note.noteContent.isNotEmpty)
                Text(
                  note.noteContent,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2D2D2D),
                    height: 1.5,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
