import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../shared/models/queue_ticket.dart';
import '../../../shared/models/salon.dart';
import '../../../shared/models/salon_service.dart';
import '../../auth/services/auth_scope.dart';
import '../../queue/data/queue_repository.dart';
import '../../queue/screens/customer_queue_screen.dart';

/// Screen displaying salon details, complete service menu with price/time, and queue join action.
class SalonDetailsScreen extends StatefulWidget {
  const SalonDetailsScreen({
    super.key,
    required this.salon,
  });

  final Salon salon;

  @override
  State<SalonDetailsScreen> createState() => _SalonDetailsScreenState();
}

class _SalonDetailsScreenState extends State<SalonDetailsScreen> {
  final QueueRepository _queueRepo = QueueRepository();
  final Set<String> _selectedServiceIds = {};
  String _selectedCategory = '';
  bool _isJoining = false;

  StreamSubscription<List<QueueTicket>>? _queueSubscription;
  int _liveWaitingCount = 0;
  int _liveServingCount = 0;
  String _liveServingTokens = '';
  int _liveEstWaitMinutes = 0;

  @override
  void initState() {
    super.initState();
    _liveWaitingCount = widget.salon.waitingCount;
    _liveEstWaitMinutes = widget.salon.estWaitMinutes;

    final cats = _categories;
    if (cats.isNotEmpty) {
      _selectedCategory = cats.first;
    }

    _subscribeToLiveQueue();
  }

  void _subscribeToLiveQueue() {
    _queueSubscription?.cancel();
    _queueSubscription = _queueRepo.streamLiveQueueForSalon(widget.salon.id).listen(
      (tickets) {
        if (!mounted) return;
        final waiting = tickets.where((t) => t.status == QueueStatus.waiting).toList();
        final serving = tickets.where((t) => t.status == QueueStatus.inChair).toList();
        final chairs = widget.salon.activeChairs > 0 ? widget.salon.activeChairs : 1;
        final estWait = (waiting.length * (20 / chairs)).round();

        setState(() {
          _liveWaitingCount = waiting.length;
          _liveServingCount = serving.length;
          _liveServingTokens = serving.isNotEmpty
              ? serving.map((t) => '#${t.tokenNumber}').join(', ')
              : 'None';
          _liveEstWaitMinutes = estWait;
        });
      },
      onError: (err) {
        debugPrint('[SalonDetailsScreen] streamLiveQueueForSalon error: $err');
      },
    );
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    super.dispose();
  }

  /// Calculates dynamic live rush level based on real-time waiting count
  RushLevel get _liveRushLevel {
    if (!widget.salon.isQueueOpen) return RushLevel.low;
    final chairs = widget.salon.activeChairs > 0 ? widget.salon.activeChairs : 1;
    final ratio = _liveWaitingCount / chairs;
    if (ratio <= 0.6) return RushLevel.low;
    if (ratio <= 1.5) return RushLevel.moderate;
    return RushLevel.high;
  }

  /// Dynamically extracts all distinct service categories from the salon's actual services,
  /// always starting with 'All' so all categories are accessible horizontally.
  List<String> get _categories {
    final categoriesSet = <String>{};
    for (final s in widget.salon.services) {
      final cat = s.category.trim();
      if (cat.isNotEmpty) {
        categoriesSet.add(cat);
      }
    }
    final list = categoriesSet.isNotEmpty
        ? categoriesSet.toList()
        : ['Hair', 'Beard', 'Facial', 'Styling', 'Color', 'Spa', 'Combo'];
    return ['All', ...list];
  }

  /// Returns currently selected category, defaulting to 'All'.
  String get _effectiveSelectedCategory {
    final cats = _categories;
    if (_selectedCategory.isEmpty || _selectedCategory.toLowerCase() == 'all') {
      return 'All';
    }
    if (cats.any((c) => c.toLowerCase() == _selectedCategory.toLowerCase())) {
      return cats.firstWhere(
          (c) => c.toLowerCase() == _selectedCategory.toLowerCase());
    }
    return 'All';
  }

