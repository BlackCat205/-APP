import 'package:flutter/material.dart';
import '../services/fan_scent_service.dart';

/// 风扇气味配置页面
class FanScentConfigPage extends StatefulWidget {
  const FanScentConfigPage({super.key});

  @override
  State<FanScentConfigPage> createState() => _FanScentConfigPageState();
}

class _FanScentConfigPageState extends State<FanScentConfigPage> {
  // 4个风扇的当前选择
  final Map<int, String> _fanScents = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    await FanScentService.init();
    setState(() {
      for (int i = 1; i <= 4; i++) {
        _fanScents[i] = FanScentService.getFanScent(i);
      }
      _isLoading = false;
    });
  }

  /// 保存配置
  Future<void> _saveConfig() async {
    await FanScentService.setAllFanScents(_fanScents);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('配置已保存')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('气味配置'),
        backgroundColor: const Color(0xFFF5F0EB),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F0EB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '为每个风扇配置气味',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 4个风扇配置
                  Expanded(
                    child: ListView.builder(
                      itemCount: 4,
                      itemBuilder: (context, index) {
                        final fanId = index + 1;
                        return _buildFanItem(fanId);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 保存按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA8D8B9),
                        foregroundColor: const Color(0xFF2D2D2D),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// 构建风扇配置项
  Widget _buildFanItem(int fanId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 风扇图标和名称
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFA8D8B9).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.toys, color: Color(0xFFA8D8B9)),
          ),
          const SizedBox(width: 16),
          // 风扇名称
          Text(
            '风扇 $fanId',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D2D2D),
            ),
          ),
          const Spacer(),
          // 气味下拉选择
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0EB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _fanScents[fanId],
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down),
              items: FanScentService.availableScents.map((scent) {
                return DropdownMenuItem<String>(
                  value: scent,
                  child: Text(scent),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _fanScents[fanId] = value;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
