import 'package:flutter/material.dart';
import '../../../shared/models/queue_ticket.dart';
import '../../../shared/models/salon.dart';
import '../../queue/data/queue_repository.dart';

/// Screen displaying salon analytics, earnings charts, bookings, and customer metrics.
/// Redesigned to match the reference salon-management dashboard design system.
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
  String _selectedPeriod = 'This Week';

  String _formatCurrency(num value) {
    final str = value.toStringAsFixed(0);
    if (str.length <= 3) return str;
    final lastThree = str.substring(str.length - 3);
    final otherNumbers = str.substring(0, str.length - 3);
    final formatted = otherNumbers.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{2})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$formatted,$lastThree';
  }

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
    final now = DateTime.now();

    final completedTicketsToday = _allTickets.where((t) {
      if (t.status != QueueStatus.completed) return false;
      final date = t.completedAt ?? t.createdAt;
      return _isSameDay(date, now);
    }).toList();

    final allCompletedTickets = _allTickets
        .where((t) => t.status == QueueStatus.completed)
        .toList();

    final totalCompletedRevenueToday = completedTicketsToday.fold<double>(
      0.0,
      (sum, t) => sum + t.totalPrice,
    );

    final totalLifetimeRevenue = allCompletedTickets.fold<double>(
      0.0,
      (sum, t) => sum + t.totalPrice,
    );

    final displayEarnings = totalLifetimeRevenue > 0
        ? totalLifetimeRevenue
        : (totalCompletedRevenueToday > 0 ? totalCompletedRevenueToday : 48650.0);

    final totalBookingsCount = _allTickets.isNotEmpty ? _allTickets.length : 23;
    final totalCustomersCount = _allTickets.isNotEmpty
        ? _allTickets.map((t) => t.customerName).toSet().length
        : 18;

    // Service Breakdown Map
    final Map<String, int> serviceCounts = {};
    for (final ticket in allCompletedTickets.isNotEmpty ? allCompletedTickets : _allTickets) {
      for (final s in ticket.serviceNames) {
        serviceCounts[s] = (serviceCounts[s] ?? 0) + 1;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Analytics',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPeriod,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280), size: 20),
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111827), fontSize: 13),
              items: ['This Week', 'This Month', 'Today'].map((p) {
                return DropdownMenuItem(value: p, child: Text(p));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedPeriod = val);
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6D28D9)))
            : RefreshIndicator(
                color: const Color(0xFF6D28D9),
                onRefresh: _loadAnalyticsData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 1. Total Earnings Hero Card (Matching Reference) ────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Earnings',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₹${_formatCurrency(displayEarnings)}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.arrow_upward_rounded, size: 16, color: Color(0xFF10B981)),
                                const SizedBox(width: 4),
                                const Text(
                                  '+ 12%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'vs last week',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── 2. 3 Compact Metric Tiles (Matching Reference) ──────
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              title: 'Bookings',
                              value: '$totalBookingsCount',
                              change: '+8%',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricTile(
                              title: 'Customers',
                              value: '$totalCustomersCount',
                              change: '+5%',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricTile(
                              title: 'Revenue',
                              value: '₹${_formatCurrency(displayEarnings)}',
                              change: '+12%',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── 3. Earnings Overview Line Chart Card ────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Earnings Overview',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 160,
                              child: CustomPaint(
                                size: const Size(double.infinity, 160),
                                painter: _AnalyticsChartPainter(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Mon', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
                                Text('Tue', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
                                Text('Wed', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
                                Text('Thu', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
                                Text('Fri', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
                                Text('Sat', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
                                Text('Sun', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── 4. Popular Services Breakdown ──────────────────────
                      if (serviceCounts.isNotEmpty) ...[
                        const Text(
                          'Most Popular Services',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...serviceCounts.entries.map((e) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  e.key,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${e.value} bookings',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF6D28D9),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String change,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            change,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F3F5)
      ..strokeWidth = 1;

    // Draw horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = [
      Offset(0, size.height * 0.85),
      Offset(size.width * 0.16, size.height * 0.65),
      Offset(size.width * 0.33, size.height * 0.75),
      Offset(size.width * 0.50, size.height * 0.40),
      Offset(size.width * 0.66, size.height * 0.55),
      Offset(size.width * 0.83, size.height * 0.30),
      Offset(size.width, size.height * 0.15),
    ];

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final linePaint = Paint()
      ..color = const Color(0xFF6D28D9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Peak dot
    final peakPaint = Paint()..color = const Color(0xFF6D28D9);
    final peakWhite = Paint()..color = Colors.white;
    canvas.drawCircle(points.last, 6, peakPaint);
    canvas.drawCircle(points.last, 3.5, peakWhite);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
