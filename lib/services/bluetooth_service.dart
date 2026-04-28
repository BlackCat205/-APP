import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;

class BluetoothService {
  static fb.BluetoothDevice? _device;
  static fb.BluetoothCharacteristic? _writeChar;
  static bool isConnected = false;

  // 发送原始字节数据（带响应写入）
  static Future<void> _sendBytes(List<int> bytes) async {
    if (_writeChar == null) {
      final err = "未连接设备或特征未找到，_writeChar 为空";
      print(err);
      throw Exception(err);
    }
    try {
      // 显式使用 withoutResponse: false，即 Write with Response
      await _writeChar!.write(bytes, withoutResponse: false);
      print("✅ 写入成功: $bytes");
    } catch (e) {
      print("❌ 写入失败: $e");
      rethrow;
    }
  }

  // 发送字符串指令（自动转为UTF-8字节，不添加换行）
  static Future<void> _sendString(String command) async {
    final bytes = utf8.encode(command);
    print("📤 准备发送指令: $command, 字节: $bytes");
    await _sendBytes(bytes);
    print("📤 指令已发送: $command");
  }

  // 发送原始字符串指令（带换行符，供外部调用）
  static Future<void> sendRawCommand(String command) async {
    final fullCommand = "$command\n";
    final bytes = utf8.encode(fullCommand);
    print("📤 准备发送原始指令: $fullCommand, 字节: $bytes");
    await _sendBytes(bytes);
    print("📤 原始指令已发送: $fullCommand");
  }

  // 发送纯原文字符串指令（不带换行符，供定时页面使用）
  static Future<void> sendPlainCommand(String command) async {
    final bytes = utf8.encode(command);
    print("📤 准备发送纯指令: $command, 字节: $bytes");
    await _sendBytes(bytes);
    print("📤 纯指令已发送: $command");
  }

  // ========== 硬件指令方法 ==========
  static Future<void> sendFanOn(int fanNum) async {
    if (fanNum < 1 || fanNum > 4) return;
    await _sendString("fan${fanNum}on");
  }

  static Future<void> sendFanOff(int fanNum) async {
    if (fanNum < 1 || fanNum > 4) return;
    await _sendString("fan${fanNum}off");
  }

  static Future<void> sendAllOn() async => _sendString("allon");
  static Future<void> sendAllOff() async => _sendString("alloff");

  // 便捷方法（供 UI 调用）
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

  // ========== 连接相关方法 ==========
  static Future<bool> connectToDeviceByName(String targetName) async {
    await fb.FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    Completer<bool> completer = Completer();
    late StreamSubscription<List<fb.ScanResult>> subscription;

    subscription = fb.FlutterBluePlus.scanResults.listen((results) {
      for (var result in results) {
        if (result.device.name == targetName) {
          _device = result.device;
          fb.FlutterBluePlus.stopScan();
          subscription.cancel();
          completer.complete(true);
          return;
        }
      }
    });

    Future.delayed(const Duration(seconds: 6), () {
      if (!completer.isCompleted) {
        fb.FlutterBluePlus.stopScan();
        subscription.cancel();
        completer.complete(false);
      }
    });

    bool found = await completer.future;
    if (!found) return false;

    await _device!.connect();
    await _discoverServices();
    isConnected = true; // 服务发现完成后再标记连接成功
    return true;
  }

  // 直接连接设备对象（供弹窗选择使用）
  static Future<bool> connectToDeviceByDevice(fb.BluetoothDevice device) async {
    _device = device;
    print("正在连接设备: ${device.name}");
    await _device!.connect();
    await _discoverServices();
    isConnected = true;
    print("设备连接并服务发现完成");
    return true;
  }

  static Future<void> _discoverServices() async {
    if (_device == null) {
      throw Exception("设备为空");
    }
    print("开始发现服务...");
    List<fb.BluetoothService> services = await _device!.discoverServices();
    print("共发现 ${services.length} 个服务");
    for (var service in services) {
      print("服务 UUID: ${service.uuid}");
      // 统一转为小写比较
      if (service.uuid.toString().toLowerCase() ==
          "19b10000-e8f2-537e-4f6c-d104768a1214") {
        print("找到目标服务，特征列表：");
        for (var char in service.characteristics) {
          print("特征 UUID: ${char.uuid}, 属性: ${char.properties}");
          if (char.uuid.toString().toLowerCase() ==
              "19b10001-e8f2-537e-4f6c-d104768a1214") {
            _writeChar = char;
            print("✅ 找到目标特征值");
            break;
          }
        }
        break;
      }
    }
    if (_writeChar == null) {
      print("❌ 未找到匹配的特征值，请检查 UUID");
      throw Exception("特征值未找到");
    }
  }

  static Future<void> disconnect() async {
    await _device?.disconnect();
    isConnected = false;
    _writeChar = null;
    _device = null;
  }
}
