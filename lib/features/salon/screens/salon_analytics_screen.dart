import 'package:flutter/material.dart';
import '../../../shared/models/queue_ticket.dart';
import '../../../shared/models/salon.dart';
import '../../queue/data/queue_repository.dart';

/// Screen displaying salon daily revenue, customers served, and service insights.
class SalonAnalyticsScreen extends StatefulWidget {
  const SalonAnalyticsScreen({
    super.key,
    required this.salon,
    this.tickets = const [],
  });

  final Salon salon;
  final List<QueueTicket> tickets;

  @override
  State<SalonAnalyticsScreen> createState() => _SalonAnalyticsScreenState();
}

class _SalonAnalyticsScreenState extends State<SalonAnalyticsScreen> {
  final QueueRepository _queueRepo = QueueRepository();
  List<QueueTicket> _allTickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    try {
      final fetched = await _queueRepo.fetchAllTicketsForSalon(widget.salon.id);
      if (!mounted) return;
      setState(() {
        _allTickets = fetched.isNotEmpty ? fetched : widget.tickets;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allTickets = widget.tickets;
        _isLoading = false;
      });
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    // 1. Separate by status and date
    final completedTicketsToday = _allTickets.where((t) {
      if (t.status != QueueStatus.completed) return false;
      final date = t.completedAt ?? t.createdAt;
      return _isSameDay(date, now);
    }).toList();

    final allCompletedTickets = _allTickets
        .where((t) => t.status == QueueStatus.completed)
        .toList();
    final inChairTickets = _allTickets
        .where((t) => t.status == QueueStatus.inChair)
        .toList();
    final waitingTickets = _allTickets
        .where((t) => t.status == QueueStatus.waiting)
        .toList();

    final totalCompletedRevenueToday = completedTicketsToday.fold<double>(
      0.0,
      (sum, t) => sum + t.totalPrice,
    );

    final totalLifetimeRevenue = allCompletedTickets.fold<double>(
      0.0,
      (sum, t) => sum + t.totalPrice,
    );

    final totalExpectedRevenueToday = _allTickets
        .where((t) {
          final date = t.completedAt ?? t.createdAt;
          return _isSameDay(date, now);
        })
        .fold<double>(0.0, (sum, t) => sum + t.totalPrice);

    final avgTicketValueToday = completedTicketsToday.isNotEmpty
        ? (totalCompletedRevenueToday / completedTicketsToday.length)
        : 0.0;

    // Service Breakdown Map
    final Map<String, int> serviceCounts = {};
    for (final ticket
        in completedTicketsToday.isNotEmpty
            ? completedTicketsToday
            : allCompletedTickets) {
      for (final s in ticket.serviceNames) {
        serviceCounts[s] = (serviceCounts[s] ?? 0) + 1;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Business Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalyticsData,
            tooltip: 'Refresh Analytics',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAnalyticsData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.salon.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Today Summary & Performance',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Total Collected Revenue Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF2E7D32,
                              ).withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'COLLECTED REVENUE TODAY',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '₹${totalCompletedRevenueToday.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Avg Ticket: ₹${avgTicketValueToday.toStringAsFixed(0)} • Lifetime: ₹${totalLifetimeRevenue.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            if (totalExpectedRevenueToday >
                                totalCompletedRevenueToday) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Potential Today (incl. In-Chair/Waiting): ₹${totalExpectedRevenueToday.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Customer Metric Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Completed Cuts',
                              value: completedTicketsToday.length.toString(),
                              icon: Icons.check_circle_outline,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'In Chair Now',
                              value: inChairTickets.length.toString(),
                              icon: Icons.chair_alt,
                              color: const Color(0xFF14243A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Waiting in Line',
                              value: waitingTickets.length.toString(),
                              icon: Icons.hourglass_empty,
                              color: const Color(0xFFE65100),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Popular Services Breakdown
                      Text(
                        'Top Requested Services',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (serviceCounts.isEmpty)
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(
                              child: Text('No service records yet today.'),
                            ),
                          ),
                        )
                      else
                        ...serviceCounts.entries.map((entry) {
                          final totalTokens = completedTicketsToday.isNotEmpty
                              ? completedTicketsToday.length
                              : (allCompletedTickets.isNotEmpty
                                    ? allCompletedTickets.length
                                    : 1);
                          final percentage = (entry.value / totalTokens).clamp(
                            0.0,
                            1.0,
                          );

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        '${entry.value} orders (${(percentage * 100).toStringAsFixed(0)}%)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.primary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: percentage,
                                    backgroundColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    color: const Color(0xFF6750A4),
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
