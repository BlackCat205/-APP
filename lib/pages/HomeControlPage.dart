import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';
import '../services/fan_scent_service.dart';
import '../services/usage_record_service.dart';
import '../database/database_helper.dart';
import '../database/app_database.dart';
import '../models/usage_record.dart';
import 'smell_memory/smell_save_popup.dart';
import 'fan_timer_page.dart';
import 'fan_scent_config_page.dart';

/// 主页：蓝牙连接、风扇控制、测试入口
class HomeControlPage extends StatefulWidget {
  const HomeControlPage({super.key});

  @override
  State<HomeControlPage> createState() => _HomeControlPageState();
}

class _HomeControlPageState extends State<HomeControlPage> {
  bool _isBluetoothConnected = false;
  String _connectionStatus = '未连接';

  // 风扇开关本地 UI 状态（乐观更新）
  final List<bool> _fanStates = [false, false, false, false];

  // ========== 样式常量 ==========
  static const Color _accentGreen = Color(0xFFA8D8B9);
  static const Color _textColor = Color(0xFF2D2D2D);
  static const Color _connectionBgConnected = Color(0xFFE8F5E9);
  static const Color _connectionBgDisconnected = Color(0xFFEEEEEE);
  static const double _defaultRadius = 8.0;
  static const double _cardRadius = 12.0;
  static const double _verticalPadding = 16.0;

