import 'package:flutter/material.dart';
import 'services/society_service.dart';

class AnalyticsDashboard extends StatefulWidget {
  final String societyName;
  final String userEmail;
  final String? userAuthToken;

  const AnalyticsDashboard({
    super.key,
    required this.societyName,
    required this.userEmail,
    this.userAuthToken,
  });

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  late SocietyService _societyService;
  late Future<Map<String, dynamic>> _analyticsFuture;
  late Future<Map<String, dynamic>> _membersFuture;
  late Future<Map<String, dynamic>> _pollsFuture;

  @override
  void initState() {
    super.initState();
    _societyService = SocietyService();
    _analyticsFuture = _societyService.getReviewAnalytics(
      societyName: widget.societyName,
      viewerEmail: widget.userEmail,
      authToken: widget.userAuthToken,
    );
    _membersFuture = _societyService.getMembers(
      societyName: widget.societyName,
      viewerEmail: widget.userEmail,
    );
    _pollsFuture = _societyService.getPolls(
      societyName: widget.societyName,
      viewerEmail: widget.userEmail,
      authToken: widget.userAuthToken,
    );
  }

  String _monthLabel(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      return monthKey;
    }

    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${names[month - 1]} $year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.societyName} - Analytics',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _membersFuture,
        builder: (context, memberSnapshot) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _pollsFuture,
            builder: (context, pollSnapshot) {
              return FutureBuilder<Map<String, dynamic>>(
                future: _analyticsFuture,
                builder: (context, analyticsSnapshot) {
              if (memberSnapshot.connectionState == ConnectionState.waiting ||
                      pollSnapshot.connectionState == ConnectionState.waiting ||
                      analyticsSnapshot.connectionState ==
                          ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              // Extract member data
              int totalMembers = 0;
              int adminCount = 0;
              if (memberSnapshot.hasData &&
                  memberSnapshot.data!['success'] == true) {
                final List<dynamic> members =
                    memberSnapshot.data!['members'] as List<dynamic>? ?? [];
                totalMembers = members.length;
                adminCount = members
                    .where((m) => (m as Map<String, dynamic>)['role'] == 'admin')
                    .length;
              }

                  // Extract polls and info data
                  int totalPolls = 0;
                  int infoItemsCount = 0;
                  if (pollSnapshot.hasData &&
                      pollSnapshot.data!['success'] == true) {
                    final List<dynamic> polls =
                        pollSnapshot.data!['polls'] as List<dynamic>? ?? [];
                    final List<dynamic> infoItems =
                        pollSnapshot.data!['info_items'] as List<dynamic>? ?? [];
                    totalPolls = polls.length;
                    infoItemsCount = infoItems.length;
                  }

              // Extract analytics data
              if (!analyticsSnapshot.hasData ||
                  analyticsSnapshot.data!['success'] != true) {
                // Show member stats even if analytics fail
                    return _buildMembersOnlyView(
                      context,
                      totalMembers,
                      adminCount,
                      totalPolls,
                      infoItemsCount,
                    );
              }

              final analyticsData = analyticsSnapshot.data!;
              final List<dynamic> rawTrends =
                  analyticsData['trends'] as List<dynamic>? ?? [];
              final trends = rawTrends
                  .map((item) => item as Map<String, dynamic>)
                  .map(_TrendData.fromJson)
                  .toList();

              if (trends.isEmpty) {
                // Show members and empty reviews state
                    return _buildMembersAndEmptyReviewsView(
                      context,
                      totalMembers,
                      adminCount,
                      totalPolls,
                      infoItemsCount,
                    );
              }

              // Show full dashboard with both reviews and members
              return _buildFullDashboard(
                context,
                trends,
                totalMembers,
                adminCount,
                    totalPolls,
                    infoItemsCount,
              );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMembersOnlyView(
    BuildContext context,
    int totalMembers,
    int adminCount,
    int totalPolls,
    int infoItemsCount,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Society Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _StatCard(
                label: 'Total Members',
                value: '$totalMembers',
                icon: Icons.people_outline,
                color: Colors.blue,
              ),
              _StatCard(
                label: 'Admins',
                value: '$adminCount',
                icon: Icons.admin_panel_settings_outlined,
                color: Colors.purple,
              ),
              _StatCard(
                label: 'Active Polls',
                value: '$totalPolls',
                icon: Icons.poll_outlined,
                color: Colors.orange,
              ),
              _StatCard(
                label: 'Announcements',
                value: '$infoItemsCount',
                icon: Icons.announcement_outlined,
                color: Colors.teal,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                const Text(
                  'No review data yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Reviews will appear here once members start submitting them.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersAndEmptyReviewsView(
    BuildContext context,
    int totalMembers,
    int adminCount,
    int totalPolls,
    int infoItemsCount,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Society Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _StatCard(
                label: 'Total Members',
                value: '$totalMembers',
                icon: Icons.people_outline,
                color: Colors.blue,
              ),
              _StatCard(
                label: 'Admins',
                value: '$adminCount',
                icon: Icons.admin_panel_settings_outlined,
                color: Colors.purple,
              ),
              _StatCard(
                label: 'Active Polls',
                value: '$totalPolls',
                icon: Icons.poll_outlined,
                color: Colors.orange,
              ),
              _StatCard(
                label: 'Announcements',
                value: '$infoItemsCount',
                icon: Icons.announcement_outlined,
                color: Colors.teal,
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Review Analytics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                const Text(
                  'No review data available yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Reviews will appear here once members start submitting them.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullDashboard(
    BuildContext context,
    List<_TrendData> trends,
    int totalMembers,
    int adminCount,
    int totalPolls,
    int infoItemsCount,
  ) {
    // Calculate overall statistics
    final totalReviews = trends.fold<int>(
      0,
      (sum, trend) => sum + trend.reviewCount,
    );
    final avgRating = trends.isEmpty
        ? 0.0
        : trends.fold<double>(
              0,
              (sum, trend) => sum + (trend.avgRating * trend.reviewCount),
            ) /
            totalReviews;
    final highestRating = trends
        .map((t) => t.avgRating)
        .reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Society Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _StatCard(
                label: 'Total Members',
                value: '$totalMembers',
                icon: Icons.people_outline,
                color: Colors.blue,
              ),
              _StatCard(
                label: 'Admins',
                value: '$adminCount',
                icon: Icons.admin_panel_settings_outlined,
                color: Colors.purple,
              ),
              _StatCard(
                label: 'Active Polls',
                value: '$totalPolls',
                icon: Icons.poll_outlined,
                color: Colors.orange,
              ),
              _StatCard(
                label: 'Announcements',
                value: '$infoItemsCount',
                icon: Icons.announcement_outlined,
                color: Colors.teal,
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Review Analytics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
            children: [
              _StatCard(
                label: 'Total Reviews',
                value: '$totalReviews',
                icon: Icons.rate_review_outlined,
                color: Colors.blue,
              ),
              _StatCard(
                label: 'Avg Rating',
                value: avgRating.toStringAsFixed(1),
                icon: Icons.star_outline,
                color: Colors.amber,
              ),
              _StatCard(
                label: 'Highest Rating',
                value: highestRating.toStringAsFixed(1),
                icon: Icons.trending_up_outlined,
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Monthly Trends
          const Text(
            'Monthly Trends',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24,
                columns: const [
                  DataColumn(
                    label: Text('Month'),
                  ),
                  DataColumn(
                    label: Text('Avg Rating'),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text('Reviews'),
                    numeric: true,
                  ),
                ],
                rows: trends
                    .map(
                      (trend) => DataRow(
                        cells: [
                          DataCell(
                            Text(
                              _monthLabel(trend.month),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              trend.avgRating.toStringAsFixed(2),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${trend.reviewCount}',
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Visual trend bar chart
          const Text(
            'Review Count by Month',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _TrendChart(trends: trends, monthLabel: _monthLabel),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withAlpha(255),
              color.withAlpha(200),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<_TrendData> trends;
  final String Function(String) monthLabel;

  const _TrendChart({
    required this.trends,
    required this.monthLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (trends.isEmpty) {
      return const Center(
        child: Text('No data available'),
      );
    }

    final maxReviews =
        trends.map((t) => t.reviewCount).reduce((a, b) => a > b ? a : b);
    final chartHeight = 200.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: trends
              .map(
                (trend) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 40,
                        height: (trend.reviewCount / maxReviews) * chartHeight,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${trend.reviewCount}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        monthLabel(trend.month),
                        style: const TextStyle(
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _TrendData {
  final String month;
  final double avgRating;
  final int reviewCount;

  const _TrendData({
    required this.month,
    required this.avgRating,
    required this.reviewCount,
  });

  factory _TrendData.fromJson(Map<String, dynamic> json) {
    return _TrendData(
      month: (json['month'] as String?) ?? '',
      avgRating: ((json['avg_rating'] as num?) ?? 0).toDouble(),
      reviewCount: (json['review_count'] as int?) ?? 0,
    );
  }
}
