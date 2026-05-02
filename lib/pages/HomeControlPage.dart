import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';
import '../services/care_service.dart';
import '../services/fan_scent_service.dart';
import '../services/usage_record_service.dart';
import '../database/database_helper.dart';
import '../database/app_database.dart';
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
  void _openTimerPage(int fanIndex) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FanTimerPage(fanIndex: fanIndex)),
    );
    // 如果返回值是数字，表示定时时间（毫秒），启动本地定时器同步状态
    if (result is int && result > 0) {
      Future.delayed(Duration(milliseconds: result), () {
        if (mounted) {
          setState(() {
            _fanStates[fanIndex] = false;
          });
        }
      });
    }
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
    final fanId = index + 1; // 风扇ID从1开始

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
      // 开始单个风扇的使用记录
      await UsageRecordService.startRecord(fanId);
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
      // 结束单个风扇的使用记录
      await UsageRecordService.endRecord(fanId);
    }
    // 更新本地状态（乐观更新）
    setState(() {
      _fanStates[index] = value;
    });

    // 检查是否所有风扇都已关闭
    await _checkAllFansOff();
  }

  /// 检查所有风扇是否已关闭
  Future<void> _checkAllFansOff() async {
    // 检查是否还有风扇开启
    final hasActiveFan = _fanStates.any((state) => state);

    // 如果所有风扇都已关闭
    if (!hasActiveFan) {
      // 获取上次气味瞬间记录的时间戳（用于判定"本次使用"的起始时间）
      final lastMomentTimestamp =
          await SmellMomentRecordService.getLastMomentRecordTimestamp();

      // 获取今日所有使用记录
      final allTodayRecords = await UsageRecordService.getTodayRecords();

      // 筛选"本次使用"记录：createdAt > 上次弹窗时间戳 且 时长 > 60秒
      final validRecords = allTodayRecords
          .where(
            (r) =>
                r.createdAt != null &&
                r.createdAt! > lastMomentTimestamp &&
                r.duration != null &&
                r.duration! > 60,
          )
          .toList();

      print(
        '🧪 本次使用判定：上次弹窗时间=$lastMomentTimestamp, 找到${validRecords.length}条有效记录',
      );

      // 如果有有效的使用记录，触发弹窗
      if (validRecords.isNotEmpty) {
        _showSmellSavePopup(validRecords);
      }
    }
  }

  /// 显示气味瞬间保存弹窗
  void _showSmellSavePopup(List<UsageRecord> records) async {
    // 记录卡片弹出事件（不管用户是否保存，都记录一次）
    await CardTriggerRecordService.insertRecord();

    // 收集本次使用的风扇对应的气味（按风扇ID去重，避免重复显示）
    final scentMap = <int, String>{};
    for (final record in records) {
      if (record.scentName != null && record.scentName!.isNotEmpty) {
        scentMap.putIfAbsent(record.fanId, () => record.scentName!);
      }
    }
    final scents = scentMap.values.toList();

    // 计算总时长
    int totalSeconds = records.fold(0, (sum, r) => sum + (r.duration ?? 0));

    // 格式化时长显示
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int secs = totalSeconds % 60;
    String durationStr;
    if (hours > 0) {
      durationStr =
          '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      durationStr =
          '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }

    // 收集所有使用记录ID
    final recordIds = records
        .where((r) => r.id != null)
        .map((r) => r.id!)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SmellSavePopup(
          recipeList: scents,
          duration: durationStr,
          recordIds: recordIds,
        );
      },
    );
  }

  // 测试触发按钮 - 模拟真实使用流程
  Future<void> _testTrigger() async {
    // 1. 模拟开启风扇 1、3、4（使用时长超过 60 秒）
    final activeFans = [1, 3, 4];

    // 2. 获取当前气味配置（从数据库获取最新配置）
    final dbHelper = DatabaseHelper();
    final configs = await dbHelper.getAllFanConfigs();
    final scentMap = <int, String>{};
    for (var config in configs) {
      final fanId = config['fan_id'] as int;
      final scentName = config['scent_name'] as String?;
      if (scentName != null && scentName.isNotEmpty) {
        scentMap[fanId] = scentName;
      }
    }

    print('🧪 测试：当前气味配置');
    scentMap.forEach((fanId, scent) {
      print('  - 风扇$fanId: $scent');
    });

    // 3. 模拟开始记录（为每个风扇创建使用记录）
    for (final fanId in activeFans) {
      await UsageRecordService.startRecord(fanId);
    }

    // 4. 模拟使用一段时间（快速测试：等待 2 秒，然后手动修改记录时长为 65 秒）
    print('🧪 测试：开始模拟使用...');
    await Future.delayed(const Duration(seconds: 2));

    // 5. 模拟关闭所有风扇
    print('🧪 测试：关闭所有风扇');
    for (final fanId in activeFans) {
      await UsageRecordService.endRecord(fanId);
    }

    // 6. 手动修改记录时长为 65 秒（模拟真实使用超过 60 秒）
    print('🧪 测试：模拟使用时长超过 60 秒');
    final db = await AppDatabase().database;
    for (final fanId in activeFans) {
      // 获取最新的记录并更新时长
      final records = await db.query(
        'usage_records',
        where: 'fan_id = ? AND end_time IS NOT NULL',
        whereArgs: [fanId],
        orderBy: 'end_time DESC',
        limit: 1,
      );

      if (records.isNotEmpty) {
        final recordId = records.first['id'] as int;
        await db.update(
          'usage_records',
          {'duration': 65}, // 设置为 65 秒
          where: 'id = ?',
          whereArgs: [recordId],
        );
      }
    }

    // 7. 检查是否触发弹窗（只获取本次创建风扇的记录，筛选时长>60 秒的）
    final now = DateTime.now();
    final startOfDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final endOfDay = startOfDay + 24 * 60 * 60 * 1000;

    final validRecords = <UsageRecord>[];
    for (final fanId in activeFans) {
      final records = await db.query(
        'usage_records',
        where:
            'fan_id = ? AND start_time >= ? AND start_time < ? AND end_time IS NOT NULL AND duration > 60',
        whereArgs: [fanId, startOfDay, endOfDay],
        orderBy: 'start_time DESC',
        limit: 1,
      );
      if (records.isNotEmpty) {
        validRecords.add(UsageRecord.fromMap(records.first));
      }
    }

    print('🧪 测试：找到${validRecords.length}条有效记录');
    for (var record in validRecords) {
      print(
        '  - 风扇${record.fanId}: ${record.scentName}, 时长${record.duration}秒',
      );
    }

    // 8. 如果有有效记录，触发弹窗
    if (validRecords.isNotEmpty) {
      _showSmellSavePopup(validRecords);
    } else {
      // 没有有效记录，显示提示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('测试失败：没有符合条件的记录')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('情绪香薰控制中心')),
      body: SingleChildScrollView(
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
            const SizedBox(height: 24),
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
