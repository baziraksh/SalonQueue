import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../shared/models/queue_ticket.dart';
import '../../../shared/models/salon.dart';
import '../../auth/services/auth_scope.dart';
import '../../queue/data/queue_repository.dart';
import '../../queue/screens/customer_queue_screen.dart';
import '../../salon/data/salon_repository.dart';

/// Screen displaying customer's Bookings (Upcoming & Completed)
/// Redesigned to match the reference booking page design with modern cards and tabs.
class CustomerHistoryScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const CustomerHistoryScreen({super.key, this.onBack});

  static void clearCache() {
    _CustomerHistoryScreenState._cachedTickets.clear();
    _CustomerHistoryScreenState._cachedSalonMap.clear();
    _CustomerHistoryScreenState._lastFetchTime = null;
  }

  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  final QueueRepository _queueRepo = QueueRepository();
  final SalonRepository _salonRepo = SalonRepository();

  // Static persistent cache for instant frame-1 display
  static List<QueueTicket> _cachedTickets = [];
  static final Map<String, Salon> _cachedSalonMap = {};
  static DateTime? _lastFetchTime;

  int _selectedTabIndex = 0; // 0 = Upcoming, 1 = Completed
  List<QueueTicket> _allTickets = [];
  final Map<String, Salon> _salonMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 1. Instantly display cached data if available (0ms delay)
    if (_cachedTickets.isNotEmpty) {
      _allTickets = List.from(_cachedTickets);
      _salonMap.addAll(_cachedSalonMap);
      _isLoading = false;
    }
    _loadHistory();
  }

  Future<void> _loadHistory({bool force = false}) async {
    // Avoid redundant rapid network fetches if data was fetched recently (< 15 seconds)
    if (!force && _allTickets.isNotEmpty && _lastFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchTime!);
      if (elapsed.inSeconds < 15) {
        if (_isLoading && mounted) setState(() => _isLoading = false);
        return;
      }
    }

    if (_allTickets.isEmpty) {
      setState(() => _isLoading = true);
    }

    final auth = AuthScope.of(context, listen: false);
    final userId = auth.currentUser?.id ?? '';

    try {
      final list = await _queueRepo.fetchCustomerHistory(userId);
      _cachedTickets = list;
      _lastFetchTime = DateTime.now();

      // Check synchronous cache first for all salon IDs (0ms)
      final salonIds = list.map((t) => t.salonId).toSet();
      final cachedSalons = _salonRepo.getCachedSalons();
      for (final s in cachedSalons) {
        if (salonIds.contains(s.id)) {
          _salonMap[s.id] = s;
          _cachedSalonMap[s.id] = s;
        }
      }

      if (!mounted) return;
      setState(() {
        _allTickets = list;
        _isLoading = false;
      });

      // Concurrently resolve any remaining missing salons in the background without blocking UI
      final missingSalonIds =
          salonIds.where((id) => !_salonMap.containsKey(id)).toList();
      if (missingSalonIds.isNotEmpty) {
        Future.wait(
          missingSalonIds.map((id) => _salonRepo.fetchSalonById(id)),
        ).then((salons) {
          if (!mounted) return;
          bool hasNew = false;
          for (final s in salons) {
            if (s != null) {
              _salonMap[s.id] = s;
              _cachedSalonMap[s.id] = s;
              hasNew = true;
            }
          }
          if (hasNew) setState(() {});
        }).catchError((_) {});
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
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
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $hour:$min $period';
  }

  @override
  Widget build(BuildContext context) {
    final upcomingTickets = _allTickets
        .where(
          (t) =>
              t.status == QueueStatus.waiting ||
              t.status == QueueStatus.inChair,
        )
        .toList();
    final completedTickets = _allTickets
        .where(
          (t) =>
              t.status != QueueStatus.waiting &&
              t.status != QueueStatus.inChair,
        )
        .toList();

    final currentList = _selectedTabIndex == 0
        ? upcomingTickets
        : completedTickets;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── 1. Top Header ──────────────────────────────────────────────
            _buildTopHeader(),

            // ── 2. Booking Tabs (Upcoming / Completed) ────────────────────
            _buildTabs(
              upcomingCount: upcomingTickets.length,
              completedCount: completedTickets.length,
            ),

            const SizedBox(height: 12),

            // ── 3. Cards List / Empty State / Skeleton Loader ──────────────
            Expanded(
              child: _isLoading && _allTickets.isEmpty
                  ? _buildSkeletonBookingsList()
                  : RefreshIndicator(
                      color: const Color(0xFF6D28D9),
                      onRefresh: () => _loadHistory(force: true),
                      child: currentList.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: currentList.length,
                              itemBuilder: (context, idx) {
                                final ticket = currentList[idx];
                                return _buildBookingCard(
                                  ticket,
                                  isUpcoming: _selectedTabIndex == 0,
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lightweight skeleton loader for instant Bookings page structure on cold start
  Widget _buildSkeletonBookingsList() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: 3,
      itemBuilder: (context, idx) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 110,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 90,
                          height: 11,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        Container(
                          width: 50,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 1. Top Header ──────────────────────────────────────────────────────────
  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Circular Back Button
          GestureDetector(
            onTap: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF111827),
                size: 18,
              ),
            ),
          ),

          // Centered Title
          const Text(
            'My Bookings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.3,
            ),
          ),

          // Spacer to balance
          const SizedBox(width: 42, height: 42),
        ],
      ),
    );
  }

  // ── 2. Booking Tabs (Upcoming vs Completed) ────────────────────────────────
  Widget _buildTabs({required int upcomingCount, required int completedCount}) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          _buildTabItem(title: 'Upcoming', index: 0, count: upcomingCount),
          _buildTabItem(title: 'Completed', index: 1, count: completedCount),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String title,
    required int index,
    required int count,
  }) {
    final isSelected = _selectedTabIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF6D28D9)
                      : const Color(0xFF6B7280),
                ),
              ),
            ),
            // Bottom Indicator
            Container(
              height: 3,
              width: 100,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6D28D9)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. Booking Card (Exact layout matching Reference Screenshot) ───────────
  Widget _buildBookingCard(QueueTicket ticket, {required bool isUpcoming}) {
    final salon = _salonMap[ticket.salonId];
    final salonName = (salon != null && salon.name.isNotEmpty)
        ? salon.name
        : (ticket.customerName.isNotEmpty ? 'Salon' : 'Salon Queue');
    final serviceTitle = ticket.serviceNames.isNotEmpty
        ? ticket.serviceNames.join(', ')
        : 'Haircut & Styling';
    final formattedDateTime = _formatDate(ticket.createdAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Salon Image on the Left with rounded corners
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 86,
              height: 86,
              color: const Color(0xFF1E293B),
              child: _buildSalonImage(salon?.effectiveCoverImage),
            ),
          ),
          const SizedBox(width: 14),

          // 2. Middle & Right Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top line: Salon Name + Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        salonName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isUpcoming
                            ? const Color(0xFFF3E8FF)
                            : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isUpcoming ? 'Upcoming' : 'Completed',
                        style: TextStyle(
                          color: isUpcoming
                              ? const Color(0xFF6D28D9)
                              : const Color(0xFF15803D),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Middle: Service Name
                Text(
                  serviceTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Bottom line: Booking Date/Time + View Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        formattedDateTime,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _viewTicketDetails(ticket, salon),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'View',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6D28D9),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalonImage(String? imagePath) {
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        return Image.network(
          imagePath,
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return _buildFallbackSalonImage();
          },
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackSalonImage(),
        );
      } else if (imagePath.startsWith('data:image')) {
        try {
          final base64Str = imagePath.split(',').last;
          final bytes = base64Decode(base64Str);
          return Image.memory(bytes, fit: BoxFit.cover);
        } catch (_) {
          return _buildFallbackSalonImage();
        }
      }
    }
    return _buildFallbackSalonImage();
  }

  Widget _buildFallbackSalonImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.storefront_rounded,
          color: Color(0xFFD4AF5A),
          size: 28,
        ),
      ),
    );
  }

  // ── 4. View Ticket Details Action ──────────────────────────────────────────
  void _viewTicketDetails(QueueTicket ticket, Salon? salon) {
    if (ticket.status == QueueStatus.waiting ||
        ticket.status == QueueStatus.inChair) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => CustomerQueueScreen(ticket: ticket, salon: salon),
            ),
          )
          .then((_) => _loadHistory());
    } else {
      _showCompletedTicketSummary(ticket, salon);
    }
  }

  void _showCompletedTicketSummary(QueueTicket ticket, Salon? salon) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  salon?.name ?? 'Salon Visit Receipt',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Token Number',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        ticket.formattedToken,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6D28D9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        ticket.status.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ticket.status.color,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Services',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          ticket.serviceNames.join(', '),
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '₹${ticket.totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D28D9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. Empty State ─────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    final isUpcoming = _selectedTabIndex == 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF3E8FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUpcoming
                    ? Icons.calendar_today_rounded
                    : Icons.history_rounded,
                size: 38,
                color: const Color(0xFF6D28D9),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isUpcoming ? 'No Upcoming Bookings' : 'No Completed Bookings',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isUpcoming
                  ? 'Your active tokens and scheduled salon slots will appear here.'
                  : 'Your past salon visits and completed tickets will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            if (isUpcoming) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D28D9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Explore Salons',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
