import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/DeviceModel.dart';
import '../models/CartItem.dart';
import '../providers/device_provider.dart';
import '../services/CartService.dart';
import 'CheckoutPage.dart';

class DeviceDetailPage extends StatefulWidget {
  final DeviceModel device;

  const DeviceDetailPage({super.key, required this.device});

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  // 速度档位映射（UI 用）
  static const Map<int, String> _speedToText = {33: '低', 66: '中', 100: '高'};
  static const Map<int, int> _speedValues = {0: 33, 1: 66, 2: 100};

  late DeviceProvider _provider;
  late DeviceModel _currentDevice;

  // 是否已收藏
  bool _isFavorited = false;

  @override
  void initState() {
    super.initState();
    // 获取 Provider 实例
    _provider = Provider.of<DeviceProvider>(context, listen: false);
    _currentDevice = _provider.devices.firstWhere(
      (d) => d.id == widget.device.id,
      orElse: () => widget.device,
    );

    // 自动添加到浏览记录
    _addFootprint();
    // 检查是否已收藏
    _checkFavoriteStatus();
  }

  // 添加到浏览记录
  Future<void> _addFootprint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final footprintIds = prefs.getStringList('footprints') ?? [];

      // 移除旧记录（如果存在），然后添加到开头
      footprintIds.remove(widget.device.id);
      footprintIds.insert(0, widget.device.id);

      // 只保留最近20条记录
      if (footprintIds.length > 20) {
        footprintIds.removeRange(20, footprintIds.length);
      }

