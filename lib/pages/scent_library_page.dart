import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

/// 你的气味库页面 - 显示五个场景下评分最高的气味
class ScentLibraryPage extends StatefulWidget {
  const ScentLibraryPage({super.key});

  @override
  State<ScentLibraryPage> createState() => _ScentLibraryPageState();
}

class _ScentLibraryPageState extends State<ScentLibraryPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _scentData = [];

  // ========== 常量 ==========
  static const List<String> _scenes = [
    '下班回家',
    '工作学习',
    '睡前',
    '周末放松',
    '其他',
  ];

  static const double _cardRadius = 12.0;
  static const double _iconContainerSize = 48.0;
  static const double _iconSize = 24.0;
  static const double _defaultPadding = 16.0;

  static const Map<String, IconData> _sceneIcons = {
    '下班回家': Icons.home,
    '工作学习': Icons.work,
    '睡前': Icons.bed,
    '周末放松': Icons.beach_access,
    '其他': Icons.more_horiz,
  };

  static const Map<String, Color> _sceneColors = {
    '下班回家': Colors.blue,
    '工作学习': Colors.green,
    '睡前': Colors.purple,
    '周末放松': Colors.orange,
    '其他': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _loadScentData();
  }

  Future<void> _loadScentData() async {
    setState(() => _isLoading = true);
    try {
      final db = await AppDatabase().database;
      final List<Map<String, dynamic>> result = [];

      for (final scene in _scenes) {
        final records = await db.query(
          'smell_moment_record',
          where: 'scene_tag = ?',
          whereArgs: [scene],
          orderBy: 'score DESC',
          limit: 1,
        );

        if (records.isNotEmpty) {
          result.add({
            'scene': scene,
            'scent_combo': records.first['scent_combo'] ?? '未记录',
            'score': records.first['score'] ?? 0,
            'count': await _getSceneRecordCount(db, scene),
          });
        } else {
          result.add({
            'scene': scene,
            'scent_combo': '暂无记录',
            'score': 0,
            'count': 0,
          });
        }
      }

      setState(() {
        _scentData = result;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载气味库数据失败: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<int> _getSceneRecordCount(Database db, String scene) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM smell_moment_record WHERE scene_tag = ?',
      [scene],
    );
    return result.first['count'] as int? ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('你的气味库')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(_defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                '以下是你在不同场景下最常用的气味组合，根据你保存的气味瞬间卡片自动统计',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                childAspectRatio: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _scentData.length,
              itemBuilder: (_, index) => _buildSceneCard(_scentData[index]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSceneCard(Map<String, dynamic> data) {
    final scene = data['scene'] as String;
    final color = _sceneColors[scene] ?? Colors.black;
    final icon = _sceneIcons[scene] ?? Icons.spa;
    // 修复：将可空 int 转为非空再比较，确保条件表达式为 bool
    final int score = (data['score'] as int?) ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: _iconContainerSize,
              height: _iconContainerSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: color.withOpacity(0.1),
              ),
              child: Icon(icon, color: color, size: _iconSize),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scene,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['scent_combo'] ?? '暂无记录',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '评分 $score',
                  style: TextStyle(
                    color: score > 0 ? Colors.orange : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '使用 ${data['count']} 次',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}