import 'package:flutter/material.dart';
import '../models/ReviewModel.dart';

class ReviewProvider extends ChangeNotifier {
  List<ReviewModel> _reviews = [];

  List<ReviewModel> get reviews => _reviews;

  void addReview(ReviewModel review) {
    _reviews.add(review);
    notifyListeners();
  }

  bool hasReviewed(String orderId) {
    return _reviews.any((review) => review.orderId == orderId);
  }

  List<ReviewModel> getReviewsByProductId(String productId) {
    return _reviews.where((review) => review.productId == productId).toList();
  }

  void clearReviews() {
    _reviews.clear();
    notifyListeners();
  }
}