import 'package:flutter/material.dart';
import 'smell_edit_page.dart';

/// 气味体验结束弹窗，引导用户收藏为气味瞬间
class SmellSavePopup extends StatelessWidget {
  final List<String> recipeList;
  final String duration;
  final List<int> recordIds;

  const SmellSavePopup({
    super.key,
    required this.recipeList,
    required this.duration,
    this.recordIds = const [],
  });

  // ========== 样式常量 ==========
  static const Color _textColor = Color(0xFF2D2D2D);
  static const Color _greyTextColor = Color(0xFF8C8C8C);
  static const Color _accentGreen = Color(0xFFA8D8B9);
  static const Color _tagBgColor = Color(0xFFE8D5B7);
  static const double _defaultRadius = 8.0;
  static const double _tagRadius = 16.0;

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
          _buildHeader(),
          const SizedBox(height: 16),
          Text(
            '这次陪伴你的是',
            style: const TextStyle(fontSize: 16, color: _textColor),
          ),
          const SizedBox(height: 16),
          _buildRecipeTags(),
          const SizedBox(height: 16),
          Text(
            '持续时长 $duration',
            style: const TextStyle(fontSize: 14, color: _greyTextColor),
          ),
          const SizedBox(height: 24),
          _buildCollectButton(context),
          const SizedBox(height: 16),
          _buildSkipButton(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('🍃', style: TextStyle(fontSize: 24)),
        SizedBox(width: 8),
        Text(
          '气味体验已结束',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: recipeList.map((ingredient) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _tagBgColor,
            borderRadius: BorderRadius.circular(_tagRadius),
          ),
          child: Text(
            ingredient,
            style: const TextStyle(fontSize: 14, color: _textColor),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCollectButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SmellEditPage(
                usageRecordIds: recordIds,
                scentList: recipeList,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_defaultRadius)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: const Text(
          '收藏为气味瞬间',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text(
        '暂不保存',
        style: TextStyle(fontSize: 14, color: _greyTextColor),
      ),
    );
  }
}