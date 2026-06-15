import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// AI 气味推荐服务（豆包大模型 + 本地兜底）
class AIScentService {
  final String apiKey;
  final String modelName;
  final String baseUrl;

  // ========== 本地情绪-香氛映射表 ==========
  static const Map<String, Map<String, dynamic>> _localScentMap = {
    // 压力焦虑类
    '压力': {
      'emotion': '焦虑',
      'intensity': 4,
      'scent': '薰衣草',
      'reason': '薰衣草的香气有助于缓解压力，带来平静感',
      'scene': '愉悦治愈场景',
    },
    '焦虑': {
      'emotion': '焦虑',
      'intensity': 4,
      'scent': '洋甘菊',
      'reason': '洋甘菊的香气能够安抚焦虑情绪，带来宁静',
      'scene': '助眠安神场景',
    },
    '紧张': {
      'emotion': '焦虑',
      'intensity': 4,
      'scent': '薰衣草',
      'reason': '薰衣草的香气有助于缓解紧张情绪，放松身心',
      'scene': '愉悦治愈场景',
    },

    // 疲惫提神类
    '疲劳': {
      'emotion': '疲惫',
      'intensity': 5,
      'scent': '薄荷',
      'reason': '薄荷的清新香气能够提神醒脑，缓解疲劳',
      'scene': '疲惫舒缓场景',
    },
    '没精神': {
      'emotion': '疲惫',
      'intensity': 4,
      'scent': '迷迭香',
      'reason': '迷迭香的香气能够提神醒脑，增强注意力',
      'scene': '提神醒脑场景',
    },
    '困倦': {
      'emotion': '困倦',
      'intensity': 4,
      'scent': '柠檬',
      'reason': '柠檬的清新香气能够提神醒脑，缓解困倦',
      'scene': '提神醒脑场景',
    },

    // 愉悦开心类
    '开心': {
      'emotion': '愉悦',
      'intensity': 3,
      'scent': '甜橙',
      'reason': '甜橙的果香能够增强愉悦感，提升心情',
      'scene': '愉悦治愈场景',
    },
    '愉悦': {
      'emotion': '愉悦',
      'intensity': 3,
      'scent': '佛手柑',
      'reason': '佛手柑的香气能够提升心情，带来愉悦感',
      'scene': '愉悦治愈场景',
    },

    // 异味净化类
    '烟味': {
      'emotion': '不适',
      'intensity': 4,
      'scent': '柠檬',
      'reason': '柠檬的香气能够净化空气，去除烟味',
      'scene': '疲惫舒缓场景',
    },
    '异味': {
      'emotion': '不适',
      'intensity': 4,
      'scent': '茶树',
      'reason': '茶树的香气能够净化空气，去除异味',
      'scene': '疲惫舒缓场景',
    },
    '臭味': {
      'emotion': '不适',
      'intensity': 5,
      'scent': '尤加利',
      'reason': '尤加利的香气能够净化空气，去除臭味',
      'scene': '疲惫舒缓场景',
    },

    // 其他场景
    '难过': {
      'emotion': '低落',
      'intensity': 4,
      'scent': '薰衣草',
      'reason': '薰衣草的香气有助于缓解悲伤情绪，带来平静感',
      'scene': '愉悦治愈场景',
    },
    '失眠': {
      'emotion': '困倦',
      'intensity': 5,
      'scent': '薰衣草',
      'reason': '薰衣草的香气有助于放松身心，促进睡眠',
      'scene': '助眠安神场景',
    },
    '烦躁': {
      'emotion': '焦虑',
      'intensity': 4,
      'scent': '柠檬',
      'reason': '柠檬的清新香气能够舒缓烦躁情绪，带来清爽感',
      'scene': '愉悦治愈场景',
    },
  };

  // ========== 默认推荐（关键词未命中时使用） ==========
  static const Map<String, dynamic> _defaultRecommendation = {
    'emotion': '放松',
    'intensity': 3,
    'scent': '薰衣草',
    'reason': '薰衣草的香气有助于放松身心，缓解各种不良情绪',
    'scene': '愉悦治愈场景',
  };

  // ========== 网络重试常量 ==========
  static const int _maxRetries = 2;
  static const Duration _timeout = Duration(seconds: 10);
  static const Duration _retryDelay = Duration(seconds: 1);

  AIScentService({
    required this.apiKey,
    this.modelName = 'doubao-pro-1.5',
    this.baseUrl = 'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
  });

  /// 获取气味推荐（优先调用 API，失败则使用本地兜底）
  Future<Map<String, dynamic>> getScentRecommendation(String userInput) async {
    try {
      final apiResult = await _fetchAPIRecommendation(userInput);
      if (apiResult['success'] == true) {
        return apiResult;
      }
    } catch (e) {
      debugPrint('API调用失败，使用本地兜底: $e');
    }
    return _getLocalScentRecommendation(userInput);
  }

