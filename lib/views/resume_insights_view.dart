import 'package:campusconnect/models/resume_review.dart';
import 'package:campusconnect/providers/resume_review_provider.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// CampusConnect v6.9 - Resume Intelligence Dashboard
///
/// Analytics and insights for resume review history:
/// - ATS score trend chart
/// - Monthly statistics
/// - Growth analysis
/// - Review comparison

class ResumeInsightsView extends StatefulWidget {
  const ResumeInsightsView({super.key});

  @override
  State<ResumeInsightsView> createState() => _ResumeInsightsViewState();
}

class _ResumeInsightsViewState extends State<ResumeInsightsView> {
  String? _selectedReview1;
  String? _selectedReview2;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.gray50,
      appBar: AppBar(
        title: const Text('Resume Insights'),
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<ResumeReviewProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingHistory) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.history.isEmpty) {
            return _buildEmptyState(isDark);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TrendChartCard(provider: provider),
                const SizedBox(height: AppTheme.space16),
                _StatisticsCard(provider: provider),
                const SizedBox(height: AppTheme.space16),
                _GrowthInsightsCard(provider: provider),
                if (provider.history.length >= 2) ...[
                  const SizedBox(height: AppTheme.space16),
                  _ComparisonSection(
                    provider: provider,
                    selectedReview1: _selectedReview1,
                    selectedReview2: _selectedReview2,
                    onReview1Changed: (id) =>
                        setState(() => _selectedReview1 = id),
                    onReview2Changed: (id) =>
                        setState(() => _selectedReview2 = id),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insights_outlined,
            size: 80,
            color: isDark ? AppTheme.gray600 : AppTheme.gray400,
          ),
          const SizedBox(height: AppTheme.space24),
          Text(
            'No Insights Yet',
            style: AppTheme.titleLarge.copyWith(
              color: isDark ? Colors.white : AppTheme.gray900,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            'Submit resume reviews to see analytics',
            style: AppTheme.bodyMedium.copyWith(
              color: isDark ? AppTheme.gray400 : AppTheme.gray600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Trend Chart Card
// ============================================================================

class _TrendChartCard extends StatelessWidget {
  final ResumeReviewProvider provider;

  const _TrendChartCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sorted = provider.sortedHistory;

    return Card(
      elevation: 0,
      color: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: AppTheme.primaryBlue, size: 24),
                const SizedBox(width: AppTheme.space8),
                Text(
                  'ATS Score Trend',
                  style: AppTheme.titleMedium.copyWith(
                    color: isDark ? Colors.white : AppTheme.gray900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space24),
            SizedBox(
              height: 200,
              child: sorted.isEmpty
                  ? _buildNoDataMessage(isDark)
                  : _buildChart(sorted, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataMessage(bool isDark) {
    return Center(
      child: Text(
        'No review data yet',
        style: AppTheme.bodyMedium.copyWith(
          color: isDark ? AppTheme.gray500 : AppTheme.gray400,
        ),
      ),
    );
  }

  Widget _buildChart(List<ResumeReviewHistory> sorted, bool isDark) {
    final spots = sorted.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.atsScore.toDouble());
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDark ? AppTheme.gray700 : AppTheme.gray200,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: AppTheme.bodySmall.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= sorted.length)
                  return const SizedBox();

                final date = sorted[index].createdAt;
                final label = DateFormat('M/d').format(date);

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    label,
                    style: AppTheme.bodySmall.copyWith(
                      color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryBlue.withOpacity(0.8),
                AppTheme.primaryBlue,
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: AppTheme.primaryBlue,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue.withOpacity(0.2),
                  AppTheme.primaryBlue.withOpacity(0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Statistics Card
// ============================================================================

class _StatisticsCard extends StatelessWidget {
  final ResumeReviewProvider provider;

  const _StatisticsCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
                const SizedBox(width: AppTheme.space8),
                Text(
                  'Statistics',
                  style: AppTheme.titleMedium.copyWith(
                    color: isDark ? Colors.white : AppTheme.gray900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space20),
            _StatRow(
              label: 'Average Score',
              value: provider.averageScore.toStringAsFixed(1),
              icon: Icons.bar_chart,
              isDark: isDark,
            ),
            const SizedBox(height: AppTheme.space12),
            _StatRow(
              label: 'Highest Score',
              value: provider.highestScore.toString(),
              icon: Icons.arrow_upward,
              isDark: isDark,
              valueColor: AppTheme.success,
            ),
            const SizedBox(height: AppTheme.space12),
            _StatRow(
              label: 'Lowest Score',
              value: provider.lowestScore.toString(),
              icon: Icons.arrow_downward,
              isDark: isDark,
              valueColor: AppTheme.warning,
            ),
            const SizedBox(height: AppTheme.space12),
            _StatRow(
              label: 'Total Reviews',
              value: provider.totalReviews.toString(),
              icon: Icons.history,
              isDark: isDark,
            ),
            const SizedBox(height: AppTheme.space12),
            _StatRow(
              label: 'Reviews This Month',
              value: provider.reviewsThisMonth.toString(),
              icon: Icons.calendar_today,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;
  final Color? valueColor;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? AppTheme.gray400 : AppTheme.gray600,
        ),
        const SizedBox(width: AppTheme.space12),
        Expanded(
          child: Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              color: isDark ? AppTheme.gray300 : AppTheme.gray700,
            ),
          ),
        ),
        Text(
          value,
          style: AppTheme.titleMedium.copyWith(
            color: valueColor ?? (isDark ? Colors.white : AppTheme.gray900),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Growth Insights Card
// ============================================================================

class _GrowthInsightsCard extends StatelessWidget {
  final ResumeReviewProvider provider;

  const _GrowthInsightsCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analysis = provider.generateGrowthAnalysis();

    return Card(
      elevation: 0,
      color: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
                const SizedBox(width: AppTheme.space8),
                Text(
                  'Growth Insights',
                  style: AppTheme.titleMedium.copyWith(
                    color: isDark ? Colors.white : AppTheme.gray900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space16),
            ...analysis.insights.map(
              (insight) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: Text(
                        insight,
                        style: AppTheme.bodyMedium.copyWith(
                          color: isDark ? AppTheme.gray300 : AppTheme.gray700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Comparison Section
// ============================================================================

class _ComparisonSection extends StatelessWidget {
  final ResumeReviewProvider provider;
  final String? selectedReview1;
  final String? selectedReview2;
  final ValueChanged<String?> onReview1Changed;
  final ValueChanged<String?> onReview2Changed;

  const _ComparisonSection({
    required this.provider,
    required this.selectedReview1,
    required this.selectedReview2,
    required this.onReview1Changed,
    required this.onReview2Changed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.compare_arrows,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
                const SizedBox(width: AppTheme.space8),
                Text(
                  'Compare Reviews',
                  style: AppTheme.titleMedium.copyWith(
                    color: isDark ? Colors.white : AppTheme.gray900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space16),
            _ReviewDropdown(
              label: 'First Review',
              value: selectedReview1,
              items: provider.history,
              onChanged: onReview1Changed,
              isDark: isDark,
            ),
            const SizedBox(height: AppTheme.space12),
            _ReviewDropdown(
              label: 'Second Review',
              value: selectedReview2,
              items: provider.history,
              onChanged: onReview2Changed,
              isDark: isDark,
            ),
            if (selectedReview1 != null && selectedReview2 != null) ...[
              const SizedBox(height: AppTheme.space20),
              _buildComparison(provider, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComparison(ResumeReviewProvider provider, bool isDark) {
    final comparison = provider.compareReviews(
      selectedReview1!,
      selectedReview2!,
    );

    if (comparison == null) {
      return Text(
        'Unable to compare selected reviews',
        style: AppTheme.bodyMedium.copyWith(
          color: isDark ? AppTheme.gray400 : AppTheme.gray600,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: isDark ? AppTheme.gray700 : AppTheme.gray200),
        const SizedBox(height: AppTheme.space16),
        _ComparisonRow(
          label: 'Score Difference',
          value: comparison.scoreDifference >= 0
              ? '+${comparison.scoreDifference}'
              : '${comparison.scoreDifference}',
          icon: comparison.scoreDifference >= 0
              ? Icons.trending_up
              : Icons.trending_down,
          valueColor: comparison.scoreDifference >= 0
              ? AppTheme.success
              : AppTheme.error,
          isDark: isDark,
        ),
        const SizedBox(height: AppTheme.space12),
        _ComparisonRow(
          label: 'Strengths Added',
          value: comparison.addedStrengths.length.toString(),
          icon: Icons.add_circle_outline,
          isDark: isDark,
        ),
        const SizedBox(height: AppTheme.space12),
        _ComparisonRow(
          label: 'Format Issues Resolved',
          value: comparison.resolvedFormatIssues >= 0
              ? comparison.resolvedFormatIssues.toString()
              : '0',
          icon: Icons.check_circle_outline,
          valueColor: comparison.resolvedFormatIssues > 0
              ? AppTheme.success
              : null,
          isDark: isDark,
        ),
        const SizedBox(height: AppTheme.space12),
        _ComparisonRow(
          label: 'Keyword Improvement',
          value: comparison.keywordImprovement >= 0
              ? '+${comparison.keywordImprovement}'
              : '${comparison.keywordImprovement}',
          icon: Icons.key,
          valueColor: comparison.keywordImprovement > 0
              ? AppTheme.success
              : comparison.keywordImprovement < 0
              ? AppTheme.error
              : null,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _ReviewDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<ResumeReviewHistory> items;
  final ValueChanged<String?> onChanged;
  final bool isDark;

  const _ReviewDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: isDark ? AppTheme.gray400 : AppTheme.gray600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkBackground : AppTheme.gray50,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: isDark ? AppTheme.gray700 : AppTheme.gray300,
            ),
          ),
          child: DropdownButton<String>(
            value: value,
            hint: Text(
              'Select a review',
              style: AppTheme.bodyMedium.copyWith(
                color: isDark ? AppTheme.gray500 : AppTheme.gray500,
              ),
            ),
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
            items: items.map((review) {
              final date = DateFormat('MMM d, y').format(review.createdAt);
              final label =
                  '${review.targetRole ?? "General"} - $date (${review.atsScore})';

              return DropdownMenuItem<String>(
                value: review.id,
                child: Text(
                  label,
                  style: AppTheme.bodyMedium.copyWith(
                    color: isDark ? Colors.white : AppTheme.gray900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;
  final Color? valueColor;

  const _ComparisonRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? AppTheme.gray400 : AppTheme.gray600,
        ),
        const SizedBox(width: AppTheme.space12),
        Expanded(
          child: Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              color: isDark ? AppTheme.gray300 : AppTheme.gray700,
            ),
          ),
        ),
        Text(
          value,
          style: AppTheme.titleSmall.copyWith(
            color: valueColor ?? (isDark ? Colors.white : AppTheme.gray900),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
