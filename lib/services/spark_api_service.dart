import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;

/// 香氛数据模型
class ScentData {
  final String name;
  final String paperTitle;
  final String conclusion;
  final List<String> applicableEmotions;

  ScentData({
    required this.name,
    required this.paperTitle,
    required this.conclusion,
    required this.applicableEmotions,
  });
}

class SparkApiService {
  final String apiPassword;
  final String modelName;
  final String baseUrl;

  // 官方气味库 - 4种核心精油
  final List<ScentData> _officialScents = [
    ScentData(
      name: "大马士革玫瑰",
      paperTitle:
          "The effects of Rosa damascene aromatherapy on mood and sleep: a systematic review and meta-analysis",
      conclusion: "RD芳香疗法可以有效减少焦虑，改善相关的血液动力学参数，缓解压力症状，同时还能提高睡眠质量",
      applicableEmotions: ["焦虑", "压力", "失眠", "情绪低落"],
    ),
    ScentData(
      name: "薰衣草",
      paperTitle:
          "Aromatherapy: Therapy with Fragrances of Lavender Essential Oil",
      conclusion:
          "薰衣草对睡眠质量、缓解焦虑和减少抑郁症有积极影响。它还具有认知能力，并影响逐渐缓解疼痛；因此，它作为替代或辅助疗法，在牙科、术前治疗、产科、烧伤和癌症患者中显示出巨大的应用潜力。",
      applicableEmotions: ["焦虑", "失眠", "抑郁", "疼痛", "压力"],
    ),
    ScentData(
      name: "苦橙",
      paperTitle:
          "Effect of Citrus x aurantium L. Aromatherapy on Anxiety: A Systematic Review and Meta-Analysis",
      conclusion:
          "苦橙精油/橙花油干预组的焦虑水平显著降低，均值差为-12.45 (95% CI: -20.90至-3.99, p = 0.004)。因此，吸入苦橙精油和橙花油是有效降低焦虑水平的芳香疗法手段。",
      applicableEmotions: ["焦虑", "压力", "紧张"],
    ),
    ScentData(
      name: "柠檬",
      paperTitle:
          "Olfactory influences on mood and autonomic, endocrine, and immune function",
      conclusion:
          "柠檬气味在缓解压力时可能可靠地提升积极情绪，该效应独立于被试的预期。研究表明，嗅觉刺激可通过情绪调节通路影响自主神经、内分泌和免疫系统的功能状态，为气味-情绪-生理系统的整合提供了跨系统的实证证据。",
      applicableEmotions: ["疲惫", "压力", "焦虑", "低落"],
    ),
  ];

