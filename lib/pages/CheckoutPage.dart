import 'package:flutter/material.dart';
import 'dart:math';
import 'PaymentResultPage.dart';
import '../models/CartItem.dart';
import '../models/OrderModel.dart';
import '../services/CartService.dart';
import '../services/OrderService.dart';

/// 订单确认/结算页面
class CheckoutPage extends StatefulWidget {
  final CartItem? singleItem; // 立即购买时的单个商品

  const CheckoutPage({super.key, this.singleItem});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  List<CartItem> _cartItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  // 加载购物车商品
  Future<void> _loadCartItems() async {
    setState(() {
      _isLoading = true;
    });
    try {
      if (widget.singleItem != null) {
        // 立即购买模式
        _cartItems = [widget.singleItem!];
      } else {
        // 购物车结算模式
        _cartItems = await CartService.getCartItems();
      }
    } catch (e) {
      print('加载购物车商品失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 计算总价
  double _calculateTotal() {
    return _cartItems.fold(0.0, (total, item) => total + item.totalPrice);
  }

  // 提交订单
  void _submitOrder() {
    // 遍历购物车商品，创建订单
    for (final item in _cartItems) {
      // 生成订单 ID
      final orderId = 'order_${Random().nextInt(99999999)}';

      // 创建订单模型
      final order = OrderModel(
        id: orderId,
        productName: item.name,
        price: item.totalPrice,
        createTime: DateTime.now().toString(),
        status: '已完成',
      );

      // 保存订单到本地存储
      OrderService.addOrder(order);
    }

    // 跳转到支付结果页面
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PaymentResultPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('订单确认'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cartItems.isEmpty
          ? const Center(child: Text('购物车为空'))
          : Column(
              children: [
                // 收货信息模块
                _buildAddressSection(),
                // 商品列表
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      return _buildCartItem(item);
                    },
                  ),
                ),
                // 总价和提交按钮
                _buildCheckoutSection(),
              ],
            ),
    );
  }

  // 构建收货信息模块
  Widget _buildAddressSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '收货信息',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('用户名称  138****8888'),
                    SizedBox(height: 4),
                    Text('北京市朝阳区'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建购物车商品项
  Widget _buildCartItem(CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        children: [
          // 商品图片
          Container(
            width: 80,
            height: 80,
            color: Colors.grey[200],
            child: Image.network(
              item.imageUrl,
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
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '¥${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.red),
                      ),
                      Text('x${item.quantity}'),
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

  // 构建结算区域
  Widget _buildCheckoutSection() {
    final total = _calculateTotal();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('总计'),
              Text(
                '¥${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _submitOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '提交订单',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
