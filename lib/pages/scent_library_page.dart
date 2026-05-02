import 'package:flutter/material.dart';
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

  // 五个场景定义
  final List<String> _scenes = ['下班回家', '工作学习', '睡前', '周末放松', '其他'];

  @override
  void initState() {
    super.initState();
    _loadScentData();
  }

  /// 加载每个场景下评分最高的气味数据
  Future<void> _loadScentData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = await AppDatabase().database;
      final List<Map<String, dynamic>> result = [];

      for (final scene in _scenes) {
        // 查询该场景下评分最高的气味记录
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
      print('加载气味库数据失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 获取某个场景的记录数量
  Future<int> _getSceneRecordCount(dynamic db, String scene) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM smell_moment_record WHERE scene_tag = ?',
      [scene],
    );
    return result.first['count'] as int? ?? 0;
  }

  /// 获取场景图标
  IconData _getSceneIcon(String scene) {
    switch (scene) {
      case '下班回家':
        return Icons.home;
      case '工作学习':
        return Icons.work;
      case '睡前':
        return Icons.bed;
      case '周末放松':
        return Icons.beach_access;
      case '其他':
        return Icons.more_horiz;
      default:
        return Icons.spa;
    }
  }

  /// 获取场景颜色
  Color _getSceneColor(String scene) {
    switch (scene) {
      case '下班回家':
        return Colors.blue;
      case '工作学习':
        return Colors.green;
      case '睡前':
        return Colors.purple;
      case '周末放松':
        return Colors.orange;
      case '其他':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('你的气味库')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 页面描述
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      '以下是你在不同场景下最常用的气味组合，根据你保存的气味瞬间卡片自动统计',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  // 场景卡片列表
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
                    itemBuilder: (context, index) {
                      final data = _scentData[index];
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // 场景图标
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  color: _getSceneColor(
                                    data['scene'],
                                  ).withOpacity(0.1),
                                ),
                                child: Icon(
                                  _getSceneIcon(data['scene']),
                                  color: _getSceneColor(data['scene']),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // 场景信息
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['scene'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data['scent_combo'],
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              // 评分和使用次数
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '评分 ${data['score']}',
                                    style: TextStyle(
                                      color: data['score'] > 0
                                          ? Colors.orange
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '使用 ${data['count']} 次',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
