import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/DeviceModel.dart';
import '../models/CartItem.dart';
import '../services/CartService.dart';
import 'CheckoutPage.dart';

class LemonOilDetailPage extends StatefulWidget {
  final DeviceModel device;

  const LemonOilDetailPage({super.key, required this.device});

  @override
  State<LemonOilDetailPage> createState() => _LemonOilDetailPageState();
}

class _LemonOilDetailPageState extends State<LemonOilDetailPage> {
  // 是否已收藏
  bool _isFavorited = false;

  @override
  void initState() {
    super.initState();
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

  // ========== UI 构建 ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('柠檬精油'),
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
            // 产品简介模块
            _buildProductIntroduction(),
            // 底部操作区
            _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  // 主视觉区域
  Widget _buildMainVisual() {
    return Container(
      width: double.infinity,
      height: 250,
      color: Colors.grey[200],
      child: Image.network(
        'https://neeko-copilot.bytedance.net/api/text2image?prompt=lemon%20essential%20oil%20bottle%20in%20modern%20home%20setting&size=square',
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
            '柠檬精油',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                '¥99.00',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '¥129.00',
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
            '精选天然柠檬精油，源自专业研究配方，主打提振情绪、缓解压力功效。香气清新提神，可搭配香薰机使用，也可用于空间扩香，唤醒活力，舒缓身心压力。',
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
      price: 99.0, // 现价
      imageUrl: 'https://neeko-copilot.bytedance.net/api/text2image?prompt=lemon%20essential%20oil%20bottle%20in%20modern%20home%20setting&size=square',
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
      price: 99.0, // 现价
      imageUrl: 'https://neeko-copilot.bytedance.net/api/text2image?prompt=lemon%20essential%20oil%20bottle%20in%20modern%20home%20setting&size=square',
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPage(singleItem: cartItem),
      ),
    );
  }
}