  /// 带重试机制的 API 调用
  Future<Map<String, dynamic>> _fetchAPIRecommendation(String userInput) async {
    int retryCount = 0;

    while (retryCount <= _maxRetries) {
      try {
        _logApiStart(retryCount);

        final prompt = _buildPrompt(userInput);
        final response = await http
            .post(
          Uri.parse(baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': modelName,
            'messages': [
              {'role': 'system', 'content': '你是一个专业的气味情绪推荐助手，根据用户的情绪状态推荐合适的香氛'},
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.9,
          }),
        )
            .timeout(_timeout);

        _logResponse(response);

        if (response.statusCode == 200) {
          return _parseSuccessResponse(response.body);
        } else {
          return _buildErrorResponse(response);
        }
      } on http.ClientException catch (e) {
        debugPrint('网络连接失败: $e');
        if (retryCount < _maxRetries) {
          retryCount++;
          await Future.delayed(_retryDelay);
          continue;
        }
        return {'success': false, 'error': '网络连接失败$e'};
      } on TimeoutException catch (e) {
        debugPrint('请求超时: $e');
        if (retryCount < _maxRetries) {
          retryCount++;
          await Future.delayed(_retryDelay);
          continue;
        }
        return {'success': false, 'error': '请求超时$e'};
      } catch (e) {
        debugPrint('未知错误: $e');
        return {'success': false, 'error': '未知错误$e'};
      }
    }

    return {'success': false, 'error': '所有尝试失败'};
  }

  String _buildPrompt(String userInput) {
    return '''
你是气味情绪推荐助手，我们有四种气味应用场景：疲惫舒缓场景（下班劳累、精神紧绷、身心疲惫）、愉悦治愈场景（调节心情低落、烦躁、emo、情绪不佳之类情绪）、助眠安神场景（失眠、入睡困难、熬夜焦虑）、提神醒脑场景（犯困、注意力不集中、居家办公低效）

用户输入：$userInput
请只输出JSON格式，不要其他文字：
{
  "emotion": "情绪标签（疲惫/焦虑/愉悦/困倦/放松/低落/不适）",
  "intensity": 强度1-5,
  "scent": "推荐气味（薰衣草/甜橙/迷迭香/柠檬/茉莉/檀香/薄荷/洋甘菊/佛手柑/茶树/尤加利）",
  "reason": "推荐理由（一句话）",
  "scene": "适用场景"
}
''';
  }

  Map<String, dynamic> _parseSuccessResponse(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (data.containsKey('choices') && (data['choices'] as List).isNotEmpty) {
        final content = data['choices'][0]['message']['content'] as String;
        debugPrint('模型返回内容: $content');

        try {
          final result = jsonDecode(content) as Map<String, dynamic>;
          debugPrint('解析返回数据成功: $result');
          return {'success': true, 'data': result};
        } catch (e) {
          debugPrint('解析返回数据失败: $e');
          return {'success': false, 'error': '解析返回数据失败$e'};
        }
      } else {
        debugPrint('API响应格式错误，缺少choices字段');
        return {'success': false, 'error': 'API响应格式错误${body}'};
      }
    } catch (e) {
      debugPrint('解析API响应失败: $e');
      return {'success': false, 'error': '解析API响应失败$e'};
    }
  }

  Map<String, dynamic> _buildErrorResponse(http.Response response) {
    final statusCode = response.statusCode;
    final body = response.body;

    if (statusCode == 401) {
      debugPrint('API密钥无效');
      return {'success': false, 'error': 'API密钥无效$body'};
    } else if (statusCode >= 500) {
      debugPrint('服务器错误: $statusCode');
      return {'success': false, 'error': '服务器错误$body'};
    } else {
      debugPrint('请求失败: $statusCode');
      return {'success': false, 'error': '请求失败$body'};
    }
  }

  void _logApiStart(int retryCount) {
    debugPrint('=== API调用开始 (尝试 ${retryCount + 1}/${_maxRetries + 1}) ===');
    debugPrint('API Key: ${apiKey.substring(0, 5)}...${apiKey.substring(apiKey.length - 5)}');
    debugPrint('Base URL: $baseUrl');
    debugPrint('Model: $modelName');
  }

  void _logResponse(http.Response response) {
    debugPrint('请求完成，状态码: ${response.statusCode}');
    debugPrint('响应头: ${response.headers}');
    debugPrint('响应体: ${response.body}');
  }

  // ========== 本地关键词匹配 ==========

  Map<String, dynamic> _getLocalScentRecommendation(String userInput) {
    debugPrint('使用本地兜底逻辑获取气味推荐');

    // 按优先级匹配
    final matched = _matchKeywordGroup(userInput, [
      ['压力', '焦虑', '紧张'],
      ['疲劳', '没精神', '困倦', '疲惫'],
      ['开心', '愉悦', '高兴'],
      ['烟味', '异味', '臭味'],
      ['难过', '悲伤'],
      ['失眠', '睡不着'],
      ['烦躁'],
    ]);

    if (matched != null) {
      return {'success': true, 'data': matched};
    }

    debugPrint('未匹配到本地情绪，使用默认推荐');
    return {'success': true, 'data': _defaultRecommendation};
  }

  /// 根据关键词组从本地映射中获取最精确的匹配项
  Map<String, dynamic>? _matchKeywordGroup(
      String input,
      List<List<String>> groups,
      ) {
    for (final group in groups) {
      for (final keyword in group) {
        if (input.contains(keyword)) {
          // 返回该组第一个命中关键词对应的映射（优先级已在映射表中定义）
          // 但这里需要保证映射表中的键与关键词一致
          final matchedKey = group.firstWhere(
                (k) => _localScentMap.containsKey(k),
            orElse: () => group.first,
          );
          return _localScentMap[matchedKey];
        }
      }
    }
    return null;
  }
}