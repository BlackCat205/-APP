import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';

class FanTimerPage extends StatefulWidget {
  final int fanIndex;

  const FanTimerPage({super.key, required this.fanIndex});

  @override
  State<FanTimerPage> createState() => _FanTimerPageState();
}

class _FanTimerPageState extends State<FanTimerPage> {
  // 当前选中的选项索引：0=不开启, 1=15分钟, 2=30分钟, 3=60分钟, 4=90分钟, 5=自定义
  int _selectedIndex = 0;

  // 预设时长（分钟）
  final List<int?> _presetDurations = [null, 15, 30, 60, 90];

  // 自定义时间（小时和分钟）
  int _customHours = 0;
  int _customMinutes = 0;
  bool _isCustomConfirmed = false;

  String get _fanName => '风扇 ${widget.fanIndex + 1}';

  // 获取当前选中的总分钟数
  int get _totalMinutes {
    if (_selectedIndex == 0) {
      return 0; // 不开启
    } else if (_selectedIndex == 5) {
      // 自定义
      return _customHours * 60 + _customMinutes;
    } else {
      // 预设时长
      return _presetDurations[_selectedIndex] ?? 0;
    }
  }

  // 倒计时显示文本
  String get _countdownText {
    final totalMinutes = _totalMinutes;
    if (totalMinutes == 0) {
      return '暂未开启';
    }
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:00';
  }

  // 是否可以保存
  bool get _canSave {
    if (_selectedIndex == 0) {
      return true; // 取消定时总是可以
    } else if (_selectedIndex == 5) {
      // 自定义必须确认且时长大于0
      return _isCustomConfirmed && _totalMinutes > 0;
    }
    return true; // 预设时长
  }

