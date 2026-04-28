import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/DeviceModel.dart';
import 'DeviceDetailPage.dart';

/// 商品收藏页面
/// 显示用户收藏的所有商品，支持查看、取消收藏
class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  // 收藏的商品列表
  List<Map<String, dynamic>> _favoriteProducts = [];
  // 是否正在加载
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 加载收藏的商品
    _loadFavorites();
  }

  // 加载收藏的商品
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoriteIds = prefs.getStringList('favorites') ?? [];
      
      // 从MallPage的products列表中获取收藏的商品
      // 这里需要从MallPage导入products列表，或者使用全局的商品数据源
      // 为了简化，我们直接使用一个模拟的商品列表
      final List<Map<String, dynamic>> allProducts = [
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
          'name': '智能风扇',
          'description': '蓝牙控制智能风扇，多档风速调节',
          'price': 149.0,
          'imageUrl':
              'https://neeko-copilot.bytedance.net/api/text2image?prompt=smart%20bluetooth%20fan&size=square',
          'rating': 4.7,
          'reviewCount': 98,
        },
        {
          'id': 'prod4',
          'name': '香薰蜡烛',
          'description': '天然大豆蜡香薰蜡烛，持久留香',
          'price': 89.0,
          'imageUrl':
              'https://neeko-copilot.bytedance.net/api/text2image?prompt=aromatherapy%20candle&size=square',
          'rating': 4.6,
          'reviewCount': 156,
        },
      ];
      
      // 筛选出收藏的商品
      _favoriteProducts = allProducts.where((product) => favoriteIds.contains(product['id'])).toList();
    } catch (e) {
      print('加载收藏失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 取消收藏
  Future<void> _removeFromFavorites(String productId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoriteIds = prefs.getStringList('favorites') ?? [];
      
      // 移除商品ID
      favoriteIds.remove(productId);
      await prefs.setStringList('favorites', favoriteIds);
      
      // 更新UI
      setState(() {
        _favoriteProducts.removeWhere((product) => product['id'] == productId);
      });
      
      // 显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已取消收藏')),
      );
    } catch (e) {
      print('取消收藏失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('取消收藏失败')),
      );
    }
  }

  // 跳转到商品详情页
  void _navigateToDetail(BuildContext context, Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceDetailPage(
          device: DeviceModel.fromJson(product),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('商品收藏'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteProducts.isEmpty
              ? const Center(child: Text('暂无收藏商品'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _favoriteProducts.length,
                  itemBuilder: (context, index) {
                    final product = _favoriteProducts[index];
                    return _buildFavoriteItem(context, product);
                  },
                ),
    );
  }

  // 构建收藏商品项
  Widget _buildFavoriteItem(BuildContext context, Map<String, dynamic> product) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
      child: Row(
        children: [
          // 商品图片
          Container(
            width: 100,
            height: 100,
            color: Colors.grey[200],
            child: Image.network(
              product['imageUrl'],
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
          ),
          // 商品信息
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product['description'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '¥${product['price'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.favorite, color: Colors.red),
                        onPressed: () => _removeFromFavorites(product['id']),
                        tooltip: '取消收藏',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
