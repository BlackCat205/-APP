import 'package:flutter/material.dart';
import '../../database/dao/user_scene_preference_dao.dart';
import '../../database/models/user_scene_preference.dart';

/// 场景偏好页面
class ScenePreferencePage extends StatefulWidget {
  const ScenePreferencePage({super.key});

  @override
  State<ScenePreferencePage> createState() => _ScenePreferencePageState();
}

class _ScenePreferencePageState extends State<ScenePreferencePage> {
  final UserScenePreferenceDAO _dao = UserScenePreferenceDAO();
  List<UserScenePreference> _preferences = [];
  bool _isLoading = true;

  final List<String> _scents = ['薰衣草', '甜橙', '玫瑰', '柠檬', '茉莉', '薄荷', '檀香'];
  final List<String> _speeds = ['低', '中', '高'];
  final List<int> _timers = [0, 30, 60, 90];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  /// 加载场景偏好
  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final preferences = await _dao.getAllScenePreferences();
      setState(() {
        _preferences = preferences;
      });
    } catch (e) {
      print('加载场景偏好失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 编辑场景偏好
  void _editPreference(UserScenePreference preference) async {
    final TextEditingController rejectedScentsController = TextEditingController(
      text: preference.rejectedScents,
    );

    String? selectedScent = preference.preferredScent;
    int? selectedSpeed = preference.defaultSpeed;
    int? selectedTimer = preference.defaultTimer;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('编辑${preference.sceneType}'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                // 首选香气
                DropdownButtonFormField<String>(
                  value: selectedScent,
                  hint: const Text('选择首选香气'),
                  items: _scents.map((scent) {
                    return DropdownMenuItem<String>(
                      value: scent,
                      child: Text(scent),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedScent = value;
                  },
                  decoration: const InputDecoration(labelText: '首选香气'),
                ),
                const SizedBox(height: 16),
                // 排斥香气
                TextField(
                  controller: rejectedScentsController,
                  decoration: const InputDecoration(
                    labelText: '排斥香气',
                    hintText: '用逗号分隔，如：玫瑰,茉莉',
                  ),
                ),
                const SizedBox(height: 16),
                // 默认风速
                DropdownButtonFormField<int>(
                  value: selectedSpeed,
                  hint: const Text('选择默认风速'),
                  items: _speeds.asMap().entries.map((entry) {
                    return DropdownMenuItem<int>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedSpeed = value;
                  },
                  decoration: const InputDecoration(labelText: '默认风速'),
                ),
                const SizedBox(height: 16),
                // 默认定时
                DropdownButtonFormField<int>(
                  value: selectedTimer,
                  hint: const Text('选择默认定时'),
                  items: _timers.map((timer) {
                    return DropdownMenuItem<int>(
                      value: timer,
                      child: Text('${timer}分钟'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedTimer = value;
                  },
                  decoration: const InputDecoration(labelText: '默认定时'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                if (selectedScent != null && selectedSpeed != null && selectedTimer != null) {
                  final updatedPreference = UserScenePreference(
                    id: preference.id,
                    sceneType: preference.sceneType,
                    preferredScent: selectedScent!,
                    rejectedScents: rejectedScentsController.text,
                    defaultSpeed: selectedSpeed!,
                    defaultTimer: selectedTimer!,
                    updatedAt: DateTime.now().millisecondsSinceEpoch,
                  );
                  await _dao.insertOrUpdate(updatedPreference);
                  _loadPreferences();
                  Navigator.pop(context);
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _preferences.length,
            itemBuilder: (context, index) {
              final preference = _preferences[index];
              return _buildPreferenceCard(preference);
            },
          );
  }

  /// 构建场景偏好卡片
  Widget _buildPreferenceCard(UserScenePreference preference) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 场景类型
            Text(
              preference.sceneType,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // 首选香气
            Row(
              children: [
                const Text('首选香气: ', style: TextStyle(color: Colors.grey)),
                Text(preference.preferredScent),
              ],
            ),
            const SizedBox(height: 8),
            // 排斥香气
            Row(
              children: [
                const Text('排斥香气: ', style: TextStyle(color: Colors.grey)),
                Text(preference.rejectedScents.isEmpty ? '无' : preference.rejectedScents),
              ],
            ),
            const SizedBox(height: 8),
            // 默认风速
            Row(
              children: [
                const Text('默认风速: ', style: TextStyle(color: Colors.grey)),
                Text(_speeds[preference.defaultSpeed]),
              ],
            ),
            const SizedBox(height: 8),
            // 默认定时
            Row(
              children: [
                const Text('默认定时: ', style: TextStyle(color: Colors.grey)),
                Text('${preference.defaultTimer}分钟'),
              ],
            ),
            const SizedBox(height: 16),
            // 编辑按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => _editPreference(preference),
                  child: const Text('编辑'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
