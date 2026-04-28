/// 情绪气味记忆模型
class EmotionScentMemory {
  int? id;
  String emotion;
  String effectiveScent;
  String userFeedback;
  int useCount;
  int createdAt;

  EmotionScentMemory({
    this.id,
    required this.emotion,
    required this.effectiveScent,
    required this.userFeedback,
    required this.useCount,
    required this.createdAt,
  });

  /// 从Map转换为模型
  factory EmotionScentMemory.fromMap(Map<String, dynamic> map) {
    return EmotionScentMemory(
      id: map['id'],
      emotion: map['emotion'],
      effectiveScent: map['effective_scent'],
      userFeedback: map['user_feedback'],
      useCount: map['use_count'],
      createdAt: map['created_at'],
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'emotion': emotion,
      'effective_scent': effectiveScent,
      'user_feedback': userFeedback,
      'use_count': useCount,
      'created_at': createdAt,
    };
  }
}
