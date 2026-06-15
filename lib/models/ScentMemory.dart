import 'package:hive/hive.dart';

part 'ScentMemory.g.dart';

/// 气味记忆模型，使用 Hive 存储
@HiveType(typeId: 0)
class ScentMemory {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userInput;

  @HiveField(2)
  final String emotion;

  @HiveField(3)
  final String scent;

  @HiveField(4)
  final DateTime timestamp;

  const ScentMemory({
    required this.id,
    required this.userInput,
    required this.emotion,
    required this.scent,
    required this.timestamp,
  });
}