  // ========== 测试常量 ==========
  static const List<int> _testActiveFans = [1, 3, 4];
  static const int _testSimulatedDuration = 65; // 秒

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  // ---------- 权限 ----------
  Future<void> _requestPermissions() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      debugPrint('桌面端跳过蓝牙权限请求');
      return;
    }
    final scanGranted = await Permission.bluetoothScan.request().isGranted;
    final connectGranted = await Permission.bluetoothConnect.request().isGranted;
    final locationGranted = await Permission.location.request().isGranted;
    if (scanGranted && connectGranted && locationGranted) {
      debugPrint('蓝牙权限已授予');
    } else {
      debugPrint('蓝牙权限被拒绝');
    }
  }

  // ---------- 蓝牙连接 ----------
  Future<void> _connectBluetooth() async {
    await fb.FlutterBluePlus.startScan(timeout: const Duration(seconds: 3));
    _showSnackBar('正在扫描设备，请稍后...');
    await Future.delayed(const Duration(seconds: 4));
    await fb.FlutterBluePlus.stopScan();

    final results = await fb.FlutterBluePlus.scanResults.first;
    if (results.isEmpty) {
      _showSnackBar('未发现任何蓝牙设备');
      return;
    }
    _showDeviceSelectionDialog(results);
  }

  void _showDeviceSelectionDialog(List<fb.ScanResult> results) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('选择设备'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: results.length,
            itemBuilder: (_, index) {
              final device = results[index].device;
              final name = device.name.isNotEmpty ? device.name : '未知设备';
              return ListTile(
                title: Text(name),
                subtitle: Text(device.id.toString()),
                onTap: () => _onDeviceSelected(dialogContext, device),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<void> _onDeviceSelected(
      BuildContext dialogContext,
      fb.BluetoothDevice device,
      ) async {
    Navigator.pop(dialogContext);
    final success = await BluetoothService.connectToDeviceByDevice(device);
    setState(() {
      _isBluetoothConnected = success;
      _connectionStatus = success ? '已连接' : '连接失败';
    });
    _showSnackBar(success ? '连接成功' : '连接失败');
    if (success) await _checkAllFansOff();
  }

  // ---------- 风扇控制指令 ----------
  Future<void> _sendCommand(
      Future<void> Function() command,
      String successMsg,
      ) async {
    if (!_isBluetoothConnected) {
      _showSnackBar('请先连接蓝牙设备');
      return;
    }
    try {
      await command();
      _showSnackBar(successMsg);
    } catch (e) {
      _showSnackBar('发送失败: $e');
    }
  }

  void _toggleFan(int index, bool value) async {
    final fanId = index + 1;
    // 根据 on/off 分发指令和记录
    if (value) {
      await _sendCommand(_fanOnCommand(index), '风扇$fanId 已开启');
      if (_isBluetoothConnected) await UsageRecordService.startRecord(fanId);
    } else {
      await _sendCommand(_fanOffCommand(index), '风扇$fanId 已关闭');
      if (_isBluetoothConnected) await UsageRecordService.endRecord(fanId);
    }
    setState(() => _fanStates[index] = value);
    await _checkAllFansOff();
  }

  Future<void> Function() _fanOnCommand(int index) {
    switch (index) {
      case 0: return BluetoothService.fan1On;
      case 1: return BluetoothService.fan2On;
      case 2: return BluetoothService.fan3On;
      case 3: return BluetoothService.fan4On;
      default: return () async {};
    }
  }

  Future<void> Function() _fanOffCommand(int index) {
    switch (index) {
      case 0: return BluetoothService.fan1Off;
      case 1: return BluetoothService.fan2Off;
      case 2: return BluetoothService.fan3Off;
      case 3: return BluetoothService.fan4Off;
      default: return () async {};
    }
  }

  // ---------- 定时页面 ----------
  void _openTimerPage(int fanIndex) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FanTimerPage(fanIndex: fanIndex)),
    );
    if (result is int && result > 0) {
      Future.delayed(Duration(milliseconds: result), () {
        if (mounted) setState(() => _fanStates[fanIndex] = false);
      });
    }
  }

  // ---------- 气味保存弹窗 ----------
  Future<void> _checkAllFansOff() async {
    if (!_isBluetoothConnected || _fanStates.any((s) => s)) return;

    final lastMomentTimestamp =
    await SmellMomentRecordService.getLastMomentRecordTimestamp();
    final allTodayRecords = await UsageRecordService.getTodayRecords();
    final validRecords = allTodayRecords
        .where((r) => r.createdAt > lastMomentTimestamp && (r.duration ?? 0) > 60)
        .toList();

    debugPrint('本次使用判定：上次弹窗时间=$lastMomentTimestamp, 找到${validRecords.length}条有效记录');

    if (validRecords.isNotEmpty) {
      _showSmellSavePopup(validRecords);
    }
  }

  void _showSmellSavePopup(List<UsageRecord> records) async {
    await CardTriggerRecordService.insertRecord();

    final scentMap = <int, String>{};
    for (final r in records) {
      if (r.scentName != null && r.scentName!.isNotEmpty) {
        scentMap.putIfAbsent(r.fanId, () => r.scentName!);
      }
    }
    final scents = scentMap.values.toList();

    int totalSeconds = records.fold(0, (sum, r) => sum + (r.duration ?? 0));
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;
    final durationStr = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    final recordIds = records.where((r) => r.id != null).map((r) => r.id!).toList();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SmellSavePopup(
        recipeList: scents,
        duration: durationStr,
        recordIds: recordIds,
      ),
    );
  }

  // ---------- 测试方法（保持全部逻辑） ----------
  Future<void> _testTrigger() async {
    final dbHelper = DatabaseHelper();
    final configs = await dbHelper.getAllFanConfigs();
    final scentMap = <int, String>{};
    for (final c in configs) {
      final fanId = c['fan_id'] as int;
      final scentName = c['scent_name'] as String?;
      if (scentName != null && scentName.isNotEmpty) scentMap[fanId] = scentName;
    }

    debugPrint('测试：当前气味配置');
    scentMap.forEach((fanId, scent) => debugPrint('  - 风扇$fanId: $scent'));

    for (final fanId in _testActiveFans) {
      await UsageRecordService.startRecord(fanId);
    }

    debugPrint('测试：开始模拟使用...');
    await Future.delayed(const Duration(seconds: 2));

    debugPrint('测试：关闭所有风扇');
    for (final fanId in _testActiveFans) {
      await UsageRecordService.endRecord(fanId);
    }

    debugPrint('测试：模拟使用时长超过 60 秒');
    final db = await AppDatabase().database;
    for (final fanId in _testActiveFans) {
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
          {'duration': _testSimulatedDuration},
          where: 'id = ?',
          whereArgs: [recordId],
        );
      }
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = startOfDay + const Duration(days: 1).inMilliseconds;

    final validRecords = <UsageRecord>[];
    for (final fanId in _testActiveFans) {
      final records = await db.query(
        'usage_records',
        where: 'fan_id = ? AND start_time >= ? AND start_time < ? AND end_time IS NOT NULL AND duration > 60',
        whereArgs: [fanId, startOfDay, endOfDay],
        orderBy: 'start_time DESC',
        limit: 1,
      );
      if (records.isNotEmpty) validRecords.add(UsageRecord.fromMap(records.first));
    }

    debugPrint('测试：找到${validRecords.length}条有效记录');
    for (final r in validRecords) {
      debugPrint('  - 风扇${r.fanId}: ${r.scentName}, 时长${r.duration}秒');
    }

    if (validRecords.isNotEmpty) {
      _showSmellSavePopup(validRecords);
    } else {
      _showSnackBar('测试失败：没有符合条件的记录');
    }
  }

  void _testCareDialog() {
    const careData = {
      'type': 'test',
      'message': '💛 来自气味的关怀\n\n你好，这里是测试关怀弹窗。\n别忘了给自己一点疗愈时间。',
      'scene': '疲惫舒缓',
    };
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFF5E6D3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Center(
          child: Text('💛 来自气味的关怀',
              style: TextStyle(fontWeight: FontWeight.w600, color: _textColor)),
        ),
        content: Text(careData['message']!,
            style: const TextStyle(fontSize: 16, color: _textColor), textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  // ---------- UI 构建 ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('情绪香薰控制中心')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(_verticalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionBar(),
            const SizedBox(height: 24),
            const Text('风扇控制',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildFanCard(),
            const SizedBox(height: 24),
            _buildControlButtons(),
            const SizedBox(height: 16),
            _buildTestButtons(),
            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FanScentConfigPage()),
        ),
        backgroundColor: _accentGreen,
        child: const Icon(Icons.eco, color: Colors.white),
      ),
    );
  }

  Widget _buildConnectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _isBluetoothConnected ? _connectionBgConnected : _connectionBgDisconnected,
        borderRadius: BorderRadius.circular(_defaultRadius),
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
                color: _isBluetoothConnected ? Colors.green : Colors.grey,
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
    );
  }

  Widget _buildFanCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
      child: Column(
        children: List.generate(4, (i) => [
          _buildFanTile(i),
          if (i < 3) const Divider(height: 1),
        ]).expand((e) => e).toList(),
      ),
    );
  }

  Widget _buildFanTile(int index) {
    final isOn = _fanStates[index];
    return Column(
      children: [
        SwitchListTile(
          title: Text('风扇 ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          secondary: const Icon(Icons.toys, color: Colors.blue),
          value: isOn,
          onChanged: (v) => _toggleFan(index, v),
          activeThumbColor: Colors.green,
          inactiveThumbColor: Colors.grey,
        ),
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
                  foregroundColor: _accentGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_defaultRadius),
                    side: const BorderSide(color: _accentGreen),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildLabeledButton(
            onPressed: () => _sendCommand(BluetoothService.allOff, '所有风扇已关闭'),
            icon: Icons.stop_circle,
            label: '关闭所有风扇',
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildLabeledButton(
            onPressed: () => _sendCommand(BluetoothService.emergencyStop, '紧急停止'),
            icon: Icons.power_settings_new,
            label: '紧急停止',
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildTestButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildLabeledButton(
            onPressed: _testTrigger,
            icon: Icons.play_arrow,
            label: '测试气味瞬间',
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildLabeledButton(
            onPressed: _testCareDialog,
            icon: Icons.favorite,
            label: '测试关怀',
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}