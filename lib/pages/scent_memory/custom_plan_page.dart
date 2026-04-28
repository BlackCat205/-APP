import 'package:flutter/material.dart';
import '../../database/dao/custom_scent_plan_dao.dart';
import '../../database/models/custom_scent_plan.dart';

/// 自定义香氛方案页面
class CustomPlanPage extends StatefulWidget {
  const CustomPlanPage({super.key});

  @override
  State<CustomPlanPage> createState() => _CustomPlanPageState();
}

class _CustomPlanPageState extends State<CustomPlanPage> {
  final CustomScentPlanDAO _dao = CustomScentPlanDAO();
  List<CustomScentPlan> _plans = [];
  bool _isLoading = true;

  final List<String> _scents = ['无', '薰衣草', '甜橙', '玫瑰', '柠檬', '茉莉', '薄荷', '檀香'];
  final List<int> _speeds = [0, 1, 2]; // 0低 1中 2高
  final List<int> _timers = [0, 30, 60, 90];
  final List<String> _scenes = ['疲惫舒缓', '愉悦治愈', '助眠安神', '提神醒脑', '工作', '学习', '运动', '休闲'];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  /// 加载自定义香氛方案
  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final plans = await _dao.getAllCustomScentPlans();
      setState(() {
        _plans = plans;
      });
    } catch (e) {
      print('加载自定义香氛方案失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 添加或编辑自定义香氛方案
  void _addOrEditPlan([CustomScentPlan? plan]) async {
    final TextEditingController planNameController = TextEditingController(
      text: plan?.planName,
    );

    String? selectedScene = plan?.scene;
    String? selectedFan1Scent = plan?.fan1Scent ?? '无';
    int? selectedFan1Speed = plan?.fan1Speed ?? 0;
    String? selectedFan2Scent = plan?.fan2Scent ?? '无';
    int? selectedFan2Speed = plan?.fan2Speed ?? 0;
    String? selectedFan3Scent = plan?.fan3Scent ?? '无';
    int? selectedFan3Speed = plan?.fan3Speed ?? 0;
    String? selectedFan4Scent = plan?.fan4Scent ?? '无';
    int? selectedFan4Speed = plan?.fan4Speed ?? 0;
    int? selectedTimer = plan?.timerMinutes ?? 30;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(plan == null ? '添加自定义香氛方案' : '编辑自定义香氛方案'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                // 方案名称
                TextField(
                  controller: planNameController,
                  decoration: const InputDecoration(labelText: '方案名称'),
                ),
                const SizedBox(height: 16),
                // 场景
                DropdownButtonFormField<String>(
                  value: selectedScene,
                  hint: const Text('选择场景'),
                  items: _scenes.map((scene) {
                    return DropdownMenuItem<String>(
                      value: scene,
                      child: Text(scene),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedScene = value;
                  },
                  decoration: const InputDecoration(labelText: '场景'),
                ),
                const SizedBox(height: 16),
                // 风扇1
                const Text('风扇1', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  value: selectedFan1Scent,
                  hint: const Text('选择香气'),
                  items: _scents.map((scent) {
                    return DropdownMenuItem<String>(
                      value: scent,
                      child: Text(scent),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedFan1Scent = value;
                  },
                  decoration: const InputDecoration(labelText: '香气'),
                ),
                DropdownButtonFormField<int>(
                  value: selectedFan1Speed,
                  hint: const Text('选择风速'),
                  items: _speeds.map((speed) {
                    return DropdownMenuItem<int>(
                      value: speed,
                      child: Text(speed == 0 ? '低' : speed == 1 ? '中' : '高'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedFan1Speed = value;
                  },
                  decoration: const InputDecoration(labelText: '风速'),
                ),
                const SizedBox(height: 16),
                // 风扇2
                const Text('风扇2', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  value: selectedFan2Scent,
                  hint: const Text('选择香气'),
                  items: _scents.map((scent) {
                    return DropdownMenuItem<String>(
                      value: scent,
                      child: Text(scent),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedFan2Scent = value;
                  },
                  decoration: const InputDecoration(labelText: '香气'),
                ),
                DropdownButtonFormField<int>(
                  value: selectedFan2Speed,
                  hint: const Text('选择风速'),
                  items: _speeds.map((speed) {
                    return DropdownMenuItem<int>(
                      value: speed,
                      child: Text(speed == 0 ? '低' : speed == 1 ? '中' : '高'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedFan2Speed = value;
                  },
                  decoration: const InputDecoration(labelText: '风速'),
                ),
                const SizedBox(height: 16),
                // 风扇3
                const Text('风扇3', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  value: selectedFan3Scent,
                  hint: const Text('选择香气'),
                  items: _scents.map((scent) {
                    return DropdownMenuItem<String>(
                      value: scent,
                      child: Text(scent),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedFan3Scent = value;
                  },
                  decoration: const InputDecoration(labelText: '香气'),
                ),
                DropdownButtonFormField<int>(
                  value: selectedFan3Speed,
                  hint: const Text('选择风速'),
                  items: _speeds.map((speed) {
                    return DropdownMenuItem<int>(
                      value: speed,
                      child: Text(speed == 0 ? '低' : speed == 1 ? '中' : '高'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedFan3Speed = value;
                  },
                  decoration: const InputDecoration(labelText: '风速'),
                ),
                const SizedBox(height: 16),
                // 风扇4
                const Text('风扇4', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  value: selectedFan4Scent,
                  hint: const Text('选择香气'),
                  items: _scents.map((scent) {
                    return DropdownMenuItem<String>(
                      value: scent,
                      child: Text(scent),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedFan4Scent = value;
                  },
                  decoration: const InputDecoration(labelText: '香气'),
                ),
                DropdownButtonFormField<int>(
                  value: selectedFan4Speed,
                  hint: const Text('选择风速'),
                  items: _speeds.map((speed) {
                    return DropdownMenuItem<int>(
                      value: speed,
                      child: Text(speed == 0 ? '低' : speed == 1 ? '中' : '高'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedFan4Speed = value;
                  },
                  decoration: const InputDecoration(labelText: '风速'),
                ),
                const SizedBox(height: 16),
                // 定时
                DropdownButtonFormField<int>(
                  value: selectedTimer,
                  hint: const Text('选择定时'),
                  items: _timers.map((timer) {
                    return DropdownMenuItem<int>(
                      value: timer,
                      child: Text('${timer}分钟'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedTimer = value;
                  },
                  decoration: const InputDecoration(labelText: '定时'),
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
                if (planNameController.text.isNotEmpty && selectedScene != null) {
                  if (plan == null) {
                    // 添加
                    final newPlan = CustomScentPlan(
                      planName: planNameController.text,
                      scene: selectedScene!,
                      fan1Scent: selectedFan1Scent!,
                      fan1Speed: selectedFan1Speed!,
                      fan2Scent: selectedFan2Scent!,
                      fan2Speed: selectedFan2Speed!,
                      fan3Scent: selectedFan3Scent!,
                      fan3Speed: selectedFan3Speed!,
                      fan4Scent: selectedFan4Scent!,
                      fan4Speed: selectedFan4Speed!,
                      timerMinutes: selectedTimer!,
                      createdAt: DateTime.now().millisecondsSinceEpoch,
                    );
                    await _dao.insert(newPlan);
                  } else {
                    // 编辑
                    plan.planName = planNameController.text;
                    plan.scene = selectedScene!;
                    plan.fan1Scent = selectedFan1Scent!;
                    plan.fan1Speed = selectedFan1Speed!;
                    plan.fan2Scent = selectedFan2Scent!;
                    plan.fan2Speed = selectedFan2Speed!;
                    plan.fan3Scent = selectedFan3Scent!;
                    plan.fan3Speed = selectedFan3Speed!;
                    plan.fan4Scent = selectedFan4Scent!;
                    plan.fan4Speed = selectedFan4Speed!;
                    plan.timerMinutes = selectedTimer!;
                    await _dao.update(plan);
                  }
                  _loadPlans();
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

  /// 启用自定义香氛方案
  void _enablePlan(CustomScentPlan plan) {
    // 这里实现发送蓝牙指令的逻辑
    // 组合成 5 字节蓝牙指令（AA 55 00 cmd FB）
    // 实际项目中需要调用蓝牙发送方法
    print('启用自定义香氛方案: ${plan.planName}');
    print('风扇1: ${plan.fan1Scent}, 风速: ${plan.fan1Speed}');
    print('风扇2: ${plan.fan2Scent}, 风速: ${plan.fan2Speed}');
    print('风扇3: ${plan.fan3Scent}, 风速: ${plan.fan3Speed}');
    print('风扇4: ${plan.fan4Scent}, 风速: ${plan.fan4Speed}');
    print('定时: ${plan.timerMinutes}分钟');
    
    // 显示启用成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已启用方案: ${plan.planName}')),
    );
  }

  /// 删除自定义香氛方案
  void _deletePlan(int id) async {
    await _dao.delete(id);
    _loadPlans();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // 添加按钮
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => _addOrEditPlan(),
                  child: const Text('添加自定义香氛方案'),
                ),
              ),
              // 方案列表
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _plans.length,
                  itemBuilder: (context, index) {
                    final plan = _plans[index];
                    return _buildPlanCard(plan);
                  },
                ),
              ),
            ],
          );
  }

  /// 构建自定义香氛方案卡片
  Widget _buildPlanCard(CustomScentPlan plan) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 方案名称
            Text(
              plan.planName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // 场景
            Row(
              children: [
                const Text('场景: ', style: TextStyle(color: Colors.grey)),
                Text(plan.scene),
              ],
            ),
            const SizedBox(height: 8),
            // 风扇1
            Row(
              children: [
                const Text('风扇1: ', style: TextStyle(color: Colors.grey)),
                Text('${plan.fan1Scent}, 风速: ${plan.fan1Speed == 0 ? '低' : plan.fan1Speed == 1 ? '中' : '高'}'),
              ],
            ),
            const SizedBox(height: 8),
            // 风扇2
            Row(
              children: [
                const Text('风扇2: ', style: TextStyle(color: Colors.grey)),
                Text('${plan.fan2Scent}, 风速: ${plan.fan2Speed == 0 ? '低' : plan.fan2Speed == 1 ? '中' : '高'}'),
              ],
            ),
            const SizedBox(height: 8),
            // 风扇3
            Row(
              children: [
                const Text('风扇3: ', style: TextStyle(color: Colors.grey)),
                Text('${plan.fan3Scent}, 风速: ${plan.fan3Speed == 0 ? '低' : plan.fan3Speed == 1 ? '中' : '高'}'),
              ],
            ),
            const SizedBox(height: 8),
            // 风扇4
            Row(
              children: [
                const Text('风扇4: ', style: TextStyle(color: Colors.grey)),
                Text('${plan.fan4Scent}, 风速: ${plan.fan4Speed == 0 ? '低' : plan.fan4Speed == 1 ? '中' : '高'}'),
              ],
            ),
            const SizedBox(height: 8),
            // 定时
            Row(
              children: [
                const Text('定时: ', style: TextStyle(color: Colors.grey)),
                Text('${plan.timerMinutes}分钟'),
              ],
            ),
            const SizedBox(height: 16),
            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => _addOrEditPlan(plan),
                  child: const Text('编辑'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _enablePlan(plan),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('启用'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _deletePlan(plan.id!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
