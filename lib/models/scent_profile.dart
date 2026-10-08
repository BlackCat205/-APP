class ScentUsageSummary {
  const ScentUsageSummary({
    required this.name,
    required this.count,
    required this.seconds,
  });
  final String name;
  final int count;
  final int seconds;
}

class PreferencePoint {
  const PreferencePoint({required this.time, required this.liking});
  final DateTime time;
  final double liking;
}

class ScentProfile {
  const ScentProfile({
    required this.useCount,
    required this.totalSeconds,
    required this.commonCombinations,
    required this.preferenceTrend,
    required this.preferredTraits,
    required this.dislikedTraits,
    required this.aiStatus,
    this.aiConfidence,
    this.aiReason,
    this.aiUpdatedAt,
  });
  final int useCount, totalSeconds;
  final List<ScentUsageSummary> commonCombinations;
  final List<PreferencePoint> preferenceTrend;
  final List<String> preferredTraits, dislikedTraits;
  final String aiStatus;
  final double? aiConfidence;
  final String? aiReason;
  final DateTime? aiUpdatedAt;
}
