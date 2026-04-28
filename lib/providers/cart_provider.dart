import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      quantity: map['quantity'],
      imageUrl: map['imageUrl'],
    );
  }
}

class CartProvider extends ChangeNotifier {
  List<CartItem> _items = [];
  static const String _cartKey = 'cart_items';

  List<CartItem> get items => _items;

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount {
    return _items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  Future<void> loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartData = prefs.getStringList(_cartKey);

    if (cartData != null) {
      _items = cartData.map((item) {
        final map = Uri.splitQueryString(item);
        return CartItem(
          id: map['id'] ?? '',
          name: map['name'] ?? '',
          price: double.tryParse(map['price'] ?? '0') ?? 0.0,
          quantity: int.tryParse(map['quantity'] ?? '0') ?? 0,
          imageUrl: map['imageUrl'] ?? '',
        );
      }).toList();
      notifyListeners();
    }
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartData = _items.map((item) {
      return 'id=${item.id}&name=${Uri.encodeComponent(item.name)}&price=${item.price}&quantity=${item.quantity}&imageUrl=${Uri.encodeComponent(item.imageUrl)}';
    }).toList();
    await prefs.setStringList(_cartKey, cartData);
  }

  void addItem(CartItem cartItem) {
    final existingIndex = _items.indexWhere((item) => item.id == cartItem.id);

    if (existingIndex >= 0) {
      // 如果商品已存在，增加数量
      _items[existingIndex] = CartItem(
        id: _items[existingIndex].id,
        name: _items[existingIndex].name,
        price: _items[existingIndex].price,
        quantity: _items[existingIndex].quantity + 1,
        imageUrl: _items[existingIndex].imageUrl,
      );
    } else {
      // 如果商品不存在，添加新商品
      _items.add(
        CartItem(
          id: cartItem.id,
          name: cartItem.name,
          price: cartItem.price,
          quantity: 1,
          imageUrl: cartItem.imageUrl,
        ),
      );
    }

    _saveCart();
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item.id == productId);
    _saveCart();
    notifyListeners();
  }

  void updateQuantity(String productId, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(productId);
    } else {
      final existingIndex = _items.indexWhere((item) => item.id == productId);
      if (existingIndex >= 0) {
        _items[existingIndex] = CartItem(
          id: _items[existingIndex].id,
          name: _items[existingIndex].name,
          price: _items[existingIndex].price,
          quantity: newQuantity,
          imageUrl: _items[existingIndex].imageUrl,
        );
        _saveCart();
        notifyListeners();
      }
    }
  }

  void clearCart() {
    _items.clear();
    _saveCart();
    notifyListeners();
  }
}
