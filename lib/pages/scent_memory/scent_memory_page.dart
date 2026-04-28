import 'package:flutter/material.dart';
import '../AIScentAssistantPage.dart';

/// AI 气味助手页面包装器
/// 只提供返回功能，不显示标题（标题在子页面中显示）
class AIScentAssistantPageWrapper extends StatefulWidget {
  const AIScentAssistantPageWrapper({super.key});

  @override
  State<AIScentAssistantPageWrapper> createState() =>
      _AIScentAssistantPageWrapperState();
}

class _AIScentAssistantPageWrapperState
    extends State<AIScentAssistantPageWrapper> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      // 不设置appBar，让AIScentAssistantPage自己处理标题
      body: AIScentAssistantPage(),
    );
  }
}
