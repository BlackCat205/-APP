import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 香氛数据模型（科研论文支撑）
class ScentData {
  final String name;
  final String paperTitle;
  final String conclusion;
  final List<String> applicableEmotions;

  const ScentData({
    required this.name,
    required this.paperTitle,
    required this.conclusion,
    required this.applicableEmotions,
  });
}

/// 讯飞星火大模型 API 服务（气味推荐）
class SparkApiService {
  final String apiPassword;
  final String modelName;
  final String baseUrl;

  // ========== 网络常量 ==========
  static const int _maxRetries = 2;
  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _retryDelay = Duration(seconds: 1);

  // ========== 官方气味库（4种核心精油） ==========
  static const List<ScentData> _officialScents = [
    ScentData(
      name: '大马士革玫瑰',
      paperTitle:
      'The effects of Rosa damascene aromatherapy on mood and sleep: a systematic review and meta-analysis',
      conclusion:
      'RD芳香疗法可以有效减少焦虑，改善相关的血液动力学参数，缓解压力症状，同时还能提高睡眠质量',
      applicableEmotions: ['焦虑', '压力', '失眠', '情绪低落'],
    ),
    ScentData(
      name: '薰衣草',
      paperTitle: 'Aromatherapy: Therapy with Fragrances of Lavender Essential Oil',
      conclusion:
      '薰衣草对睡眠质量、缓解焦虑和减少抑郁症有积极影响。它还具有认知能力，并影响逐渐缓解疼痛；因此，它作为替代或辅助疗法，在牙科、术前治疗、产科、烧伤和癌症患者中显示出巨大的应用潜力。',
      applicableEmotions: ['焦虑', '失眠', '抑郁', '疼痛', '压力'],
    ),
    ScentData(
      name: '苦橙',
      paperTitle:
      'Effect of Citrus x aurantium L. Aromatherapy on Anxiety: A Systematic Review and Meta-Analysis',
      conclusion:
      '苦橙精油/橙花油干预组的焦虑水平显著降低，均值差为-12.45 (95% CI: -20.90至-3.99, p = 0.004)。因此，吸入苦橙精油和橙花油是有效降低焦虑水平的芳香疗法手段。',
      applicableEmotions: ['焦虑', '压力', '紧张'],
    ),
    ScentData(
      name: '柠檬',
      paperTitle:
      'Olfactory influences on mood and autonomic, endocrine, and immune function',
      conclusion:
      '柠檬气味在缓解压力时可能可靠地提升积极情绪，该效应独立于被试的预期。研究表明，嗅觉刺激可通过情绪调节通路影响自主神经、内分泌和免疫系统的功能状态，为气味-情绪-生理系统的整合提供了跨系统的实证证据。',
      applicableEmotions: ['疲惫', '压力', '焦虑', '低落'],
    ),
  ];

