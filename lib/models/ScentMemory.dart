import 'package:hive/hive.dart';

part 'ScentMemory.g.dart';

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

  ScentMemory({
    required this.id,
    required this.userInput,
    required this.emotion,
    required this.scent,
    required this.timestamp,
  });
}
