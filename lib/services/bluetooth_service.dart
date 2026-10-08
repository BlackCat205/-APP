import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;

/// 蓝牙服务：设备连接、指令发送
class BluetoothService {
  // ---------- 静态实例 ----------
  static fb.BluetoothDevice? _device;
  static fb.BluetoothCharacteristic? _writeChar;
  static final ValueNotifier<bool> connection = ValueNotifier(false);
  static bool get isConnected => connection.value;
  static StreamSubscription<fb.BluetoothConnectionState>? _connectionSubscription;

  static void _watchConnection(fb.BluetoothDevice device) {
    _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((state) {
      if (state == fb.BluetoothConnectionState.disconnected) {
        _writeChar = null;
        connection.value = false;
      }
    });
  }

  // ---------- UUID 常量 ----------
  static const String _serviceUuid =
      '19b10000-e8f2-537e-4f6c-d104768a1214';
  static const String _charUuid =
      '19b10001-e8f2-537e-4f6c-d104768a1214';

  // ========== 底层通信 ==========

  /// 向已连接设备发送原始字节数据（带响应写入）
  static Future<void> _sendBytes(List<int> bytes) async {
    if (!isConnected || _writeChar == null) {
      const err = '未连接设备或特征未找到，_writeChar 为空';
      debugPrint(err);
      throw Exception(err);
    }
    try {
      await _writeChar!.write(bytes, withoutResponse: false).timeout(const Duration(seconds: 10));
      debugPrint('✅ 写入成功: $bytes');
    } catch (e) {
      debugPrint('❌ 写入失败: $e');
      rethrow;
    }
  }

  /// 发送字符串指令（UTF-8 编码，不添加换行符）
  static Future<void> _sendString(String command) async {
    final bytes = utf8.encode(command);
    debugPrint('📤 准备发送指令: $command, 字节: $bytes');
    await _sendBytes(bytes);
    debugPrint('📤 指令已发送: $command');
  }

  // ---------- 公开指令接口 ----------

  /// 发送带换行符的原始字符串指令
  static Future<void> sendRawCommand(String command) async {
    final full = '$command\n';
    final bytes = utf8.encode(full);
    debugPrint('📤 准备发送原始指令: $full, 字节: $bytes');
    await _sendBytes(bytes);
    debugPrint('📤 原始指令已发送: $full');
  }

  /// 发送纯字符串指令（不带换行符，供定时页面使用）
  static Future<void> sendPlainCommand(String command) async {
    final bytes = utf8.encode(command);
    debugPrint('📤 准备发送纯指令: $command, 字节: $bytes');
    await _sendBytes(bytes);
    debugPrint('📤 纯指令已发送: $command');
  }

  // ---------- 硬件指令 ----------

  static Future<void> sendFanOn(int fanNum) async {
    if (_isValidFan(fanNum)) await _sendString('fan${fanNum}on');
  }

  static Future<void> sendFanOff(int fanNum) async {
    if (_isValidFan(fanNum)) await _sendString('fan${fanNum}off');
  }

  static Future<void> sendAllOn() async => _sendString('allon');
  static Future<void> sendAllOff() async => _sendString('alloff');

  static bool _isValidFan(int fanNum) => fanNum >= 1 && fanNum <= 4;

  // ---------- 便捷调用 ----------

  static Future<void> fan1On() async => sendFanOn(1);
  static Future<void> fan2On() async => sendFanOn(2);
  static Future<void> fan3On() async => sendFanOn(3);
  static Future<void> fan4On() async => sendFanOn(4);

  static Future<void> fan1Off() async => sendFanOff(1);
  static Future<void> fan2Off() async => sendFanOff(2);
  static Future<void> fan3Off() async => sendFanOff(3);
  static Future<void> fan4Off() async => sendFanOff(4);

  static Future<void> allOff() async => sendAllOff();
  static Future<void> emergencyStop() async => sendAllOff();

  // ========== 连接管理 ==========

  /// 按设备名称扫描并连接
  static Future<bool> connectToDeviceByName(String targetName) async {
    await fb.FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    final completer = Completer<bool>();
    fb.BluetoothDevice? selected;
    late final StreamSubscription<List<fb.ScanResult>> subscription;

    subscription = fb.FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        if (result.device.name == targetName) {
          selected = result.device;
          fb.FlutterBluePlus.stopScan();
          subscription.cancel();
          completer.complete(true);
          return;
        }
      }
    });

    // 超时保护
    Future.delayed(const Duration(seconds: 6), () {
      if (!completer.isCompleted) {
        fb.FlutterBluePlus.stopScan();
        subscription.cancel();
        completer.complete(false);
      }
    });

    final found = await completer.future;
    if (!found) return false;

    return connectToDeviceByDevice(selected!);
  }

  /// 直接连接给定的蓝牙设备对象
  static Future<bool> connectToDeviceByDevice(fb.BluetoothDevice device) async {
    if (_device != null && _device != device) await disconnect();
    _device = device;
    _writeChar = null;
    connection.value = false;
    try {
      await device.connect();
      _watchConnection(device);
      await _discoverServices();
      if (!device.isConnected) throw StateError('服务发现期间连接已断开');
      connection.value = true;
      return true;
    } catch (_) {
      _writeChar = null;
      connection.value = false;
      rethrow;
    }
  }

  /// 发现目标服务与特征
  static Future<void> _discoverServices() async {
    if (_device == null) throw Exception('设备为空');

    debugPrint('开始发现服务...');
    final services = await _device!.discoverServices();
    debugPrint('共发现 ${services.length} 个服务');

    for (final service in services) {
      debugPrint('服务 UUID: ${service.uuid}');
      if (service.uuid.toString().toLowerCase() == _serviceUuid) {
        debugPrint('找到目标服务，特征列表：');
        for (final char in service.characteristics) {
          debugPrint('特征 UUID: ${char.uuid}, 属性: ${char.properties}');
          if (char.uuid.toString().toLowerCase() == _charUuid) {
            _writeChar = char;
            debugPrint('✅ 找到目标特征值');
            break;
          }
        }
        break;
      }
    }

    if (_writeChar == null) {
      debugPrint('❌ 未找到匹配的特征值，请检查 UUID');
      throw Exception('特征值未找到');
    }
  }

  /// 断开连接并清理资源
  static Future<void> disconnect() async {
    await _device?.disconnect();
    connection.value = false;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _writeChar = null;
    _device = null;
  }
}