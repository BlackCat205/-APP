import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import 'package:provider/provider.dart';
import '../services/usage_session_service.dart';

/// 风扇定时关闭页面
class FanTimerPage extends StatefulWidget {
  final int fanIndex;

  const FanTimerPage({super.key, required this.fanIndex});

  @override
  State<FanTimerPage> createState() => _FanTimerPageState();
}

class _FanTimerPageState extends State<FanTimerPage> {
  // 选项索引：0=不开启, 1=15分钟, 2=30分钟, 3=60分钟, 4=90分钟, 5=自定义
  int _selectedIndex = 0;

  // 预设时长（分钟），下标对应选项
  static const List<int?> _presetDurations = [null, 15, 30, 60, 90];

  int _customHours = 0;
  int _customMinutes = 0;
  bool _isCustomConfirmed = false;

  // ========== 样式常量 ==========
  static const Color _bgColor = Color(0xFFF5F0EB);
  static const Color _textColor = Color(0xFF2D2D2D);
  static const Color _greyTextColor = Color(0xFF8C8C8C);
  static const Color _accentGreen = Color(0xFFA8D8B9);
  static const Color _disabledBg = Color(0xFFE0E0E0);
  static const Color _disabledFg = Color(0xFF9E9E9E);
  static const Color _hintTextColor = Color(0xFF9E9E9E);
  static const double _defaultPadding = 24.0;
  static const double _cardRadius = 12.0;
  static const double _pickerItemExtent = 48.0;

  // ========== 计算属性 ==========

  String get _fanName => '风扇 ${widget.fanIndex + 1}';

  int get _totalMinutes {
    if (_selectedIndex == 0) return 0;
    if (_selectedIndex == 5) return _customHours * 60 + _customMinutes;
    return _presetDurations[_selectedIndex] ?? 0;
  }

  String get _countdownText {
    final total = _totalMinutes;
    if (total == 0) return '暂未开启';
    final hours = total ~/ 60;
    final minutes = total % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:00';
  }

  bool get _canSave {
    if (_selectedIndex == 0) return true;
    if (_selectedIndex == 5) return _isCustomConfirmed && _totalMinutes > 0;
    return true;
  }

  // ========== 交互方法 ==========

