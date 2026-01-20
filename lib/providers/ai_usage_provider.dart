import 'package:campusconnect/services/ai/ai_service.dart';
import 'package:flutter/foundation.dart';

/// V5: Centralized AI usage state
/// Tracks trial status, quota, and usage
class AIUsageProvider with ChangeNotifier {
  final String userId;

  AIUsageProvider({required AIService aiService, required this.userId});

  // State
  bool _isInTrial = false;
  int _daysRemainingInTrial = 0;
  int _messagesUsedToday = 0;
  int _dailyLimit = 50;
  bool _isLoading = false;
  String? _error;

  // Getters
  bool get isInTrial => _isInTrial;
  int get daysRemainingInTrial => _daysRemainingInTrial;
  int get messagesUsedToday => _messagesUsedToday;
  int get dailyLimit => _dailyLimit;
  int get messagesRemaining => dailyLimit - messagesUsedToday;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasReachedLimit => messagesUsedToday >= dailyLimit;

  /// Initialize: Load AI usage data
  Future<void> init() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // In V5, we'll fetch usage data from backend
      // For now, set defaults
      _isInTrial = true;
      _daysRemainingInTrial = 5;
      _messagesUsedToday = 0;
      _dailyLimit = 50;
      _error = null;
    } catch (e) {
      _error = 'Failed to load AI usage data';
      debugPrint('AIUsageProvider init error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update usage after sending a message
  void incrementUsage() {
    _messagesUsedToday++;
    notifyListeners();
  }

  /// Update trial info from AI response
  void updateTrialInfo({required bool isInTrial, required int daysRemaining}) {
    _isInTrial = isInTrial;
    _daysRemainingInTrial = daysRemaining;
    notifyListeners();
  }

  /// Update usage info from AI response
  void updateUsageInfo({required int messagesUsed, required int dailyLimit}) {
    _messagesUsedToday = messagesUsed;
    _dailyLimit = dailyLimit;
    notifyListeners();
  }
}
