class DeviceModel {
  final String id;
  final String name;
  final bool isOnline;
  final bool isPoweredOn;
  final ConcentrationLevel concentration;
  final int timer; // 单位：分钟
  final List<ScentChannel> scentChannels;
  final int speed; // 0: 低, 1: 中, 2: 高

  const DeviceModel({
    required this.id,
    required this.name,
    required this.isOnline,
    required this.isPoweredOn,
    required this.concentration,
    required this.timer,
    required this.scentChannels,
    this.speed = 1,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'],
      name: json['name'],
      isOnline: json['isOnline'] ?? false,
      isPoweredOn: json['isPoweredOn'] ?? false,
      concentration: ConcentrationLevel.medium,
      timer: json['timer'] ?? 30,
      scentChannels: [
        ScentChannel(channel: 1, isActive: false, speed: 66),
        ScentChannel(channel: 2, isActive: false, speed: 66),
        ScentChannel(channel: 3, isActive: false, speed: 66),
        ScentChannel(channel: 4, isActive: false, speed: 66),
      ],
    );
  }
}

enum ConcentrationLevel { low, medium, high }

class ScentChannel {
  final int channel;
  final bool isActive;
  final int speed;

  const ScentChannel({
    required this.channel,
    required this.isActive,
    required this.speed,
  });
}
