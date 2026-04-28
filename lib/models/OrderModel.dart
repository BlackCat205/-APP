/// 订单模型
class OrderModel {
  final String id;
  final String productName;
  final double price;
  final String createTime;
  final String status;

  OrderModel({
    required this.id,
    required this.productName,
    required this.price,
    required this.createTime,
    required this.status,
  });

  // 转Map（用于JSON序列化）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productName': productName,
      'price': price,
      'createTime': createTime,
      'status': status,
    };
  }

  // 从Map还原（用于JSON反序列化）
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      createTime: json['createTime'] as String? ?? '',
      status: json['status'] as String? ?? "已完成",
    );
  }
}
