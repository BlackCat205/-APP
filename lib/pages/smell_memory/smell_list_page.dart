import 'package:flutter/material.dart';
import '../../services/usage_record_service.dart';
import '../../services/smell_moment_repository.dart';

/// 气味记忆列表页（按日期分组展示）
class SmellListPage extends StatefulWidget {
  const SmellListPage({super.key});

  @override
  State<SmellListPage> createState() => _SmellListPageState();
}

class _SmellListPageState extends State<SmellListPage>
    with AutomaticKeepAliveClientMixin {
  Map<String, List<Map<String, dynamic>>> _groupedMemories = {};
  List<String> _sortedDates = [];
  bool _isLoading = true;

  // ========== 常量 ==========
  static const Color _bgColor = Color(0xFFF5F0EB);
  static const Color _textColor = Color(0xFF2D2D2D);
  static const Color _greyTextColor = Color(0xFF8C8C8C);
  static const Color _deleteColor = Color(0xFFE07A5F);
  static const double _cardRadius = 12.0;

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
    _loadMemories();
  }

  /// 从 SQLite 加载，与评分及删除使用同一数据源
  Future<void> _loadMemories() async {
    try {
      final rows = await SmellMomentRecordService.getAllRecords();
      final memories = rows.map((row) => <String, dynamic>{
        'id': row['id'],
        'title': row['title'],
        'emoji': row['emotion_emoji'],
        'note': row['note'],
        'scene': row['scene_tag'],
        'recipe': row['scent_combo'],
        'duration': SmellMomentRepository.formatDuration(row['duration_seconds'] as int?),
        'timestamp': DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int).toString(),
      }).toList();

      // 按日期分组
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final memory in memories) {
        final timestamp = memory['timestamp'] as String?;
        if (timestamp != null) {
          final date = timestamp.split(' ').first;
          grouped.putIfAbsent(date, () => []).add(memory);
        }
      }

      final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

      if (!mounted) return;
      setState(() {
        _groupedMemories = grouped;
        _sortedDates = sortedDates;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载记忆失败: $e');
      if (mounted) setState(() => _isLoading = false);
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
        const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
        return weekdays[date.weekday % 7];
      }
    } catch (e) {
      debugPrint('解析日期失败: $e');
    }
    return '';
  }

  /// 显示记忆详情弹窗
  void _showMemoryDetail(Map<String, dynamic> memory) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          memory['title'] ?? '未命名',
          style: const TextStyle(fontWeight: FontWeight.w600, color: _textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (memory['emoji'] != null && memory['emoji']!.isNotEmpty)
                Text(memory['emoji']!, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              _detailRow('📅 ', (memory['timestamp'] as String?)?.split(' ').first ?? ''),
              const SizedBox(height: 8),
              _detailRow('🏷 ', memory['scene'] ?? '未知'),
              const SizedBox(height: 8),
              _detailRow('⏱ ', memory['duration'] ?? '未知'),
              const SizedBox(height: 8),
              _detailRow('🧪 ', (memory['recipe'] as String?)?.replaceAll(',', '/') ?? '未知'),
              const SizedBox(height: 16),
              const Text(
                '笔记:',
                style: TextStyle(fontWeight: FontWeight.w600, color: _textColor),
              ),
              const SizedBox(height: 8),
              Text(
                (memory['note'] is String && (memory['note'] as String).isNotEmpty)
                    ? memory['note']!
                    : '(无笔记)',
                style: const TextStyle(color: _textColor),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () {
              _deleteMemory(memory);
              Navigator.pop(dialogContext);
            },
            child: const Text('删除', style: TextStyle(color: _deleteColor)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String icon, String text) {
    return Row(
      children: [
        Text(icon),
        Text(text),
      ],
    );
  }

  /// 删除记忆
  void _deleteMemory(Map<String, dynamic> memory) async {
    try {
      await SmellMomentRecordService.deleteRecord(memory['id'] as int);
      await _loadMemories();
    } catch (e) {
      debugPrint('删除记忆失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除失败，请重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 要求
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          '气味记忆',
          style: TextStyle(fontWeight: FontWeight.w600, color: _textColor),
        ),
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sortedDates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌿', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              '还没有气味瞬间，开始你的第一次气味之旅吧',
              style: const TextStyle(fontSize: 16, color: _greyTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _sortedDates.length,
      itemBuilder: (context, dateIndex) {
        final date = _sortedDates[dateIndex];
        final memories = _groupedMemories[date]!;
        return _buildDateGroup(date, memories);
      },
    );
  }

  Widget _buildDateGroup(String date, List<Map<String, dynamic>> memories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '📅 ${date.replaceAll('-', '.')} ${_getWeekday(date)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
        ),
        ...memories.map((memory) => _buildMemoryCard(memory)),
      ],
    );
  }

  Widget _buildMemoryCard(Map<String, dynamic> memory) {
    return GestureDetector(
      onTap: () => _showMemoryDetail(memory),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: Text(
                memory['emoji'] ?? '😌',
                style: const TextStyle(fontSize: 40),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory['title'] ?? '未命名',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${memory['scene'] ?? '未知'} · ${memory['duration'] ?? '未知'}',
                    style: const TextStyle(fontSize: 12, color: _greyTextColor),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: _bgColor),
                  const SizedBox(height: 8),
                  Text(
                    (memory['note'] is String && (memory['note'] as String).isNotEmpty)
                        ? memory['note']!
                        : '(无笔记)',
                    style: const TextStyle(fontSize: 14, color: _textColor),
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
  }
}