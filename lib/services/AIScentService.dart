import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class AIScentService {
  final String apiKey;
  final String modelName;
  final String baseUrl;

  // 本地情绪-香氛映射表
  final Map<String, Map<String, dynamic>> _localScentMap = {
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

  AIScentService({
    required this.apiKey,
    this.modelName = 'doubao-pro-1.5',
    this.baseUrl = 'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
  });

  // 调用大模型API获取气味推荐
  Future<Map<String, dynamic>> getScentRecommendation(String userInput) async {
    try {
      // 首先尝试调用API
      final apiResult = await _fetchAPIRecommendation(userInput);
      if (apiResult['success']) {
        return apiResult;
      }
    } catch (e) {
      print('API调用失败，使用本地兜底: $e');
    }

    // API调用失败时使用本地兜底
    return _getLocalScentRecommendation(userInput);
  }

  // 请求API
  Future<Map<String, dynamic>> _fetchAPIRecommendation(String userInput) async {
    int retryCount = 0;
    const int maxRetries = 2;
    const Duration timeout = Duration(seconds: 10);

    while (retryCount <= maxRetries) {
      try {
        // 构建Prompt
        final prompt =
            '''
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

        print('=== API调用开始 (尝试 ${retryCount + 1}/${maxRetries + 1}) ===');
        print(
          'API Key: ${apiKey.substring(0, 5)}...${apiKey.substring(apiKey.length - 5)}',
        );
        print('Base URL: $baseUrl');
        print('Model: $modelName');
        print('User Input: $userInput');

        // 构建请求体
        final requestBody = {
          'model': modelName,
          'messages': [
            {'role': 'system', 'content': '你是一个专业的气味情绪推荐助手，根据用户的情绪状态推荐合适的香氛'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.9, // 提高温度，增加推荐多样性
        };

        print('Request Body: ${jsonEncode(requestBody)}');

        // 发送POST请求
        print('发送请求...');
        final response = await http
            .post(
              Uri.parse(baseUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
              body: jsonEncode(requestBody),
            )
            .timeout(timeout);

        print('请求完成，状态码: ${response.statusCode}');
        print('响应头: ${response.headers}');
        print('响应体: ${response.body}');

        // 处理响应
        if (response.statusCode == 200) {
          // 解析API响应
          try {
            final data = jsonDecode(response.body);
            print('解析API响应成功');

            if (data.containsKey('choices') && data['choices'].isNotEmpty) {
              final content = data['choices'][0]['message']['content'];
              print('模型返回内容: $content');

              // 解析返回的JSON
              try {
                final result = jsonDecode(content);
                print('解析返回数据成功: $result');
                return {'success': true, 'data': result};
              } catch (e) {
                print('解析返回数据失败: $e');
                return {'success': false, 'error': '解析返回数据失败' + e.toString()};
              }
            } else {
              print('API响应格式错误，缺少choices字段');
              return {
                'success': false,
                'error': 'API响应格式错误' + jsonEncode(data),
              };
            }
          } catch (e) {
            print('解析API响应失败: $e');
            return {'success': false, 'error': '解析API响应失败' + e.toString()};
          }
        } else if (response.statusCode == 401) {
          print('API密钥无效');
          return {
            'success': false,
            'error': 'API密钥无效' + jsonEncode(response.body),
          };
        } else if (response.statusCode >= 500) {
          print('服务器错误: ${response.statusCode}');
          return {
            'success': false,
            'error': '服务器错误' + jsonEncode(response.body),
          };
        } else {
          print('请求失败: ${response.statusCode}');
          return {
            'success': false,
            'error': '请求失败' + jsonEncode(response.body),
          };
        }
      } catch (e) {
        if (e is http.ClientException) {
          print('网络连接失败: $e');
          if (retryCount < maxRetries) {
            print('重试中...');
            retryCount++;
            await Future.delayed(Duration(seconds: 1));
            continue;
          } else {
            print('网络连接失败且重试次数耗尽');
            return {'success': false, 'error': '网络连接失败' + e.toString()};
          }
        } else if (e is TimeoutException) {
          print('请求超时: $e');
          if (retryCount < maxRetries) {
            print('重试中...');
            retryCount++;
            await Future.delayed(Duration(seconds: 1));
            continue;
          } else {
            print('请求超时且重试次数耗尽');
            return {'success': false, 'error': '请求超时' + e.toString()};
          }
        } else {
          print('未知错误: $e');
          return {'success': false, 'error': '未知错误' + e.toString()};
        }
      } finally {
        print('=== API调用结束 ===');
      }
    }

    return {'success': false, 'error': '所有尝试失败' + jsonEncode('')};
  }

  // 使用本地映射表获取气味推荐
  Map<String, dynamic> _getLocalScentRecommendation(String userInput) {
    print('使用本地兜底逻辑获取气味推荐');

    // 更精确的关键词匹配
    // 压力焦虑类
    if (userInput.contains('压力') ||
        userInput.contains('焦虑') ||
        userInput.contains('紧张')) {
      print('匹配到压力焦虑类');
      if (userInput.contains('焦虑')) {
        return {'success': true, 'data': _localScentMap['焦虑']!};
      } else if (userInput.contains('紧张')) {
        return {'success': true, 'data': _localScentMap['紧张']!};
      } else {
        return {'success': true, 'data': _localScentMap['压力']!};
      }
    }
    // 疲惫提神类
    else if (userInput.contains('疲劳') ||
        userInput.contains('没精神') ||
        userInput.contains('困倦') ||
        userInput.contains('疲惫')) {
      print('匹配到疲惫提神类');
      if (userInput.contains('没精神')) {
        return {'success': true, 'data': _localScentMap['没精神']!};
      } else if (userInput.contains('困倦')) {
        return {'success': true, 'data': _localScentMap['困倦']!};
      } else {
        return {'success': true, 'data': _localScentMap['疲劳']!};
      }
    }
    // 愉悦开心类
    else if (userInput.contains('开心') ||
        userInput.contains('愉悦') ||
        userInput.contains('高兴')) {
      print('匹配到愉悦开心类');
      if (userInput.contains('愉悦')) {
        return {'success': true, 'data': _localScentMap['愉悦']!};
      } else {
        return {'success': true, 'data': _localScentMap['开心']!};
      }
    }
    // 异味净化类
    else if (userInput.contains('烟味') ||
        userInput.contains('异味') ||
        userInput.contains('臭味')) {
      print('匹配到异味净化类');
      if (userInput.contains('烟味')) {
        return {'success': true, 'data': _localScentMap['烟味']!};
      } else if (userInput.contains('臭味')) {
        return {'success': true, 'data': _localScentMap['臭味']!};
      } else {
        return {'success': true, 'data': _localScentMap['异味']!};
      }
    }
    // 其他场景
    else if (userInput.contains('难过') || userInput.contains('悲伤')) {
      print('匹配到难过类');
      return {'success': true, 'data': _localScentMap['难过']!};
    } else if (userInput.contains('失眠') || userInput.contains('睡不着')) {
      print('匹配到失眠类');
      return {'success': true, 'data': _localScentMap['失眠']!};
    } else if (userInput.contains('烦躁') || userInput.contains('烦躁')) {
      print('匹配到烦躁类');
      return {'success': true, 'data': _localScentMap['烦躁']!};
    }

    // 默认返回薰衣草
    print('未匹配到本地情绪，使用默认推荐');
    return {
      'success': true,
      'data': {
        'emotion': '放松',
        'intensity': 3,
        'scent': '薰衣草',
        'reason': '薰衣草的香气有助于放松身心，缓解各种不良情绪',
        'scene': '愉悦治愈场景',
      },
    };
  }
}
