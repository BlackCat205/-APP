import 'package:flutter/material.dart';
import '../services/fan_scent_service.dart';

/// 风扇气味配置页面
class FanScentConfigPage extends StatefulWidget {
  const FanScentConfigPage({super.key});

  @override
  State<FanScentConfigPage> createState() => _FanScentConfigPageState();
}

class _FanScentConfigPageState extends State<FanScentConfigPage> {
  final Map<int, String> _fanScents = {};
  bool _isLoading = true;

  // ========== 样式常量 ==========
  static const Color _bgColor = Color(0xFFF5F0EB);
  static const Color _textColor = Color(0xFF2D2D2D);
  static const Color _accentGreen = Color(0xFFA8D8B9);
  static const double _defaultPadding = 24.0;
  static const double _cardRadius = 12.0;
  static const double _iconBoxSize = 48.0;
  static const int _fanCount = 4;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    await FanScentService.init();
    setState(() {
      for (int i = 1; i <= _fanCount; i++) {
        _fanScents[i] = FanScentService.getFanScent(i);
      }
      _isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    await FanScentService.setAllFanScents(_fanScents);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('配置已保存')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('气味配置'),
        backgroundColor: _bgColor,
        elevation: 0,
      ),
      backgroundColor: _bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(_defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '为每个风扇配置气味',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _fanCount,
              itemBuilder: (_, index) => _buildFanItem(index + 1),
            ),
          ),
          const SizedBox(height: 24),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildFanItem(int fanId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Row(
        children: [
          _buildFanIcon(),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '风扇 $fanId',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
            ),
          ),
          _buildScentDropdown(fanId),
        ],
      ),
    );
  }

  Widget _buildFanIcon() {
    return Container(
      width: _iconBoxSize,
      height: _iconBoxSize,
      decoration: BoxDecoration(
        color: _accentGreen.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.toys, color: _accentGreen),
    );
  }

  Widget _buildScentDropdown(int fanId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: _fanScents[fanId],
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down),
        items: FanScentService.availableScents
            .map((scent) => DropdownMenuItem(value: scent, child: Text(scent)))
            .toList(),
        onChanged: (value) {
          if (value != null) setState(() => _fanScents[fanId] = value);
        },
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveConfig,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentGreen,
          foregroundColor: _textColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          '保存',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}