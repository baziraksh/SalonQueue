import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/routing/app_router.dart';
import '../../../shared/models/queue_ticket.dart';
import '../../../shared/models/salon.dart';
import '../data/queue_repository.dart';

/// Live queue tracking screen for customer displaying their digital token ticket.
class CustomerQueueScreen extends StatefulWidget {
  const CustomerQueueScreen({
    super.key,
    required this.ticket,
    this.salon,
  });

  final QueueTicket ticket;
  final Salon? salon;

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
    _ticketSub = _queueRepo.streamTicket(_currentTicket.id).listen(
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
          if (updated.status == QueueStatus.completed && !_hasShownRatingDialog) {
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
        .listen((tickets) {
      if (!mounted) return;
      final waiting = tickets.where((t) => t.status == QueueStatus.waiting).toList();
      waiting.sort((a, b) => a.tokenNumber.compareTo(b.tokenNumber));

      final myIndex = waiting.indexWhere((t) => t.id == _currentTicket.id || t.tokenNumber == _currentTicket.tokenNumber);
      final chairs = widget.salon?.activeChairs ?? 3;
      final effectiveChairs = chairs > 0 ? chairs : 1;

      setState(() {
        if (_currentTicket.status == QueueStatus.completed || _currentTicket.status == QueueStatus.inChair) {
          _currentPosition = 0;
          _peopleAhead = 0;
          _estWaitMinutes = 0;
        } else if (myIndex != -1) {
          _currentPosition = myIndex + 1;
          _peopleAhead = myIndex;
          _estWaitMinutes = (_peopleAhead * (20 / effectiveChairs)).round();
        }
      });
    }, onError: (err) {
      debugPrint('[CustomerQueueScreen] streamLiveQueueForSalon error: $err');
    });
  }

  void _showTurnCalledAlert(int chairNum) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🎉 '),
            Text('It\'s Your Turn!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6750A4).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_seat, size: 48, color: Color(0xFF6750A4)),
            ),
            const SizedBox(height: 16),
            Text(
              'Please proceed to Chair #$chairNum.',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your stylist is ready to start your grooming service.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('I am Sitting Now'),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Rate Your Experience', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How was your grooming service today?', style: TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (idx) {
                  final starIndex = idx + 1;
                  return IconButton(
                    icon: Icon(
                      starIndex <= rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setModalState(() => rating = starIndex),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Feedback (Optional)',
                  hintText: 'Great haircut, friendly stylist!',
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
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you for rating your visit! ⭐'),
                    backgroundColor: Color(0xFF2E7D32),
                  ),
                );
                AppRouter.navigateToCustomerEntry(context);
              },
              child: const Text('Submit Review'),
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
        title: const Text('Leave Queue?'),
        content: const Text('Are you sure you want to cancel your digital token? You will lose your spot in line.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No, Stay in Line'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            child: const Text('Yes, Cancel Token'),
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
      const SnackBar(content: Text('Your queue token has been cancelled.')),
    );

    AppRouter.navigateToCustomerEntry(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final salonName = widget.salon?.name ?? 'Salon Queue Lounge';
    final salonAddress = widget.salon?.address ?? 'FC Road, Pune';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: const Text('Live Queue Token'),
        backgroundColor: const Color(0xFF14243A),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => AppRouter.navigateToCustomerEntry(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // ── 1. Digital Token Card ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF14243A), Color(0xFF1E3650)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFC9A45C), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF14243A).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'DIGITAL TOKEN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _currentTicket.status.color,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _currentTicket.status.label.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Big Token Number
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
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Divider(color: Colors.white24),
                    const SizedBox(height: 12),

                    // Salon Name & Info
                    Row(
                      children: [
                        const Icon(Icons.storefront, color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                salonName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                salonAddress,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 2. Live Queue Position & Wait Status Banner ───────────────
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.format_list_numbered_rounded, size: 16, color: Color(0xFF14243A)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'CURRENT POSITION',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.grey.shade600,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _currentTicket.isCompleted
                                ? 'Service Completed 🎉'
                                : (_currentTicket.isInChair
                                    ? 'In Chair #${_currentTicket.chairNumber ?? 1}'
                                    : 'Position #$_currentPosition in Line'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF14243A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currentTicket.isCompleted
                                ? 'All grooming services finished'
                                : (_currentTicket.isInChair
                                    ? 'Stylist currently attending you'
                                    : (_peopleAhead == 0 ? 'You are next!' : '$_peopleAhead customer(s) ahead of you')),
                            style: TextStyle(
                              fontSize: 11,
                              color: _currentTicket.isCompleted || _peopleAhead == 0
                                  ? const Color(0xFF2E7D32)
                                  : Colors.grey.shade600,
                              fontWeight: _currentTicket.isCompleted || _peopleAhead == 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 16,
                                color: _currentTicket.isCompleted
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC9A45C),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ESTIMATED WAIT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey.shade600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _currentTicket.isCompleted
                                ? 'Completed'
                                : (_currentTicket.isInChair
                                    ? 'Active Service'
                                    : '~$_estWaitMinutes mins'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: _currentTicket.isCompleted
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC9A45C),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currentTicket.isCompleted
                                ? 'Finished'
                                : (_currentTicket.isInChair
                                    ? 'In progress'
                                    : 'Live estimated time'),
                            style: TextStyle(
                              fontSize: 11,
                              color: _currentTicket.isCompleted
                                  ? const Color(0xFF2E7D32)
                                  : Colors.grey.shade600,
                              fontWeight: _currentTicket.isCompleted
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── 3. Queue Progress Stepper ─────────────────────────────────
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Status',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
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
                        isCurrent: _currentTicket.isWaiting && _currentTicket.tokenNumber <= 2,
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
                ),
              ),

              const SizedBox(height: 16),

              // ── 4. Completed Visit / Rate Stylist Action Card ─────────────
              if (_currentTicket.isCompleted)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 40),
                      const SizedBox(height: 8),
                      const Text(
                        'Service Completed Successfully!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thank you for visiting $salonName. We hope you enjoyed your service.',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showRatingDialog,
                              icon: const Icon(Icons.star_rounded, color: Color(0xFFC9A45C), size: 18),
                              label: const Text('Rate Stylist'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF14243A),
                                side: const BorderSide(color: Color(0xFFC9A45C)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => AppRouter.navigateToCustomerEntry(context),
                              icon: const Icon(Icons.home_rounded, size: 18),
                              label: const Text('Done / Home'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF14243A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              if (_currentTicket.isCompleted) const SizedBox(height: 16),

              // ── 5. Services & Amount Summary Card ─────────────────────────
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Services',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...(_currentTicket.serviceNames.map((svc) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                const Icon(Icons.check, size: 16, color: Color(0xFF2E7D32)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(svc, style: theme.textTheme.bodyMedium)),
                              ],
                            ),
                          ))),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Est. Duration: ~${_currentTicket.totalDurationMinutes} mins',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              )),
                          Text(
                            'Total: ₹${_currentTicket.totalPrice.toStringAsFixed(0)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Cancel Token Button (only shown while waiting)
              if (_currentTicket.isWaiting)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _cancelling ? null : _handleCancelTicket,
                    icon: const Icon(Icons.close, color: Color(0xFFC62828)),
                    label: const Text(
                      'Cancel / Leave Queue',
                      style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFC62828)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ),
        ),
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
        ? const Color(0xFF2E7D32)
        : (isCurrent ? const Color(0xFF6750A4) : Colors.grey.shade400);

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
                            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                          ),
                        )
                      : null),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isDone ? color : Colors.grey.shade300,
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
                  fontWeight: isDone || isCurrent ? FontWeight.bold : FontWeight.w600,
                  color: isDone
                      ? const Color(0xFF2E7D32)
                      : (isCurrent ? const Color(0xFF6750A4) : null),
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }
}