      await prefs.setStringList('footprints', footprintIds);
    } catch (e) {
      print('添加浏览记录失败: $e');
    }
  }

  // 检查是否已收藏
  Future<void> _checkFavoriteStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoriteIds = prefs.getStringList('favorites') ?? [];
      setState(() {
        _isFavorited = favoriteIds.contains(widget.device.id);
      });
    } catch (e) {
      print('检查收藏状态失败: $e');
    }
  }

  // 切换收藏状态
  Future<void> _toggleFavorite() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoriteIds = prefs.getStringList('favorites') ?? [];

      if (_isFavorited) {
        // 取消收藏
        favoriteIds.remove(widget.device.id);
        await prefs.setStringList('favorites', favoriteIds);
        setState(() {
          _isFavorited = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已取消收藏')));
      } else {
        // 添加收藏
        favoriteIds.add(widget.device.id);
        await prefs.setStringList('favorites', favoriteIds);
        setState(() {
          _isFavorited = true;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已添加到收藏')));
      }
    } catch (e) {
      print('切换收藏状态失败: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
    }
  }

  // 刷新当前设备数据（当 Provider 更新时）
  void _refreshDevice() {
    setState(() {
      _currentDevice = _provider.devices.firstWhere(
        (d) => d.id == widget.device.id,
        orElse: () => _currentDevice,
      );
    });
  }

  // 切换总电源
  void _toggleMainPower() {
    final newState = !_currentDevice.isPoweredOn;
    _provider.setPower(_currentDevice.id, newState);
    _refreshDevice();
    _emitDeviceCommand(); // 发送蓝牙指令（可选）
  }

  // 切换通道开关
  void _toggleChannel(int index) {
    final channel = _currentDevice.scentChannels[index];
    _provider.toggleChannel(_currentDevice.id, index, !channel.isActive);
    _refreshDevice();
    _emitDeviceCommand();
  }

  // 修改通道风速
  void _changeChannelSpeed(int index, int newSpeed) {
    _provider.setChannelSpeed(_currentDevice.id, index, newSpeed);
    _refreshDevice();
    _emitDeviceCommand();
  }

  // 修改定时时长（分钟）
  void _updateTimer(int minutes) {
    _provider.updateTimer(_currentDevice.id, minutes);
    _refreshDevice();
    _emitDeviceCommand();
  }

  // 发送硬件指令（与之前相同，仅作演示）
  void _emitDeviceCommand() {
    final activeChannels = _currentDevice.scentChannels
        .where((ch) => ch.isActive)
        .map((ch) => '通道${ch.channel}')
        .join(',');
    final speedDesc = _currentDevice.scentChannels
        .where((ch) => ch.isActive)
        .map((ch) => '通道${ch.channel}: ${_speedToText[ch.speed] ?? '中'}')
        .join(',');
    final command = {
      'deviceId': _currentDevice.id,
      'power': _currentDevice.isPoweredOn ? 'on' : 'off',
      'activeChannels': activeChannels,
      'channelSpeeds': speedDesc,
      'timer': '${_currentDevice.timer ~/ 60}小时',
      'timestamp': DateTime.now().toString(),
    };
    debugPrint('发送硬件指令: $command');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('指令已发送: ${command.toString()}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ========== UI 构建 ==========
  @override
  Widget build(BuildContext context) {
    // 监听 Provider 变化以实时刷新 UI
    return Consumer<DeviceProvider>(
      builder: (ctx, provider, child) {
        // 获取最新的设备数据
        final device = provider.devices.firstWhere(
          (d) => d.id == widget.device.id,
          orElse: () => _currentDevice,
        );
        _currentDevice = device;

        return Scaffold(
          appBar: AppBar(
            title: const Text('情绪香薰机'),
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorited ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorited ? Colors.red : null,
                ),
                onPressed: _toggleFavorite,
                tooltip: _isFavorited ? '取消收藏' : '添加收藏',
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 主视觉区域
                _buildMainVisual(),
                // 价格区域
                _buildPriceSection(),
                // 包含气味模块
                _buildIncludedScents(),
                // 产品简介模块
                _buildProductIntroduction(),
                // 底部操作区
                _buildBottomAction(),
              ],
            ),
          ),
        );
      },
    );
  }

  // 主视觉区域
  Widget _buildMainVisual() {
    return Container(
      width: double.infinity,
      height: 250,
      color: Colors.grey[200],
      child: Image.network(
        'https://neeko-copilot.bytedance.net/api/text2image?prompt=smart%20aroma%20diffuser%20device%20in%20modern%20home%20setting&size=square',
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: Text(
                '图片加载失败',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          );
        },
      ),
    );
  }

  // 价格区域
  Widget _buildPriceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '情绪香薰机',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                '¥299.00',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '¥349.00',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[500],
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 包含气味模块
  Widget _buildIncludedScents() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '包含气味',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // 2x2 四宫格卡片布局
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              final scents = [
                {'title': '大马士革玫瑰', 'subtitle': '舒缓焦虑，改善睡眠'},
                {'title': '薰衣草', 'subtitle': '助眠安神，缓解抑郁'},
                {'title': '苦橙', 'subtitle': '降低焦虑，舒缓压力'},
                {'title': '柠檬', 'subtitle': '提振情绪，缓解压力'},
              ];
              final scent = scents[index];
              return _buildScentCard(scent['title']!, scent['subtitle']!);
            },
          ),
        ],
      ),
    );
  }

  // 气味卡片
  Widget _buildScentCard(String title, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // 产品简介模块
  Widget _buildProductIntroduction() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '产品简介',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            '智能情绪香薰机，一机适配四种专属气味。融合大马士革玫瑰、薰衣草、苦橙、柠檬 4 种天然精油香氛，一键切换情绪模式，带你体验沉浸式芳香疗愈，找回内心的平静与愉悦。',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // 底部操作区
  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8, bottom: 20),
      child: Row(
        children: [
          // 购物车图标
          GestureDetector(
            onTap: _addToCart,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: const Icon(Icons.shopping_cart, color: Colors.red),
            ),
          ),
          const SizedBox(width: 12),
          // 立即购买按钮
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _buyNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '立即购买',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 添加到购物车
  void _addToCart() {
    final cartItem = CartItem(
      id: widget.device.id,
      name: widget.device.name,
      price: 299.0, // 现价
      imageUrl:
          'https://neeko-copilot.bytedance.net/api/text2image?prompt=smart%20aroma%20diffuser%20device%20in%20modern%20home%20setting&size=square',
    );

    CartService.addToCart(cartItem).then((success) {
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已加入购物车')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('添加失败，请重试')));
      }
    });
  }

  // 立即购买
  void _buyNow() {
    final cartItem = CartItem(
      id: widget.device.id,
      name: widget.device.name,
      price: 299.0, // 现价
      imageUrl:
          'https://neeko-copilot.bytedance.net/api/text2image?prompt=smart%20aroma%20diffuser%20device%20in%20modern%20home%20setting&size=square',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPage(singleItem: cartItem),
      ),
    );
  }
}
