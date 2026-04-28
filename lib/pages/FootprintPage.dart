import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/DeviceModel.dart';
import 'DeviceDetailPage.dart';

/// 商品足迹页面
/// 显示用户最近浏览过的商品记录
class FootprintPage extends StatefulWidget {
  const FootprintPage({super.key});

  @override
  State<FootprintPage> createState() => _FootprintPageState();
}

class _FootprintPageState extends State<FootprintPage> {
  // 浏览记录列表
  List<Map<String, dynamic>> _footprints = [];
  // 是否正在加载
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 加载浏览记录
    _loadFootprints();
  }

  // 加载浏览记录
  Future<void> _loadFootprints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final footprintIds = prefs.getStringList('footprints') ?? [];

      // 从MallPage的products列表中获取浏览过的商品
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

      // 筛选出浏览过的商品，并保持顺序
      _footprints = footprintIds
          .map(
            (id) => allProducts.firstWhere(
              (product) => product['id'] == id,
              orElse: () => {},
            ),
          )
          .where((product) => product.isNotEmpty)
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      print('加载浏览记录失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 清空浏览记录
  Future<void> _clearFootprints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('footprints');

      // 更新UI
      setState(() {
        _footprints = [];
      });

      // 显示提示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已清空浏览记录')));
    } catch (e) {
      print('清空浏览记录失败: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('清空浏览记录失败')));
    }
  }

  // 跳转到商品详情页
  void _navigateToDetail(BuildContext context, Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DeviceDetailPage(device: DeviceModel.fromJson(product)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('商品足迹'),
        centerTitle: true,
        actions: [
          if (_footprints.isNotEmpty)
            TextButton(
              onPressed: _clearFootprints,
              child: const Text('清空', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _footprints.isEmpty
          ? const Center(child: Text('暂无浏览记录'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _footprints.length,
              itemBuilder: (context, index) {
                final product = _footprints[index];
                return _buildFootprintItem(context, product);
              },
            ),
    );
  }

  // 构建浏览记录项
  Widget _buildFootprintItem(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
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
                  Text(
                    '¥${product['price'].toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
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