  // 处理选项选择
  void _onOptionSelected(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 5) {
        // 选中自定义，弹出滚轮选择器
        _showTimePickerDialog();
      } else {
        // 选中其他选项，重置自定义状态
        _isCustomConfirmed = false;
        _customHours = 0;
        _customMinutes = 0;
      }
    });
  }

  // 显示时间滚轮选择器
  void _showTimePickerDialog() {
    int tempHours = _customHours;
    int tempMinutes = _customMinutes;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: 320,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 标题栏
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '选择自定义时间',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _customHours = tempHours;
                            _customMinutes = tempMinutes;
                            _isCustomConfirmed = true;
                          });
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFA8D8B9),
                        ),
                        child: const Text(
                          '确定',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 滚轮选择器
                  Expanded(
                    child: Row(
                      children: [
                        // 小时选择器
                        Expanded(
                          child: Column(
                            children: [
                              const Text(
                                '小时',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF8C8C8C),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListWheelScrollView.useDelegate(
                                  itemExtent: 48,
                                  perspective: 0.005,
                                  diameterRatio: 1.2,
                                  physics: const FixedExtentScrollPhysics(),
                                  onSelectedItemChanged: (index) {
                                    setModalState(() {
                                      tempHours = index;
                                    });
                                  },
                                  controller: FixedExtentScrollController(
                                    initialItem: tempHours,
                                  ),
                                  childDelegate: ListWheelChildBuilderDelegate(
                                    builder: (context, index) {
                                      if (index < 0 || index > 23) return null;
                                      final isSelected = index == tempHours;
                                      return Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(
                                                  0xFFA8D8B9,
                                                ).withOpacity(0.2)
                                              : null,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          index.toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? const Color(0xFF2D2D2D)
                                                : const Color(0xFF8C8C8C),
                                          ),
                                        ),
                                      );
                                    },
                                    childCount: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 分隔符
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                        ),
                        // 分钟选择器
                        Expanded(
                          child: Column(
                            children: [
                              const Text(
                                '分钟',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF8C8C8C),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListWheelScrollView.useDelegate(
                                  itemExtent: 48,
                                  perspective: 0.005,
                                  diameterRatio: 1.2,
                                  physics: const FixedExtentScrollPhysics(),
                                  onSelectedItemChanged: (index) {
                                    setModalState(() {
                                      tempMinutes = index;
                                    });
                                  },
                                  controller: FixedExtentScrollController(
                                    initialItem: tempMinutes,
                                  ),
                                  childDelegate: ListWheelChildBuilderDelegate(
                                    builder: (context, index) {
                                      if (index < 0 || index > 59) return null;
                                      final isSelected = index == tempMinutes;
                                      return Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(
                                                  0xFFA8D8B9,
                                                ).withOpacity(0.2)
                                              : null,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          index.toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? const Color(0xFF2D2D2D)
                                                : const Color(0xFF8C8C8C),
                                          ),
                                        ),
                                      );
                                    },
                                    childCount: 60,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveTimer() async {
    if (!_canSave) return;

    // 校验蓝牙连接状态
    if (!BluetoothService.isConnected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先连接蓝牙设备')));
      return;
    }

    String command;
    final totalMinutes = _totalMinutes;

    if (totalMinutes == 0) {
      // 取消定时
      command = 'fan${widget.fanIndex + 1}_cancel';
    } else {
      // 设置定时（转换为毫秒）
      final milliseconds = totalMinutes * 60 * 1000;
      command = 'fan${widget.fanIndex + 1}_off_$milliseconds';
    }

    try {
      // 使用无换行符的方法发送指令
      await BluetoothService.sendPlainCommand(command);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(totalMinutes == 0 ? '已取消定时' : '定时设置成功')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('发送失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('定时关闭'),
        backgroundColor: const Color(0xFFF5F0EB),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F0EB),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 风扇名称
            Text(
              _fanName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 24),

            // 倒计时显示
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    '剩余时间',
                    style: TextStyle(fontSize: 14, color: Color(0xFF8C8C8C)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _countdownText,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D2D2D),
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 选择定时
            const Text(
              '选择定时',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 16),

            // 定时选项
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
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

            const Spacer(),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSave ? _saveTimer : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA8D8B9),
                  foregroundColor: const Color(0xFF2D2D2D),
                  disabledBackgroundColor: const Color(0xFFE0E0E0),
                  disabledForegroundColor: const Color(0xFF9E9E9E),
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
            ),
          ],
        ),
      ),
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
      activeColor: const Color(0xFFA8D8B9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  // 处理自定义选项点击（支持再次点击重新编辑）
  void _onCustomTap() {
    if (_selectedIndex != 5) {
      // 未选中自定义，先选中并弹出选择器
      setState(() {
        _selectedIndex = 5;
      });
    }
    // 无论是否已选中，都弹出时间选择器
    _showTimePickerDialog();
  }

  Widget _buildCustomOption() {
    final isCustomSelected = _selectedIndex == 5;

    // 构建显示文本
    String displayText;
    if (isCustomSelected && _isCustomConfirmed) {
      if (_customHours > 0 && _customMinutes > 0) {
        displayText = '自定义 (${_customHours}小时${_customMinutes}分钟)';
      } else if (_customHours > 0) {
        displayText = '自定义 (${_customHours}小时)';
      } else if (_customMinutes > 0) {
        displayText = '自定义 (${_customMinutes}分钟)';
      } else {
        displayText = '自定义 (0分钟)';
      }
    } else {
      displayText = '自定义';
    }

    // 使用 InkWell 包装，支持点击整行唤起选择器
    return InkWell(
      onTap: _onCustomTap,
      child: RadioListTile<int>(
        title: Text(displayText),
        value: 5,
        groupValue: _selectedIndex,
        // onChanged 置空，由 InkWell 处理点击
        onChanged: null,
        activeColor: const Color(0xFFA8D8B9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        secondary: isCustomSelected && !_isCustomConfirmed
            ? const Text(
                '请选择时间',
                style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
              )
            : null,
      ),
    );
  }
}