  // ========== 本地情绪-香氛映射表 ==========
  static const Map<String, Map<String, dynamic>> _localScentMap = {
    // 压力焦虑类
    '压力': {
      'emotion': '焦虑',
      'intensity': 4,
      'scent': '薰衣草',
      'reason':
      '根据《Aromatherapy: Therapy with Fragrances of Lavender Essential Oil》研究，薰衣草对睡眠质量、缓解焦虑和减少抑郁症有积极影响。',
      'scene': '愉悦治愈场景',
    },
    '焦虑': {
      'emotion': '焦虑',
      'intensity': 4,
      'scent': '大马士革玫瑰',
      'reason':
      '根据《The effects of Rosa damascene aromatherapy on mood and sleep: a systematic review and meta-analysis》研究，大马士革玫瑰芳香疗法可以有效减少焦虑，改善相关的血液动力学参数，缓解压力症状。',
      'scene': '助眠安神场景',
    },
    '紧张': {
      'emotion': '焦虑',
      'intensity': 4,
      'scent': '苦橙',
      'reason':
      '根据《Effect of Citrus x aurantium L. Aromatherapy on Anxiety: A Systematic Review and Meta-Analysis》研究，吸入苦橙精油是有效降低焦虑水平的芳香疗法手段。',
      'scene': '愉悦治愈场景',
    },
    // 疲惫提神类
    '疲劳': {
      'emotion': '疲惫',
      'intensity': 5,
      'scent': '柠檬',
      'reason':
      '根据《Olfactory influences on mood and autonomic, endocrine, and immune function》研究，柠檬气味在缓解压力时可能可靠地提升积极情绪。',
      'scene': '疲惫舒缓场景',
    },
    '没精神': {
      'emotion': '疲惫',
      'intensity': 4,
      'scent': '柠檬',
      'reason':
      '根据《Olfactory influences on mood and autonomic, endocrine, and immune function》研究，柠檬气味在缓解压力时可能可靠地提升积极情绪。',
      'scene': '提神醒脑场景',
    },
    '困倦': {
      'emotion': '困倦',
      'intensity': 4,
      'scent': '柠檬',
      'reason':
      '根据《Olfactory influences on mood and autonomic, endocrine, and immune function》研究，柠檬气味在缓解压力时可能可靠地提升积极情绪。',
      'scene': '提神醒脑场景',
    },
    // 愉悦开心类
    '开心': {
      'emotion': '愉悦',
      'intensity': 3,
      'scent': '柠檬',
      'reason':
      '根据《Olfactory influences on mood and autonomic, endocrine, and immune function》研究，柠檬气味在缓解压力时可能可靠地提升积极情绪。',
      'scene': '愉悦治愈场景',
    },
    '愉悦': {
      'emotion': '愉悦',
      'intensity': 3,
      'scent': '大马士革玫瑰',
      'reason':
      '根据《The effects of Rosa damascene aromatherapy on mood and sleep: a systematic review and meta-analysis》研究，大马士革玫瑰芳香疗法可以有效减少焦虑，改善相关的血液动力学参数，缓解压力症状。',
      'scene': '愉悦治愈场景',
    },
    // 异味净化类
    '烟味': {
      'emotion': '不适',
      'intensity': 4,
      'scent': '柠檬',
      'reason':
      '根据《Olfactory influences on mood and autonomic, endocrine, and immune function》研究，柠檬气味在缓解压力时可能可靠地提升积极情绪。',
      'scene': '疲惫舒缓场景',
    },
    '异味': {
      'emotion': '不适',
      'intensity': 4,
      'scent': '柠檬',
      'reason':
      '根据《Olfactory influences on mood and autonomic, endocrine, and immune function》研究，柠檬气味在缓解压力时可能可靠地提升积极情绪。',
      'scene': '疲惫舒缓场景',
    },
    '臭味': {
      'emotion': '不适',
      'intensity': 5,
      'scent': '柠檬',
      'reason':
      '根据《Olfactory influences on mood and autonomic, endocrine, and immune function》研究，柠檬气味在缓解压力时可能可靠地提升积极情绪。',
      'scene': '疲惫舒缓场景',
    },
    // 其他场景
    '难过': {
      'emotion': '低落',
      'intensity': 4,
      'scent': '大马士革玫瑰',
      'reason':
      '根据《The effects of Rosa damascene aromatherapy on mood and sleep: a systematic review and meta-analysis》研究，大马士革玫瑰芳香疗法可以有效减少焦虑，改善相关的血液动力学参数，缓解压力症状。',
      'scene': '愉悦治愈场景',
    },
    '失眠': {
      'emotion': '困倦',
      'intensity': 5,
      'scent': '薰衣草',
      'reason':
      '根据《Aromatherapy: Therapy with Fragrances of Lavender Essential Oil》研究，薰衣草对睡眠质量、缓解焦虑和减少抑郁症有积极影响。',
      'scene': '助眠安神场景',
    },
    '烦躁': {
      'emotion': '焦虑',
      'intensity': 4,
      'scent': '苦橙',
      'reason':
      '根据《Effect of Citrus x aurantium L. Aromatherapy on Anxiety: A Systematic Review and Meta-Analysis》研究，吸入苦橙精油是有效降低焦虑水平的芳香疗法手段。',
      'scene': '愉悦治愈场景',
    },
  };

  SparkApiService({
    required this.apiPassword,
    this.modelName = 'lite',
    this.baseUrl = 'https://spark-api-open.xf-yun.com/v1/chat/completions',
  });

  // ===================== 公共主入口 =====================

  /// 获取气味推荐（优先 API，失败则使用本地兜底）
  Future<Map<String, dynamic>> getScentRecommendation(String userInput) async {
    int retryCount = 0;

    while (retryCount <= _maxRetries) {
      try {
        _logAttemptStart(retryCount, userInput);
        final response = await _executeRequest(userInput);
        _logResponse(response);

        if (response.statusCode == 200) {
          final parsed = _parseApiResponse(response.body);
          if (parsed != null) return parsed;
        }
        // 非 200 或解析失败 -> 直接使用本地兜底
        return _getLocalScentRecommendation(userInput);
      } on http.ClientException catch (e) {
        debugPrint('网络连接失败: $e');
        if (retryCount < _maxRetries) {
          retryCount++;
          await Future.delayed(_retryDelay);
          continue;
        }
        return _getLocalScentRecommendation(userInput);
      } on TimeoutException catch (e) {
        debugPrint('请求超时: $e');
        if (retryCount < _maxRetries) {
          retryCount++;
          await Future.delayed(_retryDelay);
          continue;
        }
        return _getLocalScentRecommendation(userInput);
      } catch (e) {
        debugPrint('未知错误: $e');
        return _getLocalScentRecommendation(userInput);
      }
    }
    return _getLocalScentRecommendation(userInput);
  }

