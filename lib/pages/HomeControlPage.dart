import 'dart:io';
import '../widgets/today_recommendation_card.dart';
import '../models/recommendation.dart';
import '../providers/recommendation_provider.dart';
import 'package:provider/provider.dart';
import '../services/usage_session_service.dart';
import '../services/fan_scent_service.dart';
import 'usage_feedback_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';
import '../services/usage_record_service.dart';
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

  late final UsageSessionService _sessions;
  bool _commandBusy = false;
  final Set<String> _presented = {};
  String? _lastError;

  // UI 仅展示服务确认写入后的状态。
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
    _sessions = context.read<UsageSessionService>();
    if (_sessions.lastFinished != null) _presented.add(_sessions.lastFinished!);
    _sessions.addListener(_syncSession);
    BluetoothService.connection.addListener(_syncSession);
    _isBluetoothConnected = BluetoothService.isConnected;
    _connectionStatus = _isBluetoothConnected ? '已连接' : '未连接';
    for (var i = 0; i < 4; i++) {
      _fanStates[i] = _sessions.activeFans.contains(i + 1);
    }
    _requestPermissions();
  }

  @override
  void dispose() {
    _sessions.removeListener(_syncSession);
    BluetoothService.connection.removeListener(_syncSession);
    super.dispose();
  }

  void _syncSession() {
    if (!mounted) return;
    setState(() {
      _isBluetoothConnected = BluetoothService.isConnected;
      _connectionStatus = _isBluetoothConnected ? '已连接' : '未连接';
      for (var i = 0; i < 4; i++) {
        _fanStates[i] = _sessions.activeFans.contains(i + 1);
      }
    });
    final finished = _sessions.lastFinished;
    if (!_sessions.busy && finished != null && _presented.add(finished)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showFeedback(finished),
      );
    }
    if (_sessions.lastError != null && _sessions.lastError != _lastError) {
      _lastError = _sessions.lastError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSnackBar(_lastError!);
      });
    }
  }

  Future<void> _showFeedback(String id) async {
    if (!mounted) return;
    final user = feedbackUserId(context);
    try {
      final detail = await _sessions.feedbackDetail(id, user);
      if (detail['feedback_id'] != null) return;
      if (!mounted || feedbackUserId(context) != user) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UsageFeedbackPage(sessionId: id, userId: user),
        ),
      );
    } catch (_) {
      /* 其他用户的会话不弹出；可从对应用户的反馈历史进入。 */
    }
  }

  // ---------- 权限 ----------
  Future<void> _requestPermissions() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      debugPrint('桌面端跳过蓝牙权限请求');
      return;
    }
    final scanGranted = await Permission.bluetoothScan.request().isGranted;
    final connectGranted = await Permission.bluetoothConnect
        .request()
        .isGranted;
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
    bool success;
    try {
      success = await BluetoothService.connectToDeviceByDevice(device);
    } catch (e) {
      if (mounted) _showSnackBar('连接失败: $e');
      return;
    }
    if (!mounted) return;
    setState(() {
      _isBluetoothConnected = success;
      _connectionStatus = success ? '已连接' : '连接失败';
    });
    _showSnackBar(success ? '连接成功' : '连接失败');
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
    if (_commandBusy || _sessions.busy) return;
    if (!BluetoothService.isConnected) {
      _showSnackBar('请先连接蓝牙设备');
      return;
    }
    setState(() => _commandBusy = true);
    try {
      if (value) {
        final user = feedbackUserId(context);
        BeforeUseInput? input;
        if (!_sessions.hasActiveSession) {
          input = await askBeforeUse(context);
          if (input == null || !mounted) return;
        }
        if (!mounted || feedbackUserId(context) != user) return;
        await _sessions.startFan(
          index + 1,
          userId: user,
          beforeState: input?.state,
          scene: input?.scene,
        );
      } else {
        await _sessions.stopFan(index + 1);
      }
      if (mounted) _showSnackBar('指令已发送');
    } catch (e) {
      if (mounted) _showSnackBar('操作未完成: $e');
    } finally {
      if (mounted) setState(() => _commandBusy = false);
    }
  }

  Future<void> _startRecommendation(Recommendation recommendation) async {
    if (_commandBusy || _sessions.busy) return;
    if (_sessions.hasActiveSession) {
      _showSnackBar('请先结束当前使用');
      return;
    }
    if (!BluetoothService.isConnected) {
      _showSnackBar('请先连接蓝牙设备');
      return;
    }
    final current = FanScentService.getAllConfig();
    final stillMounted = recommendation.candidate.fans.entries.every(
      (entry) => current[entry.key] == entry.value,
    );
    if (!stillMounted) {
      _showSnackBar('气味配置已经变化，正在更新推荐');
      await context.read<RecommendationProvider>().refresh(clear: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认使用推荐组合'),
        content: Text('将开启：${recommendation.candidate.name}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final user = feedbackUserId(context);
    final input = await askBeforeUse(context);
    if (input == null || !mounted || feedbackUserId(context) != user) return;
    final confirmedConfig = FanScentService.getAllConfig();
    if (!recommendation.candidate.fans.entries.every(
      (entry) => confirmedConfig[entry.key] == entry.value,
    )) {
      _showSnackBar('气味配置已经变化，请重新选择推荐');
      await context.read<RecommendationProvider>().refresh(clear: true);
      return;
    }
    setState(() => _commandBusy = true);
    try {
      await _sessions.startCombination(
        recommendation.candidate.fans.keys,
        userId: user,
        beforeState: input.state,
        scene: input.scene,
      );
      if (mounted) _showSnackBar('推荐组合已启动');
    } catch (e) {
      if (mounted) _showSnackBar('组合未完整启动: $e');
    } finally {
      if (mounted) setState(() => _commandBusy = false);
    }
  }

  void _openTimerPage(int fanIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FanTimerPage(fanIndex: fanIndex)),
    );
  }

  // ---------- 推荐数据模拟 ----------
  Future<void> _testTrigger() async {
    if (_sessions.hasActiveSession ||
        _sessions.busy ||
        UsageRecordService.hasActiveRecord()) {
      _showSnackBar('请先结束当前使用，再运行模拟测试');
      return;
    }
    final user = feedbackUserId(context);
    final input = await askBeforeUse(context);
    if (input == null || !mounted || feedbackUserId(context) != user) return;
    try {
      await _sessions.createRecommendationSimulation(
        _testActiveFans,
        userId: user,
        durationSeconds: _testSimulatedDuration,
        beforeState: input.state,
        scene: input.scene ?? '推荐评分测试',
      );
      if (mounted) _showSnackBar('已生成 65 秒模拟使用，请填写反馈');
    } catch (e) {
      if (mounted) _showSnackBar('生成模拟记录失败: $e');
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
          child: Text(
            '💛 来自气味的关怀',
            style: TextStyle(fontWeight: FontWeight.w600, color: _textColor),
          ),
        ),
        content: Text(
          careData['message']!,
          style: const TextStyle(fontSize: 16, color: _textColor),
          textAlign: TextAlign.center,
        ),
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
            TodayRecommendationCard(onStart: _startRecommendation),
            const SizedBox(height: 16),
            _buildConnectionBar(),
            const SizedBox(height: 24),
            const Text('开关显示 APP 最近发送的状态；断连后设备实际状态未知。'),
            const Text(
              '风扇控制',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
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
        onPressed: _sessions.hasActiveSession || _sessions.busy
            ? null
            : () => Navigator.push(
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
        color: _isBluetoothConnected
            ? _connectionBgConnected
            : _connectionBgDisconnected,
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
            onPressed: _sessions.hasActiveSession || _sessions.busy
                ? null
                : _connectBluetooth,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Column(
        children: List.generate(
          4,
          (i) => [_buildFanTile(i), if (i < 3) const Divider(height: 1)],
        ).expand((e) => e).toList(),
      ),
    );
  }

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
          onChanged: _commandBusy || _sessions.busy
              ? null
              : (v) => _toggleFan(index, v),
          activeThumbColor: Colors.green,
          inactiveThumbColor: Colors.grey,
        ),
        if (isOn)
          Padding(
            padding: const EdgeInsets.only(left: 72, right: 16, bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _sessions.busy ? null : () => _openTimerPage(index),
                icon: const Icon(Icons.timer, size: 18),
                label: const Text('定时关闭'),
                style: TextButton.styleFrom(
                  foregroundColor: _accentGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
            onPressed: () => _sendCommand(_sessions.stopAll, '全部关闭指令已发送'),
            icon: Icons.stop_circle,
            label: '关闭所有风扇',
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildLabeledButton(
            onPressed: () => _sendCommand(_sessions.stopAll, '紧急停止指令已发送'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