  List<SalonService> get _filteredServices {
    final currentCat = _effectiveSelectedCategory;
    if (currentCat == 'All') {
      return widget.salon.services;
    }
    final matched = widget.salon.services
        .where((s) =>
            s.category.trim().toLowerCase() == currentCat.trim().toLowerCase())
        .toList();
    if (matched.isEmpty) return widget.salon.services;
    return matched;
  }

  List<SalonService> get _selectedServicesList {
    return widget.salon.services
        .where((s) => _selectedServiceIds.contains(s.id))
        .toList();
  }

  double get _totalPrice =>
      _selectedServicesList.fold(0.0, (sum, s) => sum + s.price);

  int get _totalDuration =>
      _selectedServicesList.fold(0, (sum, s) => sum + s.durationMinutes);

  Future<void> _handleJoinQueue() async {
    if (_selectedServiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one service to join the queue.'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }

    setState(() => _isJoining = true);

    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;

    try {
      final ticket = await _queueRepo.joinQueue(
        salonId: widget.salon.id,
        customerId: user?.id,
        customerName: user?.fullName ?? 'Valued Customer',
        customerPhone: user?.phone,
        selectedServices: _selectedServicesList,
      );

      if (!mounted) return;
      setState(() => _isJoining = false);

      // Navigate to digital ticket tracking screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CustomerQueueScreen(
            ticket: ticket,
            salon: widget.salon,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isJoining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to join queue: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rush = _liveRushLevel;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Collapsible Header with Salon Cover Image & Info
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.salon.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.salon.effectiveCoverImage != null &&
                      widget.salon.effectiveCoverImage!.isNotEmpty)
                    _buildCoverWidget(widget.salon.effectiveCoverImage!)
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF14243A), Color(0xFF1E3650), Color(0xFF2C4A6F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.storefront,
                          size: 80,
                          color: const Color(0xFFC9A45C).withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  // Scrim overlay for title readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Salon Overview, About, Gallery & Live Rush Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Address and Rating
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.salon.rating} (${widget.salon.reviewCount} reviews)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.salon.isQueueOpen
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.salon.isQueueOpen ? '● OPEN' : '● CLOSED',
                          style: TextStyle(
                            color: widget.salon.isQueueOpen
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFC62828),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 18, color: theme.colorScheme.outline),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${widget.salon.address}, ${widget.salon.city}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 18, color: theme.colorScheme.outline),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.salon.openingTime} - ${widget.salon.closingTime}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Live Rush Status Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: rush.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: rush.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(rush.icon, color: rush.color, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Live Crowd: ${rush.label}',
                                style: TextStyle(
                                  color: rush.color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$_liveWaitingCount customers in queue • ~$_liveEstWaitMinutes mins est. wait',
                                style: TextStyle(
                                  color: rush.color.withValues(alpha: 0.85),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Live Status Metrics (In Queue, Serving, Est Wait, Chairs)
                  Row(
                    children: [
                      Expanded(
                        child: _buildLiveMetricCard(
                          title: 'In Queue',
                          value: '$_liveWaitingCount',
                          subtitle: 'Waiting',
                          icon: Icons.people_alt_outlined,
                          color: const Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLiveMetricCard(
                          title: 'Serving',
                          value: _liveServingCount > 0 ? '$_liveServingCount' : '0',
                          subtitle: _liveServingTokens.isNotEmpty ? 'Token $_liveServingTokens' : 'Available',
                          icon: Icons.chair_alt_outlined,
                          color: const Color(0xFF0D9488),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLiveMetricCard(
                          title: 'Est. Wait',
                          value: '$_liveEstWaitMinutes',
                          subtitle: 'Minutes',
                          icon: Icons.hourglass_top_outlined,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLiveMetricCard(
                          title: 'Chairs',
                          value: '${widget.salon.activeChairs}',
                          subtitle: 'Stylists',
                          icon: Icons.content_cut_outlined,
                          color: const Color(0xFF4B5563),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Owner Profile Card ──────────────────────────────────────
                  _buildOwnerCard(),

                  // ── About the Salon ─────────────────────────────────────────
                  if (widget.salon.description != null && widget.salon.description!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'About the Salon',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.salon.description!,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                    ),
                  ],

                  // ── Salon Gallery ───────────────────────────────────────────
                  if (widget.salon.galleryImages.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Salon Gallery',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${widget.salon.galleryImages.length} photos',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.salon.galleryImages.length,
                        itemBuilder: (context, idx) {
                          final imgPath = widget.salon.galleryImages[idx];
                          return GestureDetector(
                            onTap: () => _openFullscreenGallery(idx),
                            child: Container(
                              width: 110,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: _buildImageWidget(imgPath, fit: BoxFit.cover),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Text(
                    'Select Services',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose the options you want to get done:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected =
                            _effectiveSelectedCategory.toLowerCase() ==
                                cat.toLowerCase();

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              setState(() => _selectedCategory = cat);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF14243A)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF14243A)
                                      : const Color(0xFFE2E8F0),
                                  width: 1.2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF14243A)
                                              .withValues(alpha: 0.2),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.03),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected) ...[
                                    const Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: Color(0xFFC9A45C),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    cat,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF1E293B),
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      fontSize: 13,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Services Checklist
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final service = _filteredServices[index];
                  final isSelected = _selectedServiceIds.contains(service.id);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withValues(alpha: 0.2),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    color: isSelected
                        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : null,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedServiceIds.remove(service.id);
                          } else {
                            _selectedServiceIds.add(service.id);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedServiceIds.add(service.id);
                                  } else {
                                    _selectedServiceIds.remove(service.id);
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    service.name,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          service.category,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.timer_outlined, size: 14, color: theme.colorScheme.outline),
                                      const SizedBox(width: 2),
                                      Text(
                                        '~${service.durationMinutes} mins',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${service.price.toStringAsFixed(0)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _filteredServices.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),

      // Bottom Bar with Summary & Join Queue CTA
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedServiceIds.length} service(s) selected',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      '₹${_totalPrice.toStringAsFixed(0)} • ~$_totalDuration mins',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _isJoining || !widget.salon.isQueueOpen ? null : _handleJoinQueue,
                icon: _isJoining
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.queue_play_next),
                label: Text(
                  widget.salon.isQueueOpen ? 'Join Live Queue' : 'Queue Closed',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerCard() {
    final ownerName = widget.salon.ownerName ?? 'Rahul Sharma';
    final avatar = widget.salon.ownerAvatarUrl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC9A45C).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFC9A45C).withValues(alpha: 0.2),
            child: CircleAvatar(
              radius: 25,
              backgroundColor: const Color(0xFF14243A),
              child: avatar != null && avatar.isNotEmpty
                  ? ClipOval(
                      child: _buildImageWidget(avatar, width: 50, height: 50, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.person, color: Color(0xFFC9A45C), size: 28),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ownerName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF14243A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC9A45C).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'OWNER',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Master Stylist & Salon Director',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 13, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 4),
                    Text(
                      'Verified Salon Management',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w600,
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

  Widget _buildLiveMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 13, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCoverWidget(String path) {
    return _buildImageWidget(path, fit: BoxFit.cover);
  }

  Widget _buildImageWidget(String path, {BoxFit fit = BoxFit.cover, double? width, double? height}) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } else if (path.startsWith('data:image')) {
      try {
        final base64Str = path.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, fit: fit, width: width, height: height);
      } catch (_) {
        return _buildPlaceholder();
      }
    } else {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, fit: fit, width: width, height: height);
      }
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF14243A),
      child: const Center(
        child: Icon(Icons.storefront, size: 64, color: Colors.white24),
      ),
    );
  }

  void _openFullscreenGallery(int initialIndex) {
    showDialog(
      context: context,
      builder: (ctx) {
        final pageController = PageController(initialPage: initialIndex);
        int currentIdx = initialIndex;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.black,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: pageController,
                    itemCount: widget.salon.galleryImages.length,
                    onPageChanged: (i) => setModalState(() => currentIdx = i),
                    itemBuilder: (context, i) {
                      final img = widget.salon.galleryImages[i];
                      return InteractiveViewer(
                        child: Center(
                          child: _buildImageWidget(img, fit: BoxFit.contain),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 40,
                    right: 20,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${currentIdx + 1} / ${widget.salon.galleryImages.length}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