  void _onOptionSelected(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 5) {
        _showTimePickerDialog();
      } else {
        _isCustomConfirmed = false;
        _customHours = 0;
        _customMinutes = 0;
      }
    });
  }

  void _showTimePickerDialog() {
    int tempHours = _customHours;
    int tempMinutes = _customMinutes;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setModalState) => _buildTimePickerContent(
          tempHours: tempHours,
          tempMinutes: tempMinutes,
          onHoursChanged: (v) => setModalState(() => tempHours = v),
          onMinutesChanged: (v) => setModalState(() => tempMinutes = v),
          onConfirm: () {
            setState(() {
              _customHours = tempHours;
              _customMinutes = tempMinutes;
              _isCustomConfirmed = true;
            });
            Navigator.pop(dialogContext);
          },
        ),
      ),
    );
  }

  Widget _buildTimePickerContent({
    required int tempHours,
    required int tempMinutes,
    required ValueChanged<int> onHoursChanged,
    required ValueChanged<int> onMinutesChanged,
    required VoidCallback onConfirm,
  }) {
    return Container(
      height: 320,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '选择自定义时间',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
              TextButton(
                onPressed: onConfirm,
                style: TextButton.styleFrom(foregroundColor: _accentGreen),
                child: const Text(
                  '确定',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                _buildHourPicker(
                  selectedValue: tempHours,
                  onChanged: onHoursChanged,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                  ),
                ),
                _buildMinutePicker(
                  selectedValue: tempMinutes,
                  onChanged: onMinutesChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourPicker({
    required int selectedValue,
    required ValueChanged<int> onChanged,
  }) {
    return _buildScrollPicker(
      label: '小时',
      itemCount: 24,
      selectedValue: selectedValue,
      onChanged: onChanged,
    );
  }

  Widget _buildMinutePicker({
    required int selectedValue,
    required ValueChanged<int> onChanged,
  }) {
    return _buildScrollPicker(
      label: '分钟',
      itemCount: 60,
      selectedValue: selectedValue,
      onChanged: onChanged,
    );
  }

  Widget _buildScrollPicker({
    required String label,
    required int itemCount,
    required int selectedValue,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: _greyTextColor)),
          const SizedBox(height: 8),
          Expanded(
            child: ListWheelScrollView.useDelegate(
              itemExtent: _pickerItemExtent,
              perspective: 0.005,
              diameterRatio: 1.2,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: onChanged,
              controller: FixedExtentScrollController(initialItem: selectedValue),
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (_, index) {
                  if (index < 0 || index >= itemCount) return null;
                  final isSelected = index == selectedValue;
                  return Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? _accentGreen.withOpacity(0.2) : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      index.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? _textColor : _greyTextColor,
                      ),
                    ),
                  );
                },
                childCount: itemCount,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTimer() async {
    if (!_canSave) return;

    if (!BluetoothService.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先连接蓝牙设备')),
        );
      }
      return;
    }

    final totalMinutes = _totalMinutes;
    try {
      await context.read<UsageSessionService>().setTimer(widget.fanIndex + 1, totalMinutes * 60 * 1000);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(totalMinutes == 0 ? '已取消定时' : '定时设置成功')),
      );
      Navigator.pop(context, totalMinutes > 0 ? totalMinutes * 60 * 1000 : 0);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败: $e')),
      );
    }
  }

  // ========== UI 构建 ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('定时关闭'),
        backgroundColor: _bgColor,
        elevation: 0,
      ),
      backgroundColor: _bgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(_defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFanName(),
            const SizedBox(height: 24),
            _buildCountdownCard(),
            const SizedBox(height: 24),
            _buildTimerOptions(),
            const SizedBox(height: 24),
            _buildSaveButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFanName() {
    return Text(
      _fanName,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _textColor,
      ),
    );
  }

  Widget _buildCountdownCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Column(
        children: [
          const Text(
            '剩余时间',
            style: TextStyle(fontSize: 14, color: _greyTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            _countdownText,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w600,
              color: _textColor,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择定时',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_cardRadius),
          ),
          child: Column(
            children: [
              _buildRadioOption('不开启', 0),
              const Divider(height: 1),
              _buildRadioOption('15 分钟', 1),
              const Divider(height: 1),
              _buildRadioOption('30 分钟', 2),
              const Divider(height: 1),
              _buildRadioOption('60 分钟', 3),
              const Divider(height: 1),
              _buildRadioOption('90 分钟', 4),
              const Divider(height: 1),
              _buildCustomOption(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRadioOption(String label, int index) {
    return RadioListTile<int>(
      title: Text(label),
      value: index,
      groupValue: _selectedIndex,
      onChanged: (v) {
        if (v != null) _onOptionSelected(v);
      },
      activeColor: _accentGreen,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  void _onCustomTap() {
    if (_selectedIndex != 5) {
      setState(() => _selectedIndex = 5);
    }
    _showTimePickerDialog();
  }

  Widget _buildCustomOption() {
    final isSelected = _selectedIndex == 5;
    final displayText = _getCustomDisplayText(isSelected);

    return InkWell(
      onTap: _onCustomTap,
      child: RadioListTile<int>(
        title: Text(displayText),
        value: 5,
        groupValue: _selectedIndex,
        onChanged: null,
        activeColor: _accentGreen,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        secondary: isSelected && !_isCustomConfirmed
            ? const Text('请选择时间', style: TextStyle(fontSize: 12, color: _hintTextColor))
            : null,
      ),
    );
  }

  String _getCustomDisplayText(bool isSelected) {
    if (!isSelected || !_isCustomConfirmed) return '自定义';
    if (_customHours > 0 && _customMinutes > 0) {
      return '自定义 ($_customHours小时$_customMinutes分钟)';
    } else if (_customHours > 0) {
      return '自定义 ($_customHours小时)';
    } else if (_customMinutes > 0) {
      return '自定义 ($_customMinutes分钟)';
    }
    return '自定义 (0分钟)';
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _canSave ? _saveTimer : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentGreen,
          foregroundColor: _textColor,
          disabledBackgroundColor: _disabledBg,
          disabledForegroundColor: _disabledFg,
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