import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';
import '../services/care_service.dart';
import '../services/fan_scent_service.dart';
import '../services/usage_record_service.dart';
import 'smell_memory/smell_save_popup.dart';
import 'fan_timer_page.dart';
import 'fan_scent_config_page.dart';
import '../models/usage_record.dart';

class HomeControlPage extends StatefulWidget {
  const HomeControlPage({super.key});

  @override
  _HomeControlPageState createState() => _HomeControlPageState();
}

class _HomeControlPageState extends State<HomeControlPage> {
  bool _isBluetoothConnected = false;
  String _connectionStatus = '未连接';

  // 风扇开关状态（本地 UI 状态，乐观更新）
  List<bool> _fanStates = [false, false, false, false];

  // 打开定时页面
  void _openTimerPage(int fanIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FanTimerPage(fanIndex: fanIndex)),
    );
  }

  // 构建风扇开关项（带定时按钮）
  Widget _buildFanTile(int index) {
    final isOn = _fanStates[index];
    return Column(
      children: [
        SwitchListTile(
          title: Text(
            '风扇 ${index + 1}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          secondary: const Icon(Icons.toys, color: Colors.blue),
          value: isOn,
          onChanged: (value) => _toggleFan(index, value),
          activeColor: Colors.green,
          inactiveThumbColor: Colors.grey,
        ),
        // 当风扇开启时显示定时关闭按钮
        if (isOn)
          Padding(
            padding: const EdgeInsets.only(left: 72, right: 16, bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openTimerPage(index),
                icon: const Icon(Icons.timer, size: 18),
                label: const Text('定时关闭'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFA8D8B9),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFFA8D8B9)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  // 权限请求（桌面端直接跳过）
  Future<void> _requestPermissions() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      debugPrint('桌面端跳过蓝牙权限请求');
      return;
    }
    if (await Permission.bluetoothScan.request().isGranted &&
        await Permission.bluetoothConnect.request().isGranted &&
        await Permission.location.request().isGranted) {
      debugPrint('蓝牙权限已授予');
    } else {
      debugPrint('蓝牙权限被拒绝');
    }
  }

  // 扫描并连接设备
  Future<void> _connectBluetooth() async {
    await fb.FlutterBluePlus.startScan(timeout: const Duration(seconds: 3));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('正在扫描设备，请稍后...')));

    await Future.delayed(const Duration(seconds: 4));
    await fb.FlutterBluePlus.stopScan();

    List<fb.ScanResult> results = await fb.FlutterBluePlus.scanResults.first;
    if (results.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未发现任何蓝牙设备')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择设备'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: results.length,
            itemBuilder: (ctx, index) {
              final device = results[index].device;
              final deviceName = device.name.isNotEmpty ? device.name : '未知设备';
              return ListTile(
                title: Text(deviceName),
                subtitle: Text(device.id.toString()),
                onTap: () async {
                  Navigator.pop(context);
                  bool success = await BluetoothService.connectToDeviceByDevice(
                    device,
                  );
                  setState(() {
                    _isBluetoothConnected = success;
                    _connectionStatus = success ? '已连接' : '连接失败';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? '连接成功' : '连接失败')),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  // 发送指令的通用包装（检查连接）
  Future<void> _sendCommand(
    Future<void> Function() command,
    String successMsg,
  ) async {
    if (!_isBluetoothConnected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先连接蓝牙设备')));
      return;
    }
    try {
      await command();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          duration: const Duration(milliseconds: 800),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发送失败: $e')));
    }
  }

  // 切换风扇开关
  void _toggleFan(int index, bool value) async {
    if (value) {
      // 开启风扇
      switch (index) {
        case 0:
          await _sendCommand(BluetoothService.fan1On, '风扇1 已开启');
          break;
        case 1:
          await _sendCommand(BluetoothService.fan2On, '风扇2 已开启');
          break;
        case 2:
          await _sendCommand(BluetoothService.fan3On, '风扇3 已开启');
          break;
        case 3:
          await _sendCommand(BluetoothService.fan4On, '风扇4 已开启');
          break;
      }
      // 自动开始使用记录
      await _startUsageRecord();
    } else {
      // 关闭风扇
      switch (index) {
        case 0:
          await _sendCommand(BluetoothService.fan1Off, '风扇1 已关闭');
          break;
        case 1:
          await _sendCommand(BluetoothService.fan2Off, '风扇2 已关闭');
          break;
        case 2:
          await _sendCommand(BluetoothService.fan3Off, '风扇3 已关闭');
          break;
        case 3:
          await _sendCommand(BluetoothService.fan4Off, '风扇4 已关闭');
          break;
      }
      // 自动结束使用记录
      await _endUsageRecord();
    }
    // 更新本地状态（乐观更新）
    setState(() {
      _fanStates[index] = value;
    });
  }

  // 开始自动记录
  Future<void> _startUsageRecord() async {
    // 获取当前开启的风扇
    final activeFans = <int>[];
    for (int i = 0; i < 4; i++) {
      if (_fanStates[i]) {
        activeFans.add(i + 1);
      }
    }
    // 如果有风扇开启，开始记录
    if (activeFans.isNotEmpty) {
      await UsageRecordService.startRecord(activeFans);
    }
  }

  // 结束自动记录
  Future<void> _endUsageRecord() async {
    // 检查是否还有风扇开启
    final hasActiveFan = _fanStates.any((state) => state);
    // 如果没有风扇开启且有进行中的记录，结束记录
    if (!hasActiveFan && UsageRecordService.hasActiveRecord()) {
      final record = await UsageRecordService.endRecord();
      // 如果使用时间大于1分钟，触发气味瞬间收集弹窗
      if (record != null && record.duration != null && record.duration! > 60) {
        _showSmellSavePopup(record);
      }
    }
  }

  /// 显示气味瞬间保存弹窗
  void _showSmellSavePopup(UsageRecord record) {
    // 解析气味组合
    final scents = record.scentCombo?.split('+') ?? [];
    
    // 格式化时长显示
    int seconds = record.duration ?? 0;
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;
    String durationStr;
    if (hours > 0) {
      durationStr = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      durationStr = '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SmellSavePopup(
          recipeList: scents,
          duration: durationStr,
          recordId: record.id,
        );
      },
    );
  }

  // 测试触发按钮
  void _testTrigger() {
    // 自动记录气味使用行为
    CareService.recordUsage(
      scene: '疲惫舒缓',
      emotion: '😌',
      duration: 332, // 5分32秒
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SmellSavePopup(
          recipeList: ['薰衣草', '檀香', '雪松'],
          duration: '00:05:32',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('情绪香薰控制中心')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 蓝牙连接状态栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isBluetoothConnected
                    ? Colors.green[50]
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isBluetoothConnected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        color: _isBluetoothConnected
                            ? Colors.green
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text('蓝牙状态: $_connectionStatus'),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _connectBluetooth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('连接设备'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '风扇控制',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // 四个风扇开关（使用 SwitchListTile）
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildFanTile(0),
                  const Divider(height: 1),
                  _buildFanTile(1),
                  const Divider(height: 1),
                  _buildFanTile(2),
                  const Divider(height: 1),
                  _buildFanTile(3),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _sendCommand(BluetoothService.allOff, '所有风扇已关闭'),
                    icon: const Icon(Icons.stop_circle),
                    label: const Text('关闭所有风扇'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _sendCommand(BluetoothService.emergencyStop, '紧急停止'),
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('紧急停止'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 测试触发按钮
            ElevatedButton.icon(
              onPressed: _testTrigger,
              icon: const Icon(Icons.play_arrow),
              label: const Text('测试触发'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
      // 右下角气味配置入口（叶子图标）
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FanScentConfigPage()),
          );
        },
        backgroundColor: const Color(0xFFA8D8B9),
        child: const Icon(Icons.eco, color: Colors.white),
      ),
    );
  }
}
