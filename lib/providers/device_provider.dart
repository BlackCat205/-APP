import 'package:flutter/material.dart';
import '../models/DeviceModel.dart';

class DeviceProvider extends ChangeNotifier {
  // 当前设备列表（可以扩展为多设备，目前先单设备）
  List<DeviceModel> _devices = [];

  List<DeviceModel> get devices => _devices;


  // 在 DeviceProvider 类中添加以下方法

// 切换指定通道的开关
  void toggleChannel(String deviceId, int channelIndex, bool isActive) {
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      final old = _devices[index];
      final updatedChannels = List<ScentChannel>.from(old.scentChannels);
      updatedChannels[channelIndex] = ScentChannel(
        channel: channelIndex + 1,
        isActive: isActive,
        speed: updatedChannels[channelIndex].speed,
      );
      _devices[index] = DeviceModel(
        id: old.id,
        name: old.name,
        isOnline: old.isOnline,
        isPoweredOn: old.isPoweredOn,
        concentration: old.concentration,
        timer: old.timer,
        speed: old.speed,
        scentChannels: updatedChannels,
      );
      notifyListeners();
    }
  }

// 修改指定通道的风速
  void setChannelSpeed(String deviceId, int channelIndex, int speed) {
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      final old = _devices[index];
      final updatedChannels = List<ScentChannel>.from(old.scentChannels);
      updatedChannels[channelIndex] = ScentChannel(
        channel: channelIndex + 1,
        isActive: updatedChannels[channelIndex].isActive,
        speed: speed,
      );
      _devices[index] = DeviceModel(
        id: old.id,
        name: old.name,
        isOnline: old.isOnline,
        isPoweredOn: old.isPoweredOn,
        concentration: old.concentration,
        timer: old.timer,
        speed: old.speed,
        scentChannels: updatedChannels,
      );
      notifyListeners();
    }
  }

// 直接设置电源状态（而不是 toggle）
  void setPower(String deviceId, bool isOn) {
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      final old = _devices[index];
      _devices[index] = DeviceModel(
        id: old.id,
        name: old.name,
        isOnline: old.isOnline,
        isPoweredOn: isOn,
        concentration: old.concentration,
        timer: old.timer,
        speed: old.speed,
        scentChannels: old.scentChannels,
      );
      notifyListeners();
    }
  }
  // 单例模式或直接提供初始化方法
  void initDevices(List<DeviceModel> initialDevices) {
    _devices = initialDevices;
    notifyListeners();
  }

  // 更新电源状态
  void togglePower(String deviceId) {
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      final old = _devices[index];
      _devices[index] = DeviceModel(
        id: old.id,
        name: old.name,
        isOnline: old.isOnline,
        isPoweredOn: !old.isPoweredOn,
        concentration: old.concentration,
        timer: old.timer,
        speed: old.speed,
        scentChannels: old.scentChannels,
      );
      notifyListeners();
    }
  }

  // 更新定时时长（分钟）
  void updateTimer(String deviceId, int newTimer) {
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      final old = _devices[index];
      _devices[index] = DeviceModel(
        id: old.id,
        name: old.name,
        isOnline: old.isOnline,
        isPoweredOn: old.isPoweredOn,
        concentration: old.concentration,
        timer: newTimer,
        speed: old.speed,
        scentChannels: old.scentChannels,
      );
      notifyListeners();
    }
  }

  // 更新风速（如果需要）
  void updateSpeed(String deviceId, int newSpeed) {
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      final old = _devices[index];
      _devices[index] = DeviceModel(
        id: old.id,
        name: old.name,
        isOnline: old.isOnline,
        isPoweredOn: old.isPoweredOn,
        concentration: old.concentration,
        timer: old.timer,
        speed: newSpeed,
        scentChannels: old.scentChannels,
      );
      notifyListeners();
    }
  }

  // 可选：设置设备在线状态（蓝牙连接成功后调用）
  void setOnline(String deviceId, bool online) {
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      final old = _devices[index];
      _devices[index] = DeviceModel(
        id: old.id,
        name: old.name,
        isOnline: online,
        isPoweredOn: old.isPoweredOn,
        concentration: old.concentration,
        timer: old.timer,
        speed: old.speed,
        scentChannels: old.scentChannels,
      );
      notifyListeners();
    }
  }
}