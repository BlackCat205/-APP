/// 气味日记笔记模型
class ScentDiaryNote {
  int? id;
  String mood;
  String usedScent;
  String scene;
  String noteContent;
  int createdAt;

  ScentDiaryNote({
    this.id,
    required this.mood,
    required this.usedScent,
    required this.scene,
    required this.noteContent,
    required this.createdAt,
  });

  /// 从Map转换为模型
  factory ScentDiaryNote.fromMap(Map<String, dynamic> map) {
    return ScentDiaryNote(
      id: map['id'],
      mood: map['mood'],
      usedScent: map['used_scent'],
      scene: map['scene'],
      noteContent: map['note_content'],
      createdAt: map['created_at'],
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mood': mood,
      'used_scent': usedScent,
      'scene': scene,
      'note_content': noteContent,
      'created_at': createdAt,
    };
  }
}
