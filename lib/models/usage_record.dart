/// 使用记录模型（单风扇记录）
class UsageRecord {
  final int? id;
  final int startTime; // 开始时间戳（毫秒）
  final int? endTime; // 结束时间戳（毫秒）
  final int? duration; // 时长（秒）
  final int fanId; // 单个风扇ID
  final String? scentName; // 气味名称
  final int createdAt; // 记录创建时间

  UsageRecord({
    this.id,
    required this.startTime,
    this.endTime,
    this.duration,
    required this.fanId,
    this.scentName,
    required this.createdAt,
  });

  /// 从Map转换
  factory UsageRecord.fromMap(Map<String, dynamic> map) {
    return UsageRecord(
      id: map['id'] as int?,
      startTime: map['start_time'] as int,
      endTime: map['end_time'] as int?,
      duration: map['duration'] as int?,
      fanId: map['fan_id'] as int,
      scentName: map['scent_name'] as String?,
      createdAt: map['created_at'] as int,
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start_time': startTime,
      'end_time': endTime,
      'duration': duration,
      'fan_id': fanId,
      'scent_name': scentName,
      'created_at': createdAt,
    };
  }

  /// 复制并修改
  UsageRecord copyWith({
    int? id,
    int? startTime,
    int? endTime,
    int? duration,
    int? fanId,
    String? scentName,
    int? createdAt,
  }) {
    return UsageRecord(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      fanId: fanId ?? this.fanId,
      scentName: scentName ?? this.scentName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
