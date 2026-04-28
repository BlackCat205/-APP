class ReviewModel {
  final String orderId;
  final String productId;
  final String productName;
  final String productImage;
  final String reviewContent;
  final DateTime reviewTime;
  final int rating;

  const ReviewModel({
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.reviewContent,
    required this.reviewTime,
    required this.rating,
  });
}