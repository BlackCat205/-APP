import 'package:flutter/material.dart';
import 'smell_edit_page.dart';

/// 气味瞬间保存弹窗
class SmellSavePopup extends StatelessWidget {
  final List<String> recipeList; // 配方列表
  final String duration; // 持续时长
  final List<int> recordIds; // 使用记录ID列表（外键关联）

  const SmellSavePopup({
    Key? key,
    required this.recipeList,
    required this.duration,
    this.recordIds = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 顶部标题
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🍃', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(
                '气味体验已结束',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D2D2D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 文案
          Text(
            '这次陪伴你的是',
            style: TextStyle(fontSize: 16, color: const Color(0xFF2D2D2D)),
          ),
          const SizedBox(height: 16),

          // 配方标签区
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: recipeList.map((ingredient) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8D5B7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  ingredient,
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF2D2D2D),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 时长
          Text(
            '持续时长 $duration',
            style: TextStyle(fontSize: 14, color: const Color(0xFF8C8C8C)),
          ),
          const SizedBox(height: 24),

          // 主按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SmellEditPage(
                      usageRecordIds: recordIds,
                      scentList: recipeList, // 传递去重后的气味列表
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA8D8B9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                '收藏为气味瞬间',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D2D2D),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 底部链接
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              '暂不保存',
              style: TextStyle(fontSize: 14, color: const Color(0xFF8C8C8C)),
            ),
          ),
        ],
      ),
    );
  }
}
