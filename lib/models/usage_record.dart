/// 使用记录模型（单风扇记录）
///
/// [startTime]、[endTime] 和 [createdAt] 单位为毫秒时间戳；
/// [duration] 单位为秒；[fanId] 范围 1-4
class UsageRecord {
  final int? id;
  final int startTime;
  final int? endTime;
  final int? duration;
  final int fanId;
  final String? scentName;
  final int createdAt;
  final String? sessionId;
  final String source;
  final String status;

  const UsageRecord({
    this.id,
    required this.startTime,
    this.endTime,
    this.duration,
    required this.fanId,
    this.scentName,
    required this.createdAt,
    this.sessionId,
    this.source = 'legacy_unknown',
    this.status = 'legacy_unknown',
  });

  /// 从数据库 Map 构造
  factory UsageRecord.fromMap(Map<String, dynamic> map) {
    return UsageRecord(
      id: map['id'] as int?,
      startTime: map['start_time'] as int,
      endTime: map['end_time'] as int?,
      duration: map['duration'] as int?,
      fanId: map['fan_id'] as int,
      scentName: map['scent_name'] as String?,
      createdAt: map['created_at'] as int,
      sessionId: map['session_id'] as String?,
      source: map['source'] as String? ?? 'legacy_unknown',
      status: map['status'] as String? ?? 'legacy_unknown',
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() => {
    'id': id,
    'start_time': startTime,
    'end_time': endTime,
    'duration': duration,
    'fan_id': fanId,
    'scent_name': scentName,
    'created_at': createdAt,
    'session_id': sessionId,
    'source': source,
    'status': status,
  };

  /// 创建修改后的副本
  UsageRecord copyWith({
    int? id,
    int? startTime,
    int? endTime,
    int? duration,
    int? fanId,
    String? scentName,
    int? createdAt,
    String? sessionId,
    String? source,
    String? status,
  }) {
    return UsageRecord(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      fanId: fanId ?? this.fanId,
      scentName: scentName ?? this.scentName,
      createdAt: createdAt ?? this.createdAt,
      sessionId: sessionId ?? this.sessionId,
      source: source ?? this.source,
      status: status ?? this.status,
    );
  }
}
