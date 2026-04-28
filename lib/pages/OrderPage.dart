import 'package:flutter/material.dart';
import '../models/OrderModel.dart';
import '../services/OrderService.dart';

/// 我的订单页面
class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  List<OrderModel> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  // 加载订单列表
  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final orders = await OrderService.getOrders();
      setState(() {
        _orders = orders;
      });
    } catch (e) {
      print('加载订单失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 查看订单详情
  void _viewOrderDetail(OrderModel order) {
    // 这里可以跳转到订单详情页面
    // 暂时用对话框显示详情
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('订单详情'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('商品名称: ${order.productName}'),
              Text('订单金额: ¥${order.price.toStringAsFixed(2)}'),
              Text('下单时间: ${order.createTime}'),
              Text('订单状态: ${order.status}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的订单'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('暂无订单'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                return _buildOrderItem(order);
              },
            ),
    );
  }

  // 构建订单项
  Widget _buildOrderItem(OrderModel order) {
    return GestureDetector(
      onTap: () => _viewOrderDetail(order),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 订单时间
            Text(order.createTime, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            // 商品信息
            Row(
              children: [
                // 商品图片
                Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[200],
                  child: Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Text(
                        '商品图片',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 商品信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '¥${order.price.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 订单状态
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '订单状态: ${order.status}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const Text('查看详情', style: TextStyle(color: Colors.blue)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