  // 本地情绪-香氛映射表（更新为使用核心精油）
  final Map<String, Map<String, dynamic>> _localScentMap = {
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

  // 生成Bearer Token
  String _generateAuthorization() {
    return 'Bearer $apiPassword';
  }

  // 调用大模型API获取气味推荐
  Future<Map<String, dynamic>> getScentRecommendation(String userInput) async {
    int retryCount = 0;
    const int maxRetries = 2;
    const Duration timeout = Duration(seconds: 30);

    while (retryCount <= maxRetries) {
      try {
        print('=== 讯飞API调用开始 (尝试 ${retryCount + 1}/${maxRetries + 1}) ===');
        print(
          'API Password: ${apiPassword.substring(0, 5)}...${apiPassword.substring(apiPassword.length - 5)}',
        );
        print('Base URL: $baseUrl');
        print('Model: $modelName');
        print('User Input: $userInput');

        // 构建请求体，完全对齐curl格式
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

        print('Request Body: ${jsonEncode(requestBody)}');

        // 生成Authorization
        final authorization = _generateAuthorization();
        print('Authorization: $authorization');

        // 构建请求头
        final headers = {
          'Content-Type': 'application/json',
          'Authorization': authorization,
        };
        print('Request Headers: $headers');

        // 打印curl命令格式，方便对比
        print('\n=== 等效curl命令 ===');
        print(
          'curl -X POST "$baseUrl" \\n  -H "Content-Type: application/json" \\n  -H "Authorization: $authorization" \\n  -d "${jsonEncode(requestBody)}"',
        );
        print('====================\n');

        // 发送POST请求
        print('发送请求...');
        final response = await http
            .post(
              Uri.parse(baseUrl),
              headers: headers,
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
              print('模型返回原始内容: $content');

              // 格式清洗逻辑
              String cleanedContent = content;
              // 去除Markdown代码块标记
              cleanedContent = cleanedContent
                  .replaceAll('```json', '')
                  .replaceAll('```', '');
              // 去除反引号
              cleanedContent = cleanedContent.replaceAll('`', '');
              // 去除首尾空白字符和换行符
              cleanedContent = cleanedContent.trim();
              print('清洗后的内容: $cleanedContent');

              // 解析模型返回的JSON
              try {
                final result = jsonDecode(cleanedContent);
                print('解析返回数据成功: $result');
                // 验证返回数据是否包含所有必要字段
                if (result.containsKey('emotion') &&
                    result.containsKey('intensity') &&
                    result.containsKey('scent') &&
                    result.containsKey('reason') &&
                    result.containsKey('scene')) {
                  // 直接使用API返回的结果，不做重复检查
                  final recommendedScent = result['scent'];
                  print('推荐的气味: $recommendedScent');
                  print('最终展示内容: $result');
                  return {'success': true, 'data': result};
                } else {
                  print('API返回数据缺少必要字段，使用本地兜底');
                  return _getLocalScentRecommendation(userInput);
                }
              } catch (e) {
                print('解析返回数据失败: $e');
                // 解析失败时使用本地兜底
                return _getLocalScentRecommendation(userInput);
              }
            } else {
              print('API响应格式错误，缺少choices字段');
              // 响应格式错误时使用本地兜底
              return _getLocalScentRecommendation(userInput);
            }
          } catch (e) {
            print('解析API响应失败: $e');
            // 解析失败时使用本地兜底
            return _getLocalScentRecommendation(userInput);
          }
        } else if (response.statusCode == 401) {
          print('API密钥无效');
          // API密钥无效时使用本地兜底
          return _getLocalScentRecommendation(userInput);
        } else if (response.statusCode >= 500) {
          print('服务器错误: ${response.statusCode}');
          // 服务器错误时使用本地兜底
          return _getLocalScentRecommendation(userInput);
        } else {
          print('请求失败: ${response.statusCode}');
          // 请求失败时使用本地兜底
          return _getLocalScentRecommendation(userInput);
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
            // 网络连接失败且重试次数耗尽时使用本地兜底
            return _getLocalScentRecommendation(userInput);
          }
        } else if (e is TimeoutException) {
          print('请求超时: $e');
          if (retryCount < maxRetries) {
            print('重试中...');
            retryCount++;
            await Future.delayed(Duration(seconds: 1));
            continue;
          } else {
            // 请求超时且重试次数耗尽时使用本地兜底
            return _getLocalScentRecommendation(userInput);
          }
        } else {
          print('未知错误: $e');
          // 未知错误时使用本地兜底
          return _getLocalScentRecommendation(userInput);
        }
      } finally {
        print('=== API调用结束 ===');
      }
    }

    // 所有尝试失败后使用本地兜底
    return _getLocalScentRecommendation(userInput);
  }

  // 检测情绪
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
    } else if (userInput.contains('烦躁') || userInput.contains('烦躁')) {
      return '焦虑';
    } else {
      return '放松';
    }
  }

  // 根据情绪获取推荐气味
  String _getScentForEmotion(String emotion) {
    switch (emotion) {
      case '焦虑':
        return '薰衣草';
      case '疲惫':
        return '薄荷';
      case '愉悦':
        return '甜橙';
      case '不适':
        return '柠檬';
      case '低落':
        return '薰衣草';
      case '困倦':
        return '薰衣草';
      default:
        return '薰衣草';
    }
  }

  // 根据情绪获取适用场景
  String _getSceneForEmotion(String emotion) {
    switch (emotion) {
      case '焦虑':
        return '愉悦治愈场景';
      case '疲惫':
        return '疲惫舒缓场景';
      case '愉悦':
        return '愉悦治愈场景';
      case '不适':
        return '疲惫舒缓场景';
      case '低落':
        return '愉悦治愈场景';
      case '困倦':
        return '助眠安神场景';
      default:
        return '愉悦治愈场景';
    }
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

    // 根据情绪类型返回不同的默认气味
    print('未匹配到本地情绪，使用默认推荐');
    final detectedEmotion = _detectEmotion(userInput);
    String defaultScent;
    String defaultReason;
    String defaultScene;

    switch (detectedEmotion) {
      case '疲惫':
      case '困倦':
        // 提神类
        defaultScent = '柠檬';
        defaultReason =
            '根据《Olfactory influences on mood and autonomic, endocrine, and immune function》研究，柠檬气味在缓解压力时可能可靠地提升积极情绪。';
        defaultScene = '工作或学习时使用，提升注意力和精神状态';
        break;
      case '焦虑':
      case '紧张':
      case '压力':
      case '烦躁':
        // 助眠/放松类
        defaultScent = '薰衣草';
        defaultReason =
            '根据《Aromatherapy: Therapy with Fragrances of Lavender Essential Oil》研究，薰衣草对睡眠质量、缓解焦虑和减少抑郁症有积极影响。';
        defaultScene = '睡前使用，帮助放松身心，促进睡眠';
        break;
      case '低落':
      case '悲伤':
        // 愉悦/提振类
        defaultScent = '大马士革玫瑰';
        defaultReason =
            '根据《The effects of Rosa damascene aromatherapy on mood and sleep: a systematic review and meta-analysis》研究，大马士革玫瑰芳香疗法可以有效减少焦虑，改善相关的血液动力学参数，缓解压力症状。';
        defaultScene = '情绪低落时使用，帮助提升心情';
        break;
      default:
        // 其他情绪
        defaultScent = '薰衣草';
        defaultReason =
            '根据《Aromatherapy: Therapy with Fragrances of Lavender Essential Oil》研究，薰衣草对睡眠质量、缓解焦虑和减少抑郁症有积极影响。';
        defaultScene = '日常使用，保持心情愉悦';
    }

    return {
      'success': true,
      'data': {
        'emotion': detectedEmotion,
        'intensity': 3,
        'scent': defaultScent,
        'reason': defaultReason,
        'scene': defaultScene,
      },
    };
  }
}
