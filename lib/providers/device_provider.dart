import 'package:flutter/foundation.dart';
import '../models/DeviceModel.dart';

/// 设备状态管理，支持单个或多个设备的信息更新。
class DeviceProvider extends ChangeNotifier {
  List<DeviceModel> _devices = [];

  List<DeviceModel> get devices => _devices;

  // ---------- 批量初始化 ----------
  void initDevices(List<DeviceModel> initialDevices) {
    _devices = initialDevices;
    notifyListeners();
  }

  // ---------- 通用更新工具 ----------
  /// 根据设备 ID 查找索引，若存在则应用 [builder] 并通知监听器。
  void _updateDevice(String deviceId, DeviceModel Function(DeviceModel old) builder) {
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      _devices[index] = builder(_devices[index]);
      notifyListeners();
    }
  }

  /// 创建与旧设备仅有指定字段不同的新 DeviceModel。
  DeviceModel _copyWith(
      DeviceModel old, {
        bool? isOnline,
        bool? isPoweredOn,
        ConcentrationLevel? concentration,
        int? timer,
        int? speed,
        List<ScentChannel>? scentChannels,
      }) {
    return DeviceModel(
      id: old.id,
      name: old.name,
      isOnline: isOnline ?? old.isOnline,
      isPoweredOn: isPoweredOn ?? old.isPoweredOn,
      concentration: concentration ?? old.concentration,
      timer: timer ?? old.timer,
      speed: speed ?? old.speed,
      scentChannels: scentChannels ?? old.scentChannels,
    );
  }

  // ---------- 在线/电源 ----------
  void setOnline(String deviceId, bool online) {
    _updateDevice(deviceId, (old) => _copyWith(old, isOnline: online));
  }

  void setPower(String deviceId, bool isOn) {
    _updateDevice(deviceId, (old) => _copyWith(old, isPoweredOn: isOn));
  }

  void togglePower(String deviceId) {
    _updateDevice(deviceId, (old) => _copyWith(old, isPoweredOn: !old.isPoweredOn));
  }

  // ---------- 定时/风速 ----------
  void updateTimer(String deviceId, int newTimer) {
    _updateDevice(deviceId, (old) => _copyWith(old, timer: newTimer));
  }

  void updateSpeed(String deviceId, int newSpeed) {
    _updateDevice(deviceId, (old) => _copyWith(old, speed: newSpeed));
  }

  // ---------- 通道操作 ----------
  void toggleChannel(String deviceId, int channelIndex, bool isActive) {
    _updateDevice(deviceId, (old) {
      final channels = List<ScentChannel>.from(old.scentChannels);
      channels[channelIndex] = ScentChannel(
        channel: channelIndex + 1,
        isActive: isActive,
        speed: channels[channelIndex].speed,
      );
      return _copyWith(old, scentChannels: channels);
    });
  }

  void setChannelSpeed(String deviceId, int channelIndex, int speed) {
    _updateDevice(deviceId, (old) {
      final channels = List<ScentChannel>.from(old.scentChannels);
      channels[channelIndex] = ScentChannel(
        channel: channelIndex + 1,
        isActive: channels[channelIndex].isActive,
        speed: speed,
      );
      return _copyWith(old, scentChannels: channels);
    });
  }
}