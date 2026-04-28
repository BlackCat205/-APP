import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class OrderItem {
  final String id;
  final String scentSetId;
  final String scentSetName;
  final double price;
  final DateTime purchaseTime;
  final String status;
  final String imageUrl;

  OrderItem({
    required this.id,
    required this.scentSetId,
    required this.scentSetName,
    required this.price,
    required this.purchaseTime,
    required this.status,
    required this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scentSetId': scentSetId,
      'scentSetName': scentSetName,
      'price': price,
      'purchaseTime': purchaseTime.toIso8601String(),
      'status': status,
      'imageUrl': imageUrl,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as String,
      scentSetId: map['scentSetId'] as String,
      scentSetName: map['scentSetName'] as String,
      price: (map['price'] as num).toDouble(),
      purchaseTime: DateTime.parse(map['purchaseTime'] as String),
      status: map['status'] as String,
      imageUrl: map['imageUrl'] as String,
    );
  }
}

class OrderProvider extends ChangeNotifier {
  List<OrderItem> _orders = [];
  static const String _ordersKey = 'orders';

  List<OrderItem> get orders => _orders;

  OrderProvider() {
    loadOrders();
  }

  Future<void> loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final ordersData = prefs.getStringList(_ordersKey);

    if (ordersData != null) {
      _orders = ordersData.map((item) {
        final map = jsonDecode(item) as Map<String, dynamic>;
        return OrderItem.fromMap(map);
      }).toList();

      _orders.sort((a, b) => b.purchaseTime.compareTo(a.purchaseTime));
      notifyListeners();
    }
  }

  Future<void> addOrder({
    required String scentSetId,
    required String scentSetName,
    required double price,
    required String imageUrl,
  }) async {
    final orderId = 'order_${DateTime.now().millisecondsSinceEpoch}';
    final order = OrderItem(
      id: orderId,
      scentSetId: scentSetId,
      scentSetName: scentSetName,
      price: price,
      purchaseTime: DateTime.now(),
      status: '已购买',
      imageUrl: imageUrl,
    );

    _orders.insert(0, order);
    _orders.sort((a, b) => b.purchaseTime.compareTo(a.purchaseTime));
    notifyListeners();
    await _saveOrders();
  }

  Future<void> removeOrder(String orderId) async {
    _orders.removeWhere((order) => order.id == orderId);
    notifyListeners();
    await _saveOrders();
  }

  Future<void> clearOrders() async {
    _orders.clear();
    notifyListeners();
    await _saveOrders();
  }

  Future<void> _saveOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final ordersData = _orders
        .map((order) => jsonEncode(order.toMap()))
        .toList();
    await prefs.setStringList(_ordersKey, ordersData);
  }

  bool hasPurchased(String scentSetId) {
    return _orders.any((order) => order.scentSetId == scentSetId);
  }
}
