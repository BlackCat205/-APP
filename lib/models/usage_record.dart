/// 使用记录模型
class UsageRecord {
  final int? id;
  final int startTime; // 开始时间戳（毫秒）
  final int? endTime; // 结束时间戳（毫秒）
  final int? duration; // 时长（秒）
  final String fanIds; // 风扇ID列表，如"1,2"
  final String? scentCombo; // 气味组合，如"檀香+薰衣草"
  final String? sceneTag; // 场景标签
  final String? emotionEmoji; // 情绪emoji
  final int createdAt; // 记录创建时间

  UsageRecord({
    this.id,
    required this.startTime,
    this.endTime,
    this.duration,
    required this.fanIds,
    this.scentCombo,
    this.sceneTag,
    this.emotionEmoji,
    required this.createdAt,
  });

  /// 从Map转换
  factory UsageRecord.fromMap(Map<String, dynamic> map) {
    return UsageRecord(
      id: map['id'] as int?,
      startTime: map['start_time'] as int,
      endTime: map['end_time'] as int?,
      duration: map['duration'] as int?,
      fanIds: map['fan_ids'] as String,
      scentCombo: map['scent_combo'] as String?,
      sceneTag: map['scene_tag'] as String?,
      emotionEmoji: map['emotion_emoji'] as String?,
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
      'fan_ids': fanIds,
      'scent_combo': scentCombo,
      'scene_tag': sceneTag,
      'emotion_emoji': emotionEmoji,
      'created_at': createdAt,
    };
  }

  /// 复制并修改
  UsageRecord copyWith({
    int? id,
    int? startTime,
    int? endTime,
    int? duration,
    String? fanIds,
    String? scentCombo,
    String? sceneTag,
    String? emotionEmoji,
    int? createdAt,
  }) {
    return UsageRecord(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      fanIds: fanIds ?? this.fanIds,
      scentCombo: scentCombo ?? this.scentCombo,
      sceneTag: sceneTag ?? this.sceneTag,
      emotionEmoji: emotionEmoji ?? this.emotionEmoji,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
