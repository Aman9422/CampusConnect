import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/models/ai_interaction.dart';
import 'package:campusconnect/models/chat_message.dart';
import 'package:campusconnect/providers/ai_chat_provider.dart';
import 'package:campusconnect/providers/ai_usage_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/utilities/error_messages.dart';
import 'package:campusconnect/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// AIChatView - Extracted from monolithic NotesView
///
/// Phase 1 of NotesView decomposition: Clean, focused AI chat interface
/// with real-time conversation, eligibility intelligence, and usage tracking.
class AIChatView extends StatefulWidget {
  const AIChatView({super.key});

  @override
  State<AIChatView> createState() => _AIChatViewState();
}

class _AIChatViewState extends State<AIChatView> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiProvider = context.watch<AIUsageProvider>();
    final aiChatProvider = context.watch<AIChatProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'CampusConnect AI',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        // v8.8 (P5): Delete AI chat history action.
        actions: [
          if (aiChatProvider.messages.isNotEmpty)
            IconButton(
              tooltip: 'Delete chat history',
              icon: Icon(
                Icons.delete_outline,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
              onPressed: _handleDeleteHistory,
            ),
        ],
      ),
      body: Column(
        children: [
          // V5.1.x: Offline banner for AI chat
          OfflineBanner(isOffline: !aiProvider.isOnline),
          // v6.0: Modern trial warning banner
          if (aiProvider.isInTrial && aiProvider.daysRemainingInTrial <= 2)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: AppTheme.space12,
              ),
              decoration: AppTheme.bannerDecoration(AppTheme.warningBg),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_outlined,
                    size: 18,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Text(
                      aiProvider.daysRemainingInTrial == 1
                          ? 'AI trial expires tomorrow!'
                          : 'AI trial expires in ${aiProvider.daysRemainingInTrial} days',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.gray800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: aiChatProvider.messages.isEmpty
                ? _buildEmptyChatState()
                : ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: aiChatProvider.messages.length,
                    itemBuilder: (context, index) {
                      return _buildChatBubble(aiChatProvider.messages[index]);
                    },
                  ),
          ),
          if (aiChatProvider.isSending) _buildLoadingIndicator(),
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyChatState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.space24),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: AppTheme.shadowColored,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            Text(
              'CampusConnect AI',
              style: AppTheme.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              'Your personal AI mentor for academics and career guidance',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: isDark ? AppTheme.gray400 : AppTheme.gray600,
              ),
            ),
            const SizedBox(height: AppTheme.space32),
            Wrap(
              spacing: AppTheme.space8,
              runSpacing: AppTheme.space8,
              alignment: WrapAlignment.center,
              children: [
                // v6.5: Smart suggestion that uses eligibility engine
                _buildSuggestionChip('Which placements am I eligible for?'),
                _buildSuggestionChip('Improve my resume for ATS'),
                _buildSuggestionChip('Suggest my career path'),
                _buildSuggestionChip('Run a mock interview'),
                _buildSuggestionChip('Find my skill gaps'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _handleSendMessage(text),
      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space16,
          vertical: AppTheme.space12,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isDark ? AppTheme.gray600 : AppTheme.gray300,
            width: 1,
          ),
          boxShadow: isDark ? null : AppTheme.shadowSmall,
        ),
        child: Text(
          text,
          style: AppTheme.bodySmall.copyWith(
            color: isDark ? Colors.white : AppTheme.gray700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    return Align(
      alignment: message.isUserMessage
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.space12),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space16,
          vertical: AppTheme.space12,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: message.isUserMessage ? AppTheme.primaryGradient : null,
          color: message.isUserMessage ? null : AppTheme.gray100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppTheme.radiusLarge),
            topRight: const Radius.circular(AppTheme.radiusLarge),
            bottomLeft: Radius.circular(
              message.isUserMessage ? AppTheme.radiusLarge : AppTheme.space4,
            ),
            bottomRight: Radius.circular(
              message.isUserMessage ? AppTheme.space4 : AppTheme.radiusLarge,
            ),
          ),
          boxShadow: message.isUserMessage
              ? AppTheme.shadowColored
              : AppTheme.shadowSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: AppTheme.bodyMedium.copyWith(
                color: message.isUserMessage ? Colors.white : AppTheme.gray900,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.space4),
            Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: AppTheme.caption.copyWith(
                color: message.isUserMessage
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.gray600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Text(
            'AI is thinking...',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.gray600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aiProvider = context.watch<AIUsageProvider>();
    final aiChatProvider = context.watch<AIChatProvider>();
    final isDisabled =
        aiChatProvider.isSending ||
        !aiProvider.isOnline ||
        aiProvider.hasReachedLimit;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.gray700 : AppTheme.gray200,
            width: 1,
          ),
        ),
        boxShadow: isDark ? null : AppTheme.shadowSmall,
      ),
      child: Row(
        children: [
          // v6.7: Resume Review quick access button
          Tooltip(
            message: 'AI Resume Review',
            child: InkWell(
              onTap: () {
                Navigator.of(context).pushNamed(resumeReviewRoute);
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.gray800 : AppTheme.gray100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: AppTheme.success,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: TextField(
              controller: _chatController,
              enabled: !isDisabled,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              style: AppTheme.bodyMedium.copyWith(
                color: isDark ? Colors.white : AppTheme.gray900,
              ),
              decoration: InputDecoration(
                hintText: !aiProvider.isOnline
                    ? 'Offline - connect to send messages'
                    : aiProvider.hasReachedLimit
                    ? 'Daily limit reached'
                    : 'Ask me anything...',
                hintStyle: AppTheme.bodyMedium.copyWith(
                  color: isDark ? AppTheme.gray500 : AppTheme.gray500,
                ),
                filled: true,
                fillColor: isDark ? AppTheme.gray800 : AppTheme.gray50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide: BorderSide(
                    color: isDark ? AppTheme.gray700 : AppTheme.gray300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide: BorderSide(
                    color: isDark ? AppTheme.gray700 : AppTheme.gray300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide: BorderSide(color: AppTheme.gray200),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space16,
                  vertical: AppTheme.space12,
                ),
              ),
              onSubmitted: (_) => _handleSendMessage(_chatController.text),
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          Container(
            decoration: BoxDecoration(
              color: isDisabled ? AppTheme.gray300 : AppTheme.primaryBlue,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: isDisabled
                  ? null
                  : () => _handleSendMessage(_chatController.text),
              icon: Icon(
                Icons.send_rounded,
                color: isDisabled ? AppTheme.gray600 : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// v8.8 (P5): Delete the user's AI chat history.
  ///
  /// Destructive — requires explicit confirmation. Uses the auth UID via
  /// `AIChatProvider.deleteHistory` (server enforces ownership through
  /// `request.auth.uid`). Clears the in-memory chat only AFTER the server
  /// confirms, so the UI shows no stale messages.
  Future<void> _handleDeleteHistory() async {
    final aiChatProvider = context.read<AIChatProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete chat history?'),
        content: const Text(
          'This permanently deletes your entire AI chat history. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    if (aiChatProvider.isSending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for the current message to finish.'),
        ),
      );
      return;
    }

    final success = await aiChatProvider.deleteHistory();
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat history deleted.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not delete your chat history. Please try again later.',
          ),
        ),
      );
    }
  }

  Future<void> _handleSendMessage(String text) async {
    final message = text.trim();
    final aiChatProvider = context.read<AIChatProvider>();
    if (message.isEmpty || aiChatProvider.isSending) return;

    final userId = AuthService.firebase().currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
      return;
    }

    // V5.1.x: Network pre-flight guard
    final aiProvider = context.read<AIUsageProvider>();
    if (!aiProvider.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You're offline. Please reconnect and try again."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Clear input
    _chatController.clear();

    // Scroll to bottom
    _scrollToBottom();

    // v6.5: Check if this is an eligibility-related question
    final eligibilityResponse = _handleEligibilityQuestion(message);
    if (eligibilityResponse != null) {
      await aiChatProvider.addLocalExchange(
        userMessage: message,
        aiMessage: eligibilityResponse,
        intent: AIInteractionIntent.skillGap,
      );
      _scrollToBottom();
      return;
    }

    try {
      // Ensure provider is initialized for current user
      if (!aiChatProvider.isInitialized) {
        await aiChatProvider.initWithUser(userId);
      }

      // Call AI career assistant
      final aiResponse = await aiChatProvider.sendMessage(message);
      if (aiResponse == null) {
        _scrollToBottom();
        return;
      }

      // VERSION 4: Update provider with latest usage info
      if (aiResponse.trial != null) {
        aiProvider.updateTrialInfo(
          isInTrial: aiResponse.trial!.isActive,
          daysRemaining: aiResponse.trial!.daysRemaining,
        );
      }

      if (aiResponse.usage != null) {
        aiProvider.updateUsageInfo(
          messagesUsed: aiResponse.usage!.dailyCount,
          dailyLimit: aiResponse.usage!.dailyLimit,
        );
      }

      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      final friendlyError = ErrorMessages.getUserFriendlyMessage(e);
      await aiChatProvider.addLocalExchange(
        userMessage: message,
        aiMessage: 'Sorry, I couldn\'t process your message.\n\n$friendlyError',
      );
      _scrollToBottom();

      debugPrint('AI Chat error: $e');
    }
  }

  /// v6.5: Detect eligibility-related questions and answer from v6.5 intelligence
  String? _handleEligibilityQuestion(String message) {
    final lowerMessage = message.toLowerCase();

    // Detect eligibility intent
    final isEligibilityQuestion =
        lowerMessage.contains('eligible') ||
        lowerMessage.contains('eligibility') ||
        lowerMessage.contains('can i apply') ||
        lowerMessage.contains('qualify') ||
        (lowerMessage.contains('which') &&
            lowerMessage.contains('placement')) ||
        (lowerMessage.contains('what') &&
            lowerMessage.contains('placement') &&
            lowerMessage.contains('for me'));

    if (!isEligibilityQuestion) {
      return null; // Not an eligibility question, let AI handle it
    }

    // Get data from v6.5 intelligence
    final placementsProvider = context.read<PlacementsProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final profile = profileProvider.profile;

    if (profile == null) {
      return "I couldn't find your profile. Please complete your profile setup first to check placement eligibility.";
    }

    final eligiblePlacements = placementsProvider.eligiblePlacements;
    final allPlacements = placementsProvider.placements;

    if (allPlacements.isEmpty) {
      return "There are no active placements available right now. Check back later for new opportunities!";
    }

    if (eligiblePlacements.isEmpty) {
      // Build helpful response explaining why
      final buffer = StringBuffer();
      buffer.writeln(
        "Based on your profile, you're currently not eligible for any active placements.\n",
      );
      buffer.writeln("📋 Your Profile:");
      buffer.writeln("• Program: ${profile.academic.program}");
      buffer.writeln("• Year: ${profile.academic.year}");
      buffer.writeln("• CGPA: ${profile.academic.cgpa.toStringAsFixed(2)}\n");
      buffer.writeln("💡 Tips to unlock more opportunities:");
      buffer.writeln("• Keep improving your CGPA");
      buffer.writeln("• Build skills in high-demand areas");
      buffer.writeln("• Update your profile regularly\n");
      buffer.writeln(
        "Check the Placements tab to see all opportunities and their requirements.",
      );
      return buffer.toString();
    }

    // Build personalized response with eligible placements
    final buffer = StringBuffer();
    buffer.writeln(
      "🎯 Great news! Based on your profile, you're eligible for ${eligiblePlacements.length} placement${eligiblePlacements.length > 1 ? 's' : ''}:\n",
    );

    for (int i = 0; i < eligiblePlacements.length && i < 5; i++) {
      final placement = eligiblePlacements[i];
      final daysUntilDeadline = placement.deadline
          .difference(DateTime.now())
          .inDays;

      buffer.writeln("${i + 1}. ${placement.company} - ${placement.role}");
      buffer.writeln("   💰 ${placement.salary}");
      if (daysUntilDeadline <= 7) {
        buffer.writeln(
          "   ⚠️ Deadline: $daysUntilDeadline day${daysUntilDeadline != 1 ? 's' : ''} left!",
        );
      } else {
        buffer.writeln(
          "   📅 Deadline: ${DateFormat('MMM dd, yyyy').format(placement.deadline)}",
        );
      }
      buffer.writeln("");
    }

    if (eligiblePlacements.length > 5) {
      buffer.writeln("...and ${eligiblePlacements.length - 5} more!\n");
    }

    buffer.writeln("📋 Your Profile:");
    buffer.writeln("• Program: ${profile.academic.program}");
    buffer.writeln("• Year: ${profile.academic.year}");
    buffer.writeln("• CGPA: ${profile.academic.cgpa.toStringAsFixed(2)}\n");

    buffer.writeln("👉 Go to the Placements tab to apply!");

    return buffer.toString();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
