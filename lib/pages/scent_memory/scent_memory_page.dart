import 'package:flutter/material.dart';
import '../AIScentAssistantPage.dart';

/// AI 气味助手页面的包装组件。
/// 只提供一个干净的 Scaffold 容器，内部的标题栏和返回逻辑由
/// [AIScentAssistantPage] 自身管理。
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
      // 不设置 AppBar，完全交由子页面处理
      body: AIScentAssistantPage(),
    );
  }
}