import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/routing/app_router.dart';
import '../../../shared/models/queue_ticket.dart';
import '../../../shared/models/salon.dart';
import '../data/queue_repository.dart';

/// Live queue tracking screen for customer displaying their digital token ticket.
/// Redesigned to match the Home, Bookings and Profile design system:
/// Clean white background, dark navy typography, purple accents, rounded cards and live metrics.
class CustomerQueueScreen extends StatefulWidget {
  final QueueTicket ticket;
  final Salon? salon;
  final VoidCallback? onBack;

  const CustomerQueueScreen({
    super.key,
    required this.ticket,
    this.salon,
    this.onBack,
  });

  @override
  State<CustomerQueueScreen> createState() => _CustomerQueueScreenState();
}

class _CustomerQueueScreenState extends State<CustomerQueueScreen> {
  final QueueRepository _queueRepo = QueueRepository();
  late QueueTicket _currentTicket;
  StreamSubscription<QueueTicket?>? _ticketSub;
  StreamSubscription<List<QueueTicket>>? _salonQueueSub;
  bool _cancelling = false;
  bool _hasShownTurnAlert = false;
  bool _hasShownRatingDialog = false;

  int _currentPosition = 1;
  int _peopleAhead = 0;
  int _estWaitMinutes = 15;

  @override
  void initState() {
    super.initState();
    _currentTicket = widget.ticket;
    _subscribeToStreams();
  }

  void _subscribeToStreams() {
    // 1. Stream the specific ticket by its ID for live updates (WAITING -> IN_CHAIR -> COMPLETED)
    _ticketSub = _queueRepo
        .streamTicket(_currentTicket.id)
        .listen(
          (updated) {
            if (updated != null && mounted) {
              final previousStatus = _currentTicket.status;
              setState(() {
                _currentTicket = updated;
                if (updated.status == QueueStatus.completed) {
                  _currentPosition = 0;
                  _peopleAhead = 0;
                  _estWaitMinutes = 0;
                }
              });

              // Check if called to chair
              if (updated.status == QueueStatus.inChair &&
                  previousStatus == QueueStatus.waiting &&
                  !_hasShownTurnAlert) {
                _hasShownTurnAlert = true;
                HapticFeedback.heavyImpact();
                _showTurnCalledAlert(updated.chairNumber ?? 1);
              }

              // Check if completed
              if (updated.status == QueueStatus.completed &&
                  !_hasShownRatingDialog) {
                _hasShownRatingDialog = true;
                HapticFeedback.mediumImpact();
                _showRatingDialog();
              }
            }
          },
          onError: (err) {
            debugPrint('[CustomerQueueScreen] streamTicket error: $err');
          },
        );

    // 2. Stream salon's full queue to compute exact live position & people ahead
    _salonQueueSub = _queueRepo
        .streamLiveQueueForSalon(_currentTicket.salonId)
        .listen(
          (tickets) {
            if (!mounted) return;
            final waiting = tickets
                .where((t) => t.status == QueueStatus.waiting)
                .toList();
            waiting.sort((a, b) => a.tokenNumber.compareTo(b.tokenNumber));

            final myIndex = waiting.indexWhere(
              (t) =>
                  t.id == _currentTicket.id ||
                  t.tokenNumber == _currentTicket.tokenNumber,
            );
            final chairs = widget.salon?.activeChairs ?? 3;
            final effectiveChairs = chairs > 0 ? chairs : 1;

            setState(() {
              if (_currentTicket.status == QueueStatus.completed ||
                  _currentTicket.status == QueueStatus.inChair) {
                _currentPosition = 0;
                _peopleAhead = 0;
                _estWaitMinutes = 0;
              } else if (myIndex != -1) {
                _currentPosition = myIndex + 1;
                _peopleAhead = myIndex;
                _estWaitMinutes = (_peopleAhead * (20 / effectiveChairs))
                    .round();
              }
            });
          },
          onError: (err) {
            debugPrint(
              '[CustomerQueueScreen] streamLiveQueueForSalon error: $err',
            );
          },
        );
  }

