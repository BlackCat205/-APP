/// 香薰设备模型
///
/// [concentration] 浓度等级；[timer] 定时分钟数；
/// [scentChannels] 四个通道的状态；[speed] 0=低, 1=中, 2=高
class DeviceModel {
  final String id;
  final String name;
  final bool isOnline;
  final bool isPoweredOn;
  final ConcentrationLevel concentration;
  final int timer;
  final List<ScentChannel> scentChannels;
  final int speed;

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

  /// 从 JSON 创建，并提供默认的四通道配置
  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      isOnline: json['isOnline'] as bool? ?? false,
      isPoweredOn: json['isPoweredOn'] as bool? ?? false,
      concentration: ConcentrationLevel.medium,
      timer: json['timer'] as int? ?? 30,
      scentChannels: const [
        ScentChannel(channel: 1, isActive: false, speed: 66),
        ScentChannel(channel: 2, isActive: false, speed: 66),
        ScentChannel(channel: 3, isActive: false, speed: 66),
        ScentChannel(channel: 4, isActive: false, speed: 66),
      ],
    );
  }
}

/// 浓度等级
enum ConcentrationLevel { low, medium, high }

/// 单个香薰通道的状态
///
/// [channel] 通道编号 1-4；[isActive] 是否开启；[speed] 风速值
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