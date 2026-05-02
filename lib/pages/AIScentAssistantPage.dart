import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';
import '../models/ScentMemory.dart';
import '../services/ScentMemoryService.dart';
import '../services/spark_api_service.dart';
import '../database/database_helper.dart';
import 'ScentMemoryPage.dart';

class AIScentAssistantPage extends StatefulWidget {
  const AIScentAssistantPage({super.key});

  @override
  State<AIScentAssistantPage> createState() => _AIScentAssistantPageState();
}

class _AIScentAssistantPageState extends State<AIScentAssistantPage> {
  // 聊天消息列表
  final List<Map<String, dynamic>> _messages = [];
  // 输入控制器
  final TextEditingController _textController = TextEditingController();
  // 是否正在加载
  bool _isLoading = false;
  // 气味记忆服务
  final ScentMemoryService _memoryService = ScentMemoryService();
  // AI气味服务
  late SparkApiService _aiService;
  // UUID生成器
  final Uuid _uuid = Uuid();
  // 滚动控制器
  final ScrollController _scrollController = ScrollController();

  // 语音转文字相关
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _transcription = '';
  bool _speechInitialized = false;
  // 平台检测
  bool _isWindows = Platform.isWindows;

  @override
  void initState() {
    super.initState();
    // 初始化气味记忆服务
    _memoryService.init();
    // 初始化AI气味服务
    _aiService = SparkApiService(
      apiPassword: 'GCurjaQCPjWKlJLXUriC:ROflhklEyofwdBnBWyBV',
      modelName: 'lite',
      baseUrl: 'https://spark-api-open.xf-yun.com/v1/chat/completions',
    );
    // 加载历史聊天记录
    _loadChatHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 加载历史聊天记录
  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('ai_chat_history');
      if (historyJson != null) {
        final List<dynamic> history = json.decode(historyJson);
        setState(() {
          _messages.addAll(history.cast<Map<String, dynamic>>());
        });
        // 滚动到底部
        _scrollToBottom();
      }
    } catch (e) {
      print('加载聊天记录失败: $e');
    }
  }

  /// 保存聊天记录到本地
  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 只保存最近100条消息，避免数据过大
      final messagesToSave = _messages.length > 100
          ? _messages.sublist(_messages.length - 100)
          : _messages;
      await prefs.setString('ai_chat_history', json.encode(messagesToSave));
    } catch (e) {
      print('保存聊天记录失败: $e');
    }
  }

  /// 清空聊天记录
  Future<void> _clearChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ai_chat_history');
      setState(() {
        _messages.clear();
      });
    } catch (e) {
      print('清空聊天记录失败: $e');
    }
  }

  /// 滚动到底部
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  // 初始化语音转文字
  Future<bool> _initSpeech() async {
    _speech = stt.SpeechToText();
    try {
      _speechInitialized = await _speech.initialize(
        onStatus: (status) {
          print('语音识别状态: $status');
          if (status == 'done') {
            _stopListening();
          }
        },
        onError: (error) {
          print('语音识别错误: $error');
          _stopListening();
        },
      );
      return _speechInitialized;
    } catch (e) {
      print('语音初始化错误: $e');
      return false;
    }
  }

  // 情绪关键词映射表（语义识别增强）
  final Map<String, List<String>> _emotionKeywords = {
    '疲惫': ['疲惫', '累', '困', '没精神', '乏力', '疲倦', '劳累', '精疲力尽'],
    '焦虑': ['焦虑', '紧张', '烦躁', '压力大', '不安', '担心', '着急', '心慌'],
    '低落': ['伤心', '难过', '想哭', '低落', '沮丧', '郁闷', '失落', '痛苦', '悲伤'],
    '失眠': ['睡不着', '失眠', '难入睡', '睡不好', '熬夜', '多梦', '早醒'],
    '放松': ['放松', '舒服', '平静', '惬意', '安逸', '宁静', '轻松', '自在'],
  };

  // 语义识别情绪
  String _detectEmotion(String text) {
    text = text.toLowerCase();
    for (final entry in _emotionKeywords.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          return entry.key;
        }
      }
    }
    return ''; // 未命中关键词，返回空让AI判断
  }

  // 生成用户画像
  Future<String> _generateUserProfile() async {
    try {
      // 获取所有气味记忆
      final memories = await _memoryService.getAllMemories();
      if (memories.isEmpty) {
        return '';
      }

      // 统计高频情绪
      final emotionCount = <String, int>{};
      // 统计高频气味
      final scentCount = <String, int>{};
      // 统计高频场景
      final sceneCount = <String, int>{};
      // 收集最近记录
      final recentMemories = memories.take(5).toList();

      for (final memory in memories) {
        // 统计情绪
        final emotion = memory.emotion;
        if (emotion.isNotEmpty) {
          emotionCount[emotion] = (emotionCount[emotion] ?? 0) + 1;
        }
        // 统计气味
        final scent = memory.scent;
        if (scent.isNotEmpty) {
          scentCount[scent] = (scentCount[scent] ?? 0) + 1;
        }
        // 从用户输入中提取场景关键词
        final userInput = memory.userInput;
        if (userInput.contains('睡前') || userInput.contains('睡觉')) {
          sceneCount['睡前'] = (sceneCount['睡前'] ?? 0) + 1;
        }
        if (userInput.contains('作业') || userInput.contains('学习')) {
          sceneCount['写作业'] = (sceneCount['写作业'] ?? 0) + 1;
        }
        if (userInput.contains('午休') || userInput.contains('午睡')) {
          sceneCount['午休'] = (sceneCount['午休'] ?? 0) + 1;
        }
        if (userInput.contains('工作') || userInput.contains('办公')) {
          sceneCount['工作'] = (sceneCount['工作'] ?? 0) + 1;
        }
      }

      // 排序获取高频项
      final topEmotions = emotionCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topScents = scentCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topScenes = sceneCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // 构建用户画像字符串
      final buffer = StringBuffer();
      buffer.writeln('【用户画像】');
      buffer.writeln('- 气味记忆总数：${memories.length} 条');

      if (topEmotions.isNotEmpty) {
        final emotionStr = topEmotions
            .take(3)
            .map((e) => '${e.key}(${e.value}次)')
            .join('、');
        buffer.writeln('- 高频情绪：$emotionStr');
      }

      if (topScents.isNotEmpty) {
        final scentStr = topScents
            .take(3)
            .map((e) => '${e.key}(${e.value}次)')
            .join('、');
        buffer.writeln('- 高频气味：$scentStr');
      }

      if (topScenes.isNotEmpty) {
        final sceneStr = topScenes.take(3).map((e) => e.key).join('、');
        buffer.writeln('- 常用场景：$sceneStr');
      }

      // 分析最近偏好
      if (recentMemories.isNotEmpty) {
        final recentScents = recentMemories
            .map((m) => m.scent)
            .where((s) => s.isNotEmpty)
            .toList();
        if (recentScents.isNotEmpty) {
          buffer.writeln('- 最近偏好：${recentScents.take(3).join('、')}');
        }
      }

      return buffer.toString();
    } catch (e) {
      print('生成用户画像失败: $e');
      return '';
    }
  }

  // 发送消息
  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // 添加用户消息到列表
    setState(() {
      _messages.add({'type': 'user', 'text': text});
      _textController.clear();
      _isLoading = true;
    });

    // 保存聊天记录
    await _saveChatHistory();
    // 滚动到底部
    _scrollToBottom();

    try {
      print('开始调用AI API，用户输入: $text');

      // 【新增】语义识别情绪
      final detectedEmotion = _detectEmotion(text);
      print('语义识别情绪: $detectedEmotion');

      // 【新增】生成用户画像
      final userProfile = await _generateUserProfile();
      print('用户画像: $userProfile');

      // 【新增】构建系统提示词
      final systemPrompt = '''你是APP专属「气味疗愈助手」，**必须严格按以下 4 步回复**，并结合用户画像做个性化推荐：

1. 情绪识别：根据用户输入，精准识别情绪（疲惫/焦虑/低落/失眠/放松）
2. 气味推荐：优先推荐用户历史高频气味，其次匹配情绪功效；必须给出 1-2 种具体香气+功效
3. 场景匹配：结合用户常用场景，给出具体使用建议
4. 设备适配：优先推荐设备可用香氛；结尾提示可保存到气味记忆

回复格式：
【情绪识别】xxx
【气味推荐】xxx（功效：xxx）
【场景建议】xxx
【使用指引】xxx''';

      // 【新增】拼接完整prompt
      final fullPrompt =
          '''$systemPrompt

$userProfile

用户当前输入：$text
${detectedEmotion.isNotEmpty ? '（用户情绪关键词命中：$detectedEmotion）' : ''}''';

      print('完整Prompt: $fullPrompt');

      // 【修改】调用大模型API，传入完整prompt
      final result = await _aiService.getScentRecommendation(fullPrompt);
      print('API调用结果: $result');

      if (result['success']) {
        // 根据模式处理推荐结果
        _handleRecommendation(result['data']);
      } else {
        // 处理API错误
        setState(() {
          _messages.add({'type': 'ai', 'error': result['error']});
          _isLoading = false;
        });
        await _saveChatHistory();
        _scrollToBottom();
      }
    } catch (error) {
      // 处理异常
      print('API调用异常: $error');
      setState(() {
        _messages.add({'type': 'ai', 'error': '抱歉，无法获取推荐，请稍后重试'});
        _isLoading = false;
      });
      await _saveChatHistory();
      _scrollToBottom();
    }
  }

  // 处理推荐结果
  void _handleRecommendation(Map<String, dynamic> data) {
    // 添加AI回复到列表
    setState(() {
      _messages.add({'type': 'ai', 'data': data});
      _isLoading = false;
    });

    // 保存聊天记录
    _saveChatHistory();
    // 滚动到底部
    _scrollToBottom();
    // 保存到气味记忆库
    _saveMemory(data);
  }

  // 保存记忆
  void _saveMemory(Map<String, dynamic> data) {
    try {
      final memory = ScentMemory(
        id: _uuid.v4(),
        userInput: _messages.last['text'] ?? '',
        emotion: data['emotion'] ?? '',
        scent: data['scent'] ?? '',
        timestamp: DateTime.now(),
      );
      _memoryService.saveMemory(memory);
    } catch (e) {
      print('保存记忆失败: $e');
      // 保存失败不影响成功结果的显示
    }
  }

  // 开始语音识别
  void _startListening() async {
    if (!_speechInitialized) {
      // 重新初始化
      await _initSpeech();
      if (!_speechInitialized) {
        print('语音初始化失败，请检查麦克风权限');
        return;
      }
    }

    setState(() {
      _isListening = true;
      _transcription = '';
    });

    try {
      // 开始录音
      bool started = await _speech.listen(
        onResult: (result) {
          setState(() {
            _transcription = result.recognizedWords;
            // 当识别完成时，自动停止
            if (result.finalResult) {
              _stopListening();
            }
          });
        },
        localeId: 'zh_CN', // 设置为中文
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      );

      if (!started) {
        throw Exception('无法开始录音');
      }
    } catch (e) {
      print('开始录音错误: $e');
      _stopListening();
    }
  }

  // 停止语音识别
  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
      // 将识别结果填入输入框
      if (_transcription.isNotEmpty) {
        _textController.text = _transcription;
        // 自动触发发送按钮
        _sendMessage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 不设置appBar，因为外层AIScentAssistantPageWrapper已经有返回功能了
      body: SafeArea(
        child: Column(
          children: [
            // 顶部标题栏（替代AppBar）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 返回按钮
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  // 标题
                  const Expanded(
                    child: Text(
                      'AI气味记忆助手',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // 清空聊天记录按钮
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('清空聊天记录'),
                          content: const Text('确定要清空所有聊天记录吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () {
                                _clearChatHistory();
                                Navigator.pop(context);
                              },
                              child: const Text('确定'),
                            ),
                          ],
                        ),
                      );
                    },
                    tooltip: '清空聊天记录',
                  ),
                  // 气味记忆入口
                  IconButton(
                    icon: const Icon(Icons.memory),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScentMemoryPage(),
                        ),
                      );
                    },
                    tooltip: '我的气味记忆',
                  ),
                ],
              ),
            ),

            // 聊天消息列表
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  if (message['type'] == 'user') {
                    // 用户消息
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          message['text'],
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    );
                  } else {
                    // AI消息
                    if (message.containsKey('error')) {
                      // 错误消息
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            message['error'],
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      );
                    } else {
                      // 正常AI回复
                      final data = message['data'];
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (data.containsKey('emotion'))
                                Text(
                                  '情绪: ${data['emotion']}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (data.containsKey('emotion'))
                                const SizedBox(height: 4),
                              Text(
                                '推荐气味: ${data['scent']}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (data.containsKey('effect'))
                                Text(
                                  '功效: ${data['effect']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              if (data.containsKey('effect'))
                                const SizedBox(height: 4),
                              if (data.containsKey('category'))
                                Text(
                                  '香气风格: ${data['category']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              if (data.containsKey('category'))
                                const SizedBox(height: 4),
                              if (data.containsKey('reason'))
                                Text(
                                  '推荐理由: ${data['reason']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              if (data.containsKey('reason'))
                                const SizedBox(height: 4),
                              if (data.containsKey('scene'))
                                Text(
                                  '适用场景: ${data['scene']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              const SizedBox(height: 8),
                              Text(
                                data['deviceAvailable'] == true
                                    ? '该香氛设备已支持，可直接保存到气味记忆并控制释放'
                                    : '注：本香氛为市面常见精油推荐，当前设备暂不支持，仅作情绪参考与种草',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: data['deviceAvailable'] == true
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () {
                                  // 保存到气味记忆
                                  _saveToMemory(data);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                ),
                                child: const Text('保存到气味记忆'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ),

            // 加载中指示器
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            // 正在聆听提示
            if (_isListening)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('正在聆听...', style: TextStyle(color: Colors.blue)),
              ),

            // 输入框和发送按钮
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: '请输入你的情绪状态...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                      ),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 语音转文字按钮 - 仅在非Windows平台显示
                  if (!_isWindows)
                    ElevatedButton(
                      onPressed: _isListening
                          ? _stopListening
                          : _startListening,
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(16),
                        backgroundColor: _isListening
                            ? Colors.red
                            : Colors.blue,
                      ),
                      child: _isListening
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.mic, color: Colors.white),
                    ),
                  const SizedBox(width: 8),
                  // 发送按钮
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendMessage,
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.green,
                    ),
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 保存到气味记忆
  void _saveToMemory(Map<String, dynamic> data) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // 查找用户输入
      String userInput = '';
      for (int i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i]['type'] == 'user') {
          userInput = _messages[i]['text'] ?? '';
          break;
        }
      }

      await db.insert('scent_memories', {
        'id': _uuid.v4(),
        'user_input': userInput,
        'emotion': data['emotion'] ?? '',
        'scent': data['scent'] ?? '',
        'effect': data['effect'] ?? '',
        'reason': data['reason'] ?? '',
        'scene': data['scene'] ?? '',
        'timestamp': DateTime.now().toIso8601String(),
        'device_available': data['deviceAvailable'] == true ? 1 : 0,
      });

      // 显示成功提示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存到气味记忆')));
    } catch (e) {
      print('保存到记忆库失败: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
    }
  }
}

// 反馈页面
class FeedbackPage extends StatefulWidget {
  final String scentName;

  const FeedbackPage({super.key, required this.scentName});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('未找到您想要的香氛'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '您搜索的 "${widget.scentName}" 暂未收录',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('我们会尽快补充该香氛的信息。您也可以：', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            const Text(
              '1. 尝试搜索其他相似香氛\n2. 切换到「市面香氛精油推荐」模式查看\n3. 提交反馈，我们会尽快添加',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text('提交反馈'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 提交反馈
  void _submitFeedback() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final scentName = widget.scentName;

      // 创建反馈表（如果不存在）
      await db.execute('''
        CREATE TABLE IF NOT EXISTS feedback_scent (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          scent_name TEXT NOT NULL,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await db.insert('feedback_scent', {'scent_name': scentName});

      // 显示成功提示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('感谢反馈！已记录您想要的「$scentName」味道')));

      // 延迟关闭页面
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pop(context);
      });
    } catch (e) {
      print('提交反馈失败: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('提交失败，请稍后重试')));
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}