  void _showTurnCalledAlert(int chairNum) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🎉 '),
            Text(
              'It\'s Your Turn!',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFF3E8FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_seat_rounded,
                size: 44,
                color: Color(0xFF6D28D9),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please proceed to Chair #$chairNum.',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your stylist is ready to start your grooming service.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6D28D9),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'I am Sitting Now',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog() {
    int rating = 5;
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Rate Your Experience',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How was your grooming service today?',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (idx) {
                  final starIndex = idx + 1;
                  return IconButton(
                    icon: Icon(
                      starIndex <= rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: const Color(0xFFF59E0B),
                      size: 32,
                    ),
                    onPressed: () => setModalState(() => rating = starIndex),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                decoration: InputDecoration(
                  labelText: 'Feedback (Optional)',
                  hintText: 'Great haircut, friendly stylist!',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                AppRouter.navigateToCustomerEntry(context);
              },
              child: const Text(
                'Skip',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you for rating your visit! ⭐'),
                    backgroundColor: Color(0xFF6D28D9),
                  ),
                );
                AppRouter.navigateToCustomerEntry(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D28D9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Submit Review',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ticketSub?.cancel();
    _salonQueueSub?.cancel();
    super.dispose();
  }

  Future<void> _handleCancelTicket() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Leave Queue?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        content: const Text(
          'Are you sure you want to cancel your digital token? You will lose your spot in line.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'No, Stay in Line',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Yes, Cancel Token',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _cancelling = true);
    await _queueRepo.cancelTicket(_currentTicket.id);

    if (!mounted) return;
    setState(() => _cancelling = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your queue token has been cancelled.'),
        backgroundColor: Color(0xFFEF4444),
      ),
    );

    AppRouter.navigateToCustomerEntry(context);
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    } else {
      AppRouter.navigateToCustomerEntry(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final salonName = widget.salon?.name ?? 'Salon Queue';
    final salonAddress = widget.salon?.address ?? 'Customer Location';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Top Header ──────────────────────────────────────────────
              _buildTopHeader(),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    // ── 2. Prominent Digital Token Card ──────────────────────
                    _buildActiveTokenCard(salonName, salonAddress),

                    const SizedBox(height: 16),

                    // ── 3. Live Position & Estimated Wait Metrics ───────────
                    _buildLiveMetricsRow(),

                    const SizedBox(height: 16),

                    // ── 4. Queue Progress Stepper ───────────────────────────
                    _buildQueueProgressCard(),

                    const SizedBox(height: 16),

                    // ── 5. Selected Services & Price Summary ────────────────
                    _buildServicesSummaryCard(),

                    const SizedBox(height: 20),

                    // ── 6. Action Button: Cancel / Leave Queue ──────────────
                    if (_currentTicket.isWaiting)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _cancelling ? null : _handleCancelTicket,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                          label: Text(
                            _cancelling
                                ? 'Cancelling...'
                                : 'Cancel / Leave Queue',
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFFFCA5A5),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Header ─────────────────────────────────────────────────────────────
  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Circular Back Button
          GestureDetector(
            onTap: _handleBack,
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

          // Centered Header Title
          const Column(
            children: [
              Text(
                'My Queue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Live Queue Token',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),

          // Spacer to balance
          const SizedBox(width: 42, height: 42),
        ],
      ),
    );
  }

  // ── Active Token Card ──────────────────────────────────────────────────────
  Widget _buildActiveTokenCard(String salonName, String salonAddress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF5A1F), // Vibrant Orange
            Color(0xFFE91E63), // Pink
            Color(0xFF6D28D9), // Deep Purple
          ],
          stops: [0.0, 0.45, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D28D9).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: Tag + Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'YOUR QUEUE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _currentTicket.status.label.toUpperCase(),
                  style: TextStyle(
                    color: _currentTicket.status.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Big Token Number (#A-21)
          Text(
            _currentTicket.formattedToken,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currentTicket.customerName,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),

          // Divider
          Container(height: 1, color: Colors.white.withValues(alpha: 0.25)),
          const SizedBox(height: 12),

          // Salon Name & Location
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      salonName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      salonAddress,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Live Position & Estimated Wait Metrics ─────────────────────────────────
  Widget _buildLiveMetricsRow() {
    return Row(
      children: [
        // Current Position Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.format_list_numbered_rounded,
                      size: 16,
                      color: Color(0xFF6D28D9),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'CURRENT POSITION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _currentTicket.isCompleted
                      ? 'Completed 🎉'
                      : (_currentTicket.isInChair
                            ? 'In Chair #${_currentTicket.chairNumber ?? 1}'
                            : 'Position #$_currentPosition in Line'),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _currentTicket.isCompleted
                      ? 'Finished'
                      : (_currentTicket.isInChair
                            ? 'Stylist attending you'
                            : (_peopleAhead == 0
                                  ? 'You are next!'
                                  : '$_peopleAhead ahead of you')),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _currentTicket.isCompleted || _peopleAhead == 0
                        ? const Color(0xFF15803D)
                        : const Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Estimated Wait Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: Color(0xFF6D28D9),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'ESTIMATED WAIT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _currentTicket.isCompleted
                      ? 'Completed'
                      : (_currentTicket.isInChair
                            ? 'In Chair'
                            : '~$_estWaitMinutes mins'),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6D28D9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _currentTicket.isCompleted
                      ? 'All done'
                      : (_currentTicket.isInChair
                            ? 'In progress'
                            : 'Live estimate'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Queue Progress Stepper ─────────────────────────────────────────────────
  Widget _buildQueueProgressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Queue Progress',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          _buildProgressStep(
            title: 'Token Confirmed',
            subtitle: 'You are in the queue line',
            isDone: true,
            isCurrent: _currentTicket.isWaiting,
          ),
          _buildProgressStep(
            title: 'Almost Your Turn',
            subtitle: 'Please arrive at the salon counter',
            isDone: _currentTicket.isInChair || _currentTicket.isCompleted,
            isCurrent: _currentTicket.isWaiting && _peopleAhead <= 1,
          ),
          _buildProgressStep(
            title: 'In Chair / Service Started',
            subtitle: _currentTicket.chairNumber != null
                ? 'Chair #${_currentTicket.chairNumber}'
                : 'Stylist attending you',
            isDone: _currentTicket.isCompleted,
            isCurrent: _currentTicket.isInChair,
          ),
          _buildProgressStep(
            title: 'Completed',
            subtitle: 'Grooming finished',
            isDone: _currentTicket.isCompleted,
            isCurrent: _currentTicket.isCompleted,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep({
    required String title,
    required String subtitle,
    required bool isDone,
    required bool isCurrent,
    bool isLast = false,
  }) {
    final color = isDone
        ? const Color(0xFF6D28D9)
        : (isCurrent ? const Color(0xFF6D28D9) : const Color(0xFFD1D5DB));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? color : Colors.transparent,
                border: Border.all(color: color, width: 2),
              ),
              child: isDone
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : (isCurrent
                        ? Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                              ),
                            ),
                          )
                        : null),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isDone
                    ? const Color(0xFF6D28D9)
                    : const Color(0xFFE5E7EB),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: isDone || isCurrent
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: isDone || isCurrent
                      ? const Color(0xFF111827)
                      : const Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  // ── Selected Services & Price Summary ──────────────────────────────────────
  Widget _buildServicesSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selected Services',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          ...(_currentTicket.serviceNames.map(
            (svc) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: Color(0xFF15803D),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      svc,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )),
          const Divider(height: 24, color: Color(0xFFF3F4F6)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Est. Duration: ~${_currentTicket.totalDurationMinutes} mins',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Total: ₹${_currentTicket.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Color(0xFF6D28D9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