  // ===================== 请求构建与发送 =====================

  Future<http.Response> _executeRequest(String userInput) async {
    final requestBody = {
      'model': modelName,
      'messages': [
        {
          'role': 'system',
          'content': '''你是专业的情绪芳香疗法顾问，根据用户的情绪状态，推荐最适合的香氛气味。
【可选气味库】：大马士革玫瑰、薰衣草、苦橙、柠檬
【核心推荐要求（必须严格遵守）】：
1. 必须根据用户的具体情绪，推荐**最匹配该情绪**的气味，绝对不能给所有情绪都推荐同一种气味
2. 针对不同情绪，必须推荐**差异化的气味**：
    - 焦虑/压力/失眠：优先推荐薰衣草、大马士革玫瑰、苦橙
    - 疲惫/提神/积极情绪：优先推荐柠檬、苦橙
3. 推荐理由必须**严格引用对应研究结论**，格式统一为：「根据《[论文标题]》研究，[气味] 可 [对应结论]」
4. 严格输出纯JSON格式，禁止任何Markdown代码块、额外文字，格式如下：
{
  "emotion": "情绪标签（贴合用户输入的真实情绪）",
  "intensity": 情绪强度（1-5的整数）,
  "scent": "推荐的香氛气味（从可选气味库中选择，必须匹配情绪）",
  "reason": "详细的推荐理由（引用研究结论）",
  "scene": "推荐的适用场景（贴合用户情绪和气味特性）"
}
''',
        },
        {'role': 'user', 'content': userInput},
      ],
    };

    final authorization = _generateAuthorization();
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': authorization,
    };

    debugPrint('Request Body: ${jsonEncode(requestBody)}');
    debugPrint('Authorization: $authorization');
    debugPrint('等效curl:\ncurl -X POST "$baseUrl" -H "Content-Type: application/json" -H "Authorization: $authorization" -d "${jsonEncode(requestBody)}"\n');

