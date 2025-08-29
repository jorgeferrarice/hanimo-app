import 'dart:io';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InAppReviewService {
  static const String _lastReviewRequestKey = 'last_review_request';
  static const String _hasReviewedKey = 'has_reviewed';
  static const int _minDaysBetweenRequests = 10;
  static const int _animeCountForReview = 3;

  static final InAppReviewService _instance = InAppReviewService._internal();
  factory InAppReviewService() => _instance;
  InAppReviewService._internal();

  static InAppReviewService get instance => _instance;

  final InAppReview _inAppReview = InAppReview.instance;

  /// Check if the app is available for review
  Future<bool> isAvailable() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return await _inAppReview.isAvailable();
    }
    return false;
  }

  /// Request a review
  Future<void> requestReview() async {
    if (await isAvailable()) {
      await _inAppReview.requestReview();
      await _markReviewRequested();
    }
  }

  /// Open the app store page for review
  Future<void> openStoreListing() async {
    if (await isAvailable()) {
      await _inAppReview.openStoreListing();
    }
  }

  /// Check if user has already reviewed
  Future<bool> hasReviewed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasReviewedKey) ?? false;
  }

  /// Mark that user has reviewed
  Future<void> markAsReviewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasReviewedKey, true);
  }

  /// Check if enough time has passed since last review request
  Future<bool> canRequestReview() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRequest = prefs.getInt(_lastReviewRequestKey);
    
    if (lastRequest == null) return true;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final daysSinceLastRequest = (now - lastRequest) / (1000 * 60 * 60 * 24);
    
    return daysSinceLastRequest >= _minDaysBetweenRequests;
  }

  /// Mark that a review was requested
  Future<void> _markReviewRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastReviewRequestKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Check if should trigger review based on anime count
  Future<bool> shouldTriggerReview(int followedAnimeCount) async {
    // Don't trigger if user has already reviewed
    if (await hasReviewed()) return false;
    
    // Don't trigger if not enough time has passed
    if (!await canRequestReview()) return false;
    
    // Trigger on third anime and every subsequent anime after the cooldown period
    return followedAnimeCount >= _animeCountForReview;
  }

  /// Get the minimum anime count needed for review
  int get animeCountForReview => _animeCountForReview;
} 