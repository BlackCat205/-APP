import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/OrderModel.dart';

/// 订单服务类，处理订单的存储和获取
class OrderService {
  static const String _ordersKey = 'orders';

  /// 添加订单
  static Future<bool> addOrder(OrderModel order) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. 从 SharedPreferences 读取现有订单（字符串）
      final String ordersJsonStr = prefs.getString(_ordersKey) ?? '[]';
      
      // 2. 解析为 List<dynamic>
      List<dynamic> ordersList = [];
      try {
        ordersList = jsonDecode(ordersJsonStr) as List<dynamic>;
      } catch (e) {
        print('解析订单数据失败，使用空列表: $e');
        ordersList = [];
      }
      
      // 3. 添加新订单（转换为 Map）
      ordersList.add(order.toJson());
      
      // 4. 转换为 JSON 字符串
      final String updatedOrdersJsonStr = jsonEncode(ordersList);
      
      // 5. 保存回 SharedPreferences
      await prefs.setString(_ordersKey, updatedOrdersJsonStr);
      
      print('添加订单成功: ${order.id}');
      return true;
    } catch (e) {
      print('添加订单失败: $e');
      return false;
    }
  }

  /// 获取所有订单
  static Future<List<OrderModel>> getOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. 从 SharedPreferences 读取订单（字符串）
      final String ordersJsonStr = prefs.getString(_ordersKey) ?? '[]';
      
      // 2. 解析为 List<dynamic>
      List<dynamic> ordersList = [];
      try {
        ordersList = jsonDecode(ordersJsonStr) as List<dynamic>;
      } catch (e) {
        print('解析订单数据失败，返回空列表: $e');
        return [];
      }
      
      // 3. 转换为 List<OrderModel>
      final List<OrderModel> orders = [];
      for (final orderMap in ordersList) {
        if (orderMap is Map<String, dynamic>) {
          try {
            orders.add(OrderModel.fromJson(orderMap));
          } catch (e) {
            print('转换订单数据失败: $e');
          }
        }
      }
      
      print('获取订单成功，共 ${orders.length} 条');
      return orders;
    } catch (e) {
      print('获取订单失败: $e');
      return [];
    }
  }

  /// 保存订单列表
  static Future<bool> saveOrders(List<OrderModel> orders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. 将订单列表转换为 Map 列表
      final List<Map<String, dynamic>> ordersMapList = orders.map((order) => order.toJson()).toList();
      
      // 2. 转换为 JSON 字符串
      final String ordersJsonStr = jsonEncode(ordersMapList);
      
      // 3. 保存到 SharedPreferences
      await prefs.setString(_ordersKey, ordersJsonStr);
      
      print('保存订单成功，共 ${orders.length} 条');
      return true;
    } catch (e) {
      print('保存订单失败: $e');
      return false;
    }
  }

  /// 根据 ID 获取订单
  static Future<OrderModel?> getOrderById(String id) async {
    try {
      final orders = await getOrders();
      final filteredOrders = orders.where((order) => order.id == id).toList();
      return filteredOrders.isNotEmpty ? filteredOrders.first : null;
    } catch (e) {
      print('获取订单详情失败: $e');
      return null;
    }
  }

  /// 清除所有订单
  static Future<bool> clearOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ordersKey, '[]');
      print('清除订单成功');
      return true;
    } catch (e) {
      print('清除订单失败: $e');
      return false;
    }
  }
}
