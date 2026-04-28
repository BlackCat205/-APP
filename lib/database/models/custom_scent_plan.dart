/// 自定义香氛方案模型
class CustomScentPlan {
  int? id;
  String planName;
  String scene;
  String fan1Scent;
  int fan1Speed;
  String fan2Scent;
  int fan2Speed;
  String fan3Scent;
  int fan3Speed;
  String fan4Scent;
  int fan4Speed;
  int timerMinutes;
  int createdAt;

  CustomScentPlan({
    this.id,
    required this.planName,
    required this.scene,
    required this.fan1Scent,
    required this.fan1Speed,
    required this.fan2Scent,
    required this.fan2Speed,
    required this.fan3Scent,
    required this.fan3Speed,
    required this.fan4Scent,
    required this.fan4Speed,
    required this.timerMinutes,
    required this.createdAt,
  });

  /// 从Map转换为模型
  factory CustomScentPlan.fromMap(Map<String, dynamic> map) {
    return CustomScentPlan(
      id: map['id'],
      planName: map['plan_name'],
      scene: map['scene'],
      fan1Scent: map['fan1_scent'],
      fan1Speed: map['fan1_speed'],
      fan2Scent: map['fan2_scent'],
      fan2Speed: map['fan2_speed'],
      fan3Scent: map['fan3_scent'],
      fan3Speed: map['fan3_speed'],
      fan4Scent: map['fan4_scent'],
      fan4Speed: map['fan4_speed'],
      timerMinutes: map['timer_minutes'],
      createdAt: map['created_at'],
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plan_name': planName,
      'scene': scene,
      'fan1_scent': fan1Scent,
      'fan1_speed': fan1Speed,
      'fan2_scent': fan2Scent,
      'fan2_speed': fan2Speed,
      'fan3_scent': fan3Scent,
      'fan3_speed': fan3Speed,
      'fan4_scent': fan4Scent,
      'fan4_speed': fan4Speed,
      'timer_minutes': timerMinutes,
      'created_at': createdAt,
    };
  }
}
