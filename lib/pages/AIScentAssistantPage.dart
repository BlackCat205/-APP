import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/ScentMemory.dart';
import '../services/ScentMemoryService.dart';
import '../services/spark_api_service.dart';
import '../services/ai_api_config.dart';
import 'ScentMemoryPage.dart';

/// AI 气味助手聊天页面（基于讯飞大模型）。
class AIScentAssistantPage extends StatefulWidget {
  const AIScentAssistantPage({super.key});

  @override
  State<AIScentAssistantPage> createState() => _AIScentAssistantPageState();
}

class _AIScentAssistantPageState extends State<AIScentAssistantPage> {
  // ========== 聊天核心 ==========
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;

  // ========== 服务与工具 ==========
  final ScentMemoryService _memoryService = ScentMemoryService();
  late final SparkApiService _aiService;
  final Uuid _uuid = const Uuid();
  final ScrollController _scrollController = ScrollController();

  // ========== 常量 ==========
  static const String _chatHistoryKey = 'ai_chat_history';
  static const double _horizontalPadding = 16.0;
  static const double _verticalPadding = 12.0;
  static const double _messageRadius = 16.0;

  // ========== 生命周期 ==========

  @override
  void initState() {
    super.initState();
    _memoryService.init();
    _aiService = SparkApiService(
      apiPassword: AiApiConfig.apiPassword,
      modelName: AiApiConfig.modelName,
      baseUrl: AiApiConfig.baseUrl,
    );
    _loadChatHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // ========== 聊天历史持久化 ==========

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_chatHistoryKey);
      if (jsonStr != null) {
        final history = json.decode(jsonStr) as List<dynamic>;
        setState(() => _messages.addAll(history.cast<Map<String, dynamic>>()));
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('加载聊天记录失败: $e');
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSave = _messages.length > 100
          ? _messages.sublist(_messages.length - 100)
          : _messages;
      await prefs.setString(_chatHistoryKey, json.encode(toSave));
    } catch (e) {
      debugPrint('保存聊天记录失败: $e');
    }
  }

  Future<void> _clearChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chatHistoryKey);
      setState(() => _messages.clear());
    } catch (e) {
      debugPrint('清空聊天记录失败: $e');
    }
  }

  // ========== 辅助工具 ==========

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // ========== 情绪识别与画像 ==========

  final Map<String, List<String>> _emotionKeywords = {
    '疲惫': ['疲惫', '累', '困', '没精神', '乏力', '疲倦', '劳累', '精疲力尽'],
    '焦虑': ['焦虑', '紧张', '烦躁', '压力大', '不安', '担心', '着急', '心慌'],
    '低落': ['伤心', '难过', '想哭', '低落', '沮丧', '郁闷', '失落', '痛苦', '悲伤'],
    '失眠': ['睡不着', '失眠', '难入睡', '睡不好', '熬夜', '多梦', '早醒'],
    '放松': ['放松', '舒服', '平静', '惬意', '安逸', '宁静', '轻松', '自在'],
  };

  String _detectEmotion(String text) {
    final lower = text.toLowerCase();
    for (final entry in _emotionKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) return entry.key;
      }
    }
    return '';
  }

  Future<String> _generateUserProfile() async {
    try {
      final memories = _memoryService.getAllMemories();
      if (memories.isEmpty) return '';

      final emotionCount = <String, int>{};
      final scentCount = <String, int>{};
      final sceneCount = <String, int>{};
      final recentMemories = memories.take(5).toList();

      for (final m in memories) {
        if (m.emotion.isNotEmpty)
          emotionCount[m.emotion] = (emotionCount[m.emotion] ?? 0) + 1;
        if (m.scent.isNotEmpty)
          scentCount[m.scent] = (scentCount[m.scent] ?? 0) + 1;
        _extractScenes(m.userInput, sceneCount);
      }

      final topEmotions = emotionCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topScents = scentCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topScenes = sceneCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final buf = StringBuffer();
      buf.writeln('【用户画像】');
      buf.writeln('- 气味记忆总数：${memories.length} 条');
      if (topEmotions.isNotEmpty) {
        buf.writeln(
          '- 高频情绪：${topEmotions.take(3).map((e) => '${e.key}(${e.value}次)').join('、')}',
        );
      }
      if (topScents.isNotEmpty) {
        buf.writeln(
          '- 高频气味：${topScents.take(3).map((e) => '${e.key}(${e.value}次)').join('、')}',
        );
      }
      if (topScenes.isNotEmpty) {
        buf.writeln('- 常用场景：${topScenes.take(3).map((e) => e.key).join('、')}');
      }
      if (recentMemories.isNotEmpty) {
        final recentScents = recentMemories
            .map((m) => m.scent)
            .where((s) => s.isNotEmpty)
            .toList();
        if (recentScents.isNotEmpty)
          buf.writeln('- 最近偏好：${recentScents.take(3).join('、')}');
      }
      return buf.toString();
    } catch (e) {
      debugPrint('生成用户画像失败: $e');
      return '';
    }
  }

  void _extractScenes(String input, Map<String, int> sceneCount) {
    if (input.contains('睡前') || input.contains('睡觉'))
      sceneCount['睡前'] = (sceneCount['睡前'] ?? 0) + 1;
    if (input.contains('作业') || input.contains('学习'))
      sceneCount['写作业'] = (sceneCount['写作业'] ?? 0) + 1;
    if (input.contains('午休') || input.contains('午睡'))
      sceneCount['午休'] = (sceneCount['午休'] ?? 0) + 1;
    if (input.contains('工作') || input.contains('办公'))
      sceneCount['工作'] = (sceneCount['工作'] ?? 0) + 1;
  }

  Future<String> _getPersonalScentLibrary() async {
    try {
      final db = await AppDatabase().database;
      const scenes = ['下班回家', '工作学习', '睡前', '周末放松', '其他'];
      final buf = StringBuffer();
      buf.writeln('【你的气味库 - 个人最佳气味组合】');
      for (final scene in scenes) {
        final records = await db.query(
          'smell_moment_record',
          where: "scene_tag = ? AND source != 'test'",
          whereArgs: [scene],
          orderBy: 'score DESC',
          limit: 1,
        );
        if (records.isNotEmpty) {
          final combo = records.first['scent_combo'] ?? '未记录';
          final score = records.first['score'] ?? 0;
          if (combo != '未记录') buf.writeln('- $scene：$combo（评分: $score）');
        }
      }
      final result = buf.toString();
      return result == '【你的气味库 - 个人最佳气味组合】\n' ? '' : result;
    } catch (e) {
      debugPrint('获取个性化气味库失败: $e');
      return '';
    }
  }

  // ========== 消息发送与AI交互 ==========

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _addUserMessage(text);
    await _saveChatHistory();
    _scrollToBottom();

    try {
      final detectedEmotion = _detectEmotion(text);
      final userProfile = await _generateUserProfile();
      final personalLibrary = await _getPersonalScentLibrary();

      const systemPrompt =
          '''你是APP专属「气味疗愈助手」，**必须严格按以下 4 步回复**，并**优先结合用户个人气味库**做个性化推荐：

1. 情绪识别：根据用户输入，精准识别情绪（疲惫/焦虑/低落/失眠/放松）
2. 气味推荐：**优先推荐用户个人气味库中该场景评分最高的气味组合**，其次匹配情绪功效；必须给出 1-2 种具体香气+功效
3. 场景匹配：结合用户个人气味库中的常用场景，给出具体使用建议
4. 设备适配：推荐个人气味库中的香氛组合；结尾提示可保存到气味记忆

回复格式：
【情绪识别】xxx
【气味推荐】xxx（功效：xxx）**优先使用个人气味库数据**
【场景建议】xxx
【使用指引】xxx''';

      final fullPrompt =
          '$systemPrompt\n'
          '${userProfile.isNotEmpty ? '$userProfile\n' : ''}'
          '${personalLibrary.isNotEmpty ? '$personalLibrary\n' : ''}'
          '用户当前输入：$text\n'
          '${detectedEmotion.isNotEmpty ? '（用户情绪关键词命中：$detectedEmotion）' : ''}';

      final result = await _aiService.getScentRecommendation(fullPrompt);
      if (result['success']) {
        _handleRecommendation(result['data']);
      } else {
        _addErrorMessage(result['error'] ?? '未知错误');
      }
    } catch (e) {
      _addErrorMessage('抱歉，无法获取推荐，请稍后重试');
    }
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add({'type': 'user', 'text': text});
      _textController.clear();
      _isLoading = true;
    });
  }

  void _addErrorMessage(String error) {
    setState(() {
      _messages.add({'type': 'ai', 'error': error});
      _isLoading = false;
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  void _handleRecommendation(Map<String, dynamic> data) {
    setState(() {
      _messages.add({'type': 'ai', 'data': data});
      _isLoading = false;
    });
    _saveChatHistory();
    _scrollToBottom();
    _saveMemory(data);
  }

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
      debugPrint('保存记忆失败: $e');
    }
  }

  // ========== 构建 UI ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeaderBar(),
            Expanded(child: _buildMessageList()),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            _buildInputArea(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: _verticalPadding,
      ),
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
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'AI气味记忆助手',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showClearDialog(),
            tooltip: '清空聊天记录',
          ),
          IconButton(
            icon: const Icon(Icons.memory),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScentMemoryPage()),
            ),
            tooltip: '我的气味记忆',
          ),
        ],
      ),
    );
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空聊天记录'),
        content: const Text('确定要清空所有聊天记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _clearChatHistory();
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _messages.length,
      padding: const EdgeInsets.all(_horizontalPadding),
      itemBuilder: (_, index) => _buildMessageBubble(_messages[index]),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    if (message['type'] == 'user') {
      return _buildUserBubble(message['text'] as String);
    }
    if (message.containsKey('error')) {
      return _buildErrorBubble(message['error'] as String);
    }
    return _buildAIBubble(message['data'] as Map<String, dynamic>);
  }

  Widget _buildUserBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(_messageRadius),
        ),
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildErrorBubble(String error) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(_messageRadius),
        ),
        child: Text(
          error,
          style: const TextStyle(fontSize: 16, color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildAIBubble(Map<String, dynamic> data) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(_messageRadius),
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
            if (data.containsKey('emotion')) const SizedBox(height: 4),
            Text(
              '推荐气味: ${data['scent']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (data.containsKey('effect'))
              Text(
                '功效: ${data['effect']}',
                style: const TextStyle(fontSize: 16),
              ),
            if (data.containsKey('category'))
              Text(
                '香气风格: ${data['category']}',
                style: const TextStyle(fontSize: 16),
              ),
            if (data.containsKey('reason'))
              Text(
                '推荐理由: ${data['reason']}',
                style: const TextStyle(fontSize: 16),
              ),
            if (data.containsKey('scene'))
              Text(
                '适用场景: ${data['scene']}',
                style: const TextStyle(fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _horizontalPadding,
        8,
        _horizontalPadding,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
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
          _buildSendButton(),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _sendMessage,
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(16),
        backgroundColor: Colors.green,
      ),
      child: const Icon(Icons.send, color: Colors.white),
    );
  }

  // ========== 已废弃的辅助方法（保留兼容） ==========

  void _saveToMemory(Map<String, dynamic> data) async {
    // 此方法已不再使用，功能由 _saveMemory 替代
    try {
      final db = await AppDatabase().database;
      String userInput = '';
      for (final msg in _messages.reversed) {
        if (msg['type'] == 'user') {
          userInput = msg['text'] ?? '';
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已保存到气味记忆')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    }
  }
}
