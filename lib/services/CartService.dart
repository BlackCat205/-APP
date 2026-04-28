import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/CartItem.dart';

/// 购物车服务
class CartService {
  static const String _cartKey = 'shopping_cart';

  /// 获取购物车商品列表
  static Future<List<CartItem>> getCartItems() async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString(_cartKey);
    if (cartJson == null) {
      return [];
    }
    try {
      final List<dynamic> cartList = jsonDecode(cartJson);
      return cartList.map((item) => CartItem.fromMap(item)).toList();
    } catch (e) {
      print('解析购物车数据失败: $e');
      return [];
    }
  }

  /// 添加商品到购物车
  static Future<bool> addToCart(CartItem item) async {
    try {
      final cartItems = await getCartItems();

      // 检查商品是否已在购物车中
      final existingItemIndex = cartItems.indexWhere(
        (cartItem) => cartItem.id == item.id,
      );

      if (existingItemIndex != -1) {
        // 商品已存在，增加数量
        cartItems[existingItemIndex].quantity += item.quantity;
      } else {
        // 商品不存在，添加新商品
        cartItems.add(item);
      }

      // 保存到本地存储
      final prefs = await SharedPreferences.getInstance();
      final cartJson = jsonEncode(
        cartItems.map((item) => item.toMap()).toList(),
      );
      return await prefs.setString(_cartKey, cartJson);
    } catch (e) {
      print('添加商品到购物车失败: $e');
      return false;
    }
  }

  /// 从购物车移除商品
  static Future<bool> removeFromCart(String itemId) async {
    try {
      final cartItems = await getCartItems();
      cartItems.removeWhere((item) => item.id == itemId);

      // 保存到本地存储
      final prefs = await SharedPreferences.getInstance();
      final cartJson = jsonEncode(
        cartItems.map((item) => item.toMap()).toList(),
      );
      return await prefs.setString(_cartKey, cartJson);
    } catch (e) {
      print('从购物车移除商品失败: $e');
      return false;
    }
  }

  /// 更新商品数量
  static Future<bool> updateQuantity(String itemId, int quantity) async {
    try {
      if (quantity <= 0) {
        return await removeFromCart(itemId);
      }

      final cartItems = await getCartItems();
      final existingItemIndex = cartItems.indexWhere(
        (cartItem) => cartItem.id == itemId,
      );

      if (existingItemIndex != -1) {
        cartItems[existingItemIndex].quantity = quantity;

        // 保存到本地存储
        final prefs = await SharedPreferences.getInstance();
        final cartJson = jsonEncode(
          cartItems.map((item) => item.toMap()).toList(),
        );
        return await prefs.setString(_cartKey, cartJson);
      }
      return false;
    } catch (e) {
      print('更新商品数量失败: $e');
      return false;
    }
  }

  /// 清空购物车
  static Future<bool> clearCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_cartKey);
    } catch (e) {
      print('清空购物车失败: $e');
      return false;
    }
  }

  /// 计算购物车总价
  static Future<double> getCartTotal() async {
    final cartItems = await getCartItems();
    double total = 0.0;
    for (var item in cartItems) {
      total += item.totalPrice;
    }
    return total;
  }

  /// 获取购物车商品数量
  static Future<int> getCartItemCount() async {
    final cartItems = await getCartItems();
    int count = 0;
    for (var item in cartItems) {
      count += item.quantity;
    }
    return count;
  }
}