    return http
        .post(Uri.parse(baseUrl), headers: headers, body: jsonEncode(requestBody))
        .timeout(_timeout);
  }

  String _generateAuthorization() => 'Bearer $apiPassword';

  // ===================== 响应解析 =====================

  /// 尝试解析 API 成功响应，返回标准格式或 null（失败时外部调用兜底）
  Map<String, dynamic>? _parseApiResponse(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        debugPrint('API响应缺少choices字段');
        return null;
      }

      final content = choices[0]['message']['content'] as String;
      debugPrint('模型返回原始内容: $content');
      final cleaned = _cleanJson(content);
      debugPrint('清洗后的内容: $cleaned');

      final result = jsonDecode(cleaned) as Map<String, dynamic>;
      if (_isValidResult(result)) {
        debugPrint('最终展示内容: $result');
        return {'success': true, 'data': result};
      } else {
        debugPrint('返回数据缺少必要字段');
        return null;
      }
    } catch (e) {
      debugPrint('解析API响应失败: $e');
      return null;
    }
  }

  /// 清洗模型返回的 JSON 字符串（移除 Markdown 标记）
  String _cleanJson(String raw) {
    return raw
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .replaceAll('`', '')
        .trim()
        .replaceAll(RegExp(r',\s*}'), '}')
        .replaceAll(RegExp(r',\s*]'), ']');
  }

  bool _isValidResult(Map<String, dynamic> result) {
    return result.containsKey('emotion') &&
        result.containsKey('intensity') &&
        result.containsKey('scent') &&
        result.containsKey('reason') &&
        result.containsKey('scene');
  }

  // ===================== 本地兜底 =====================

  /// 使用本地关键词匹配 + 情绪识别返回推荐
  Map<String, dynamic> _getLocalScentRecommendation(String userInput) {
    debugPrint('使用本地兜底逻辑获取气味推荐');

    // 按优先级逐个关键词组匹配
    final match = _matchKeywordGroup(userInput, [
      ['焦虑', '压力', '紧张'],
      ['疲劳', '没精神', '困倦', '疲惫'],
      ['开心', '愉悦', '高兴'],
      ['烟味', '异味', '臭味'],
      ['难过', '悲伤'],
      ['失眠', '睡不着'],
      ['烦躁'],
    ]);

    if (match != null) {
      return {'success': true, 'data': match};
    }

    // 未命中任何关键词，基于情绪识别构建默认推荐
    debugPrint('未匹配到本地情绪，使用默认推荐');
    final emotion = _detectEmotion(userInput);
    return {
      'success': true,
      'data': _buildDefaultRecommendation(emotion),
    };
  }

  /// 遍历关键词组，返回首个匹配的映射表条目
  Map<String, dynamic>? _matchKeywordGroup(
      String input,
      List<List<String>> groups,
      ) {
    for (final group in groups) {
      for (final keyword in group) {
        if (input.contains(keyword)) {
          // 返回该组中第一个在映射表中存在的关键词数据
          final key = group.firstWhere(
                (k) => _localScentMap.containsKey(k),
            orElse: () => group.first,
          );
          return _localScentMap[key];
        }
      }
    }
    return null;
  }

  /// 根据检测到的情绪构建默认推荐数据
  Map<String, dynamic> _buildDefaultRecommendation(String emotion) {
    String scent, reason, scene;
    switch (emotion) {
      case '疲惫':
      case '困倦':
        scent = '柠檬';
        reason =
        '根据《Olfactory influences on mood and autonomic, endocrine, and immune function》研究，柠檬气味在缓解压力时可能可靠地提升积极情绪。';
        scene = '工作或学习时使用，提升注意力和精神状态';
        break;
      case '焦虑':
      case '紧张':
      case '压力':
      case '烦躁':
        scent = '薰衣草';
        reason =
        '根据《Aromatherapy: Therapy with Fragrances of Lavender Essential Oil》研究，薰衣草对睡眠质量、缓解焦虑和减少抑郁症有积极影响。';
        scene = '睡前使用，帮助放松身心，促进睡眠';
        break;
      case '低落':
      case '悲伤':
        scent = '大马士革玫瑰';
        reason =
        '根据《The effects of Rosa damascene aromatherapy on mood and sleep: a systematic review and meta-analysis》研究，大马士革玫瑰芳香疗法可以有效减少焦虑，改善相关的血液动力学参数，缓解压力症状。';
        scene = '情绪低落时使用，帮助提升心情';
        break;
      default:
        scent = '薰衣草';
        reason =
        '根据《Aromatherapy: Therapy with Fragrances of Lavender Essential Oil》研究，薰衣草对睡眠质量、缓解焦虑和减少抑郁症有积极影响。';
        scene = '日常使用，保持心情愉悦';
    }
    return {
      'emotion': emotion,
      'intensity': 3,
      'scent': scent,
      'reason': reason,
      'scene': scene,
    };
  }

  // ===================== 情绪识别辅助 =====================

  String _detectEmotion(String userInput) {
    if (userInput.contains('压力') ||
        userInput.contains('焦虑') ||
        userInput.contains('紧张')) {
      return '焦虑';
    } else if (userInput.contains('疲劳') ||
        userInput.contains('没精神') ||
        userInput.contains('困倦')) {
      return '疲惫';
    } else if (userInput.contains('开心') ||
        userInput.contains('愉悦') ||
        userInput.contains('高兴')) {
      return '愉悦';
    } else if (userInput.contains('烟味') ||
        userInput.contains('异味') ||
        userInput.contains('臭味')) {
      return '不适';
    } else if (userInput.contains('难过') || userInput.contains('悲伤')) {
      return '低落';
    } else if (userInput.contains('失眠') || userInput.contains('睡不着')) {
      return '困倦';
    } else if (userInput.contains('烦躁')) {
      return '焦虑';
    } else {
      return '放松';
    }
  }

  // ===================== 日志打印 =====================

  void _logAttemptStart(int retry, String userInput) {
    debugPrint('=== 讯飞API调用开始 (尝试 ${retry + 1}/${_maxRetries + 1}) ===');
    debugPrint('API Password: ${apiPassword.substring(0, 5)}...${apiPassword.substring(apiPassword.length - 5)}');
    debugPrint('Base URL: $baseUrl');
    debugPrint('Model: $modelName');
    debugPrint('User Input: $userInput');
  }

  void _logResponse(http.Response response) {
    debugPrint('请求完成，状态码: ${response.statusCode}');
    debugPrint('响应头: ${response.headers}');
    debugPrint('响应体: ${response.body}');
  }
}