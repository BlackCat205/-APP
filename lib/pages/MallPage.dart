import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../models/DeviceModel.dart';
import 'CartPage.dart';
import 'MyOrderPage.dart';
import 'DeviceDetailPage.dart';
import 'EssentialOilSetDetailPage.dart';
import 'LavenderOilDetailPage.dart';
import 'LemonOilDetailPage.dart';
import 'FavoritePage.dart';
import 'FootprintPage.dart';
import '../services/CartService.dart';

/// 商城页面
/// 负责展示商品列表，提供订单、购物车等导航入口
class MallPage extends StatelessWidget {
  // 模拟商品数据列表
  static final List<Map<String, dynamic>> products = [
    {
      'id': 'prod1',
      'name': '情绪香薰机',
      'description': '智能香薰机，支持蓝牙控制，多种香氛模式',
      'price': 299.0,
      'imageUrl':
          'https://neeko-copilot.bytedance.net/api/text2image?prompt=smart%20aroma%20diffuser%20device&size=square',
      'rating': 4.8,
      'reviewCount': 123,
    },
    {
      'id': 'prod2',
      'name': '香薰精油套装',
      'description': '10ml×4瓶精油套装，天然植物提取',
      'price': 199.0,
      'imageUrl':
          'https://neeko-copilot.bytedance.net/api/text2image?prompt=essential%20oil%20set%20in%20bottles&size=square',
      'rating': 4.9,
      'reviewCount': 234,
    },
    {
      'id': 'prod3',
      'name': '薰衣草精油',
      'description': '天然薰衣草精油，舒缓放松，助眠安神',
      'price': 89.0,
      'imageUrl':
          'https://neeko-copilot.bytedance.net/api/text2image?prompt=lavender%20essential%20oil%20bottle&size=square',
      'rating': 4.9,
      'reviewCount': 189,
    },
    {
      'id': 'prod4',
      'name': '柠檬精油',
      'description': '天然柠檬精油，提振情绪，缓解压力',
      'price': 99.0,
      'imageUrl':
          'https://neeko-copilot.bytedance.net/api/text2image?prompt=lemon%20essential%20oil%20bottle&size=square',
      'rating': 4.8,
      'reviewCount': 156,
    },
  ];

  const MallPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 页面标题栏
      appBar: AppBar(
        title: const Text('商城'),
        centerTitle: true, // 标题居中，提升视觉体验
        actions: [
          // 购物车入口
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () => _navigateToPage(context, const CartPage()),
              ),
              // 购物车数量角标
              FutureBuilder<int>(
                future: CartService.getCartItemCount(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data! > 0) {
                    return Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${snapshot.data}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ],
          ),
        ],
      ),
      // 主体内容 - 可滚动布局适配不同屏幕
      body: SingleChildScrollView(
        padding: EdgeInsets.zero, // 消除默认内边距，统一布局控制
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部功能导航栏（订单/购物车/收藏/足迹）
            _buildTopNavigationBar(context),
            // 商品列表区域
            _buildProductListSection(context),
          ],
        ),
      ),
    );
  }

  /// 构建顶部功能导航栏
  /// 包含我的订单、购物车、商品收藏、商品足迹四个核心功能入口
  Widget _buildTopNavigationBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 我的订单入口
          _buildNavItem(
            context: context,
            icon: Icons.list_alt,
            label: '我的订单',
            onTap: () => _navigateToPage(context, const MyOrderPage()),
          ),
          // 购物车入口（带数量角标）
          _buildCartNavItem(context),
          // 商品收藏入口
          _buildNavItem(
            context: context,
            icon: Icons.favorite_outline,
            label: '商品收藏',
            onTap: () => _navigateToPage(context, const FavoritePage()),
          ),
          // 商品足迹入口
          _buildNavItem(
            context: context,
            icon: Icons.history,
            label: '商品足迹',
            onTap: () => _navigateToPage(context, const FootprintPage()),
          ),
        ],
      ),
    );
  }

  /// 构建通用导航项
  /// 统一导航项样式，减少重复代码
  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: Colors.red),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建购物车导航项（带数量角标）
  /// 特殊处理：展示购物车商品数量角标
  Widget _buildCartNavItem(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigateToPage(context, const CartPage()),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 购物车图标 + 数量角标
            Stack(
              children: [
                const Icon(Icons.shopping_cart, size: 24, color: Colors.red),
                // 购物车数量角标
                Consumer<CartProvider>(
                  builder: (context, cartProvider, child) {
                    if (cartProvider.itemCount <= 0) return const SizedBox();

                    return Positioned(
                      top: -5,
                      right: -5,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${cartProvider.itemCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '购物车',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建商品列表区域
  /// 包含页面标题和网格布局的商品列表
  Widget _buildProductListSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 区域标题
          const Text(
            '商品列表',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // 商品网格列表
          _buildProductGrid(context),
        ],
      ),
    );
  }

  /// 构建商品网格列表
  /// 2列布局展示所有气味套装商品
  Widget _buildProductGrid(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true, // 适配外层SingleChildScrollView
      physics: const NeverScrollableScrollPhysics(), // 禁用自身滚动
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2列布局
        crossAxisSpacing: 16, // 列间距
        mainAxisSpacing: 16, // 行间距
        childAspectRatio: 0.75, // 子项宽高比
      ),
      itemCount: products.length,
      itemBuilder: (context, index) =>
          _buildProductItem(context, products[index]),
    );
  }

  /// 构建单个商品项
  /// 展示商品图片、名称、价格、评分等信息
  Widget _buildProductItem(BuildContext context, Map<String, dynamic> product) {
    return GestureDetector(
      // 点击跳转到商品详情页
      onTap: () {
        final device = DeviceModel.fromJson(product);
        if (product['id'] == 'prod1') {
          // 情绪香薰机
          _navigateToPage(context, DeviceDetailPage(device: device));
        } else if (product['id'] == 'prod2') {
          // 香薰精油套装
          _navigateToPage(context, EssentialOilSetDetailPage(device: device));
        } else if (product['id'] == 'prod3') {
          // 薰衣草精油
          _navigateToPage(context, LavenderOilDetailPage(device: device));
        } else if (product['id'] == 'prod4') {
          // 柠檬精油
          _navigateToPage(context, LemonOilDetailPage(device: device));
        } else {
          // 其他商品暂时跳转到通用详情页
          _navigateToPage(context, DeviceDetailPage(device: device));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.grey[100]!,
              blurRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 商品图片区域
            _buildProductImageSection(product),
            // 商品信息区域
            _buildProductInfoSection(product),
          ],
        ),
      ),
    );
  }

  /// 构建商品图片区域
  /// 包含商品图片
  Widget _buildProductImageSection(Map<String, dynamic> product) {
    return Container(
      height: 120,
      color: Colors.grey[200],
      child: Image.network(
        product['imageUrl'],
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // 图片加载失败时的占位UI
          return Container(
            height: 120,
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

  /// 构建商品信息区域
  /// 展示商品名称、价格、评分、评价数等
  Widget _buildProductInfoSection(Map<String, dynamic> product) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 商品名称
          Text(
            product['name'],
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis, // 名称过长时省略
          ),
          const SizedBox(height: 4),
          // 商品价格
          Text(
            '¥${product['price'].toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          // 评分和评价数
          Row(
            children: [
              const Icon(Icons.star, color: Colors.yellow, size: 14),
              const SizedBox(width: 2),
              Text(
                '${product['rating']}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 8),
              Text(
                '${product['reviewCount']}条评价',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 页面导航通用方法
  /// 统一页面跳转逻辑，提升代码可维护性
  void _navigateToPage(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }
}
