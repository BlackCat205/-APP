import '../models/recommendation.dart';

/// 固定 ID 与风扇位置无关。重复气味保留数量，单路雪松不等于双路雪松。
class ScentCatalog {
  static const idsByName = <String, String>{
    '薰衣草': 'lavender',
    '檀香': 'sandalwood',
    '雪松': 'cedar',
    '甜橙': 'sweet_orange',
    '柠檬': 'lemon',
    '玫瑰': 'rose',
    '茉莉': 'jasmine',
    '桂花': 'osmanthus',
    '百合': 'lily',
    '薄荷': 'mint',
    '绿茶': 'green_tea',
    '海洋': 'marine',
    '木质': 'woody',
    '香草': 'vanilla',
    '白桃': 'white_peach',
    '葡萄': 'grape',
    '蓝莓': 'blueberry',
    '沉香': 'agarwood',
    '柑橘': 'citrus',
    '栀子花': 'gardenia',
  };

  static String? key(Iterable<String> scents) {
    final ids = <String>[];
    for (final scent in scents) {
      final id = idsByName[scent.trim()];
      if (id == null) return null;
      ids.add(id);
    }
    if (ids.isEmpty) return null;
    ids.sort();
    return ids.join('+');
  }

  static List<ScentCandidate> candidates(Map<int, String> configuration) {
    final fans =
        configuration.keys
            .where(
              (id) =>
                  id >= 1 &&
                  id <= 4 &&
                  idsByName.containsKey(configuration[id]?.trim()),
            )
            .toList()
          ..sort();
    final unique = <String, ScentCandidate>{};
    for (var mask = 1; mask < (1 << fans.length); mask++) {
      final selected = <int, String>{
        for (var i = 0; i < fans.length; i++)
          if (mask & (1 << i) != 0) fans[i]: configuration[fans[i]]!.trim(),
      };
      final id = key(selected.values)!;
      unique.putIfAbsent(id, () => ScentCandidate(id: id, fans: selected));
    }
    return unique.values.toList()..sort((a, b) {
      final count = a.fans.length.compareTo(b.fans.length);
      return count != 0 ? count : a.id.compareTo(b.id);
    });
  }
}
