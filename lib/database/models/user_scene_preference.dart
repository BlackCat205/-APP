/// 用户场景偏好模型
class UserScenePreference {
  int? id;
  String sceneType;
  String preferredScent;
  String rejectedScents;
  int defaultSpeed;
  int defaultTimer;
  int updatedAt;

  UserScenePreference({
    this.id,
    required this.sceneType,
    required this.preferredScent,
    required this.rejectedScents,
    required this.defaultSpeed,
    required this.defaultTimer,
    required this.updatedAt,
  });

  /// 从Map转换为模型
  factory UserScenePreference.fromMap(Map<String, dynamic> map) {
    return UserScenePreference(
      id: map['id'],
      sceneType: map['scene_type'],
      preferredScent: map['preferred_scent'],
      rejectedScents: map['rejected_scents'],
      defaultSpeed: map['default_speed'],
      defaultTimer: map['default_timer'],
      updatedAt: map['updated_at'],
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scene_type': sceneType,
      'preferred_scent': preferredScent,
      'rejected_scents': rejectedScents,
      'default_speed': defaultSpeed,
      'default_timer': defaultTimer,
      'updated_at': updatedAt,
    };
  }
}
