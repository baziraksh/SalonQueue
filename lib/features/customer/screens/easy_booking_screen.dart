import 'package:flutter/material.dart';
import '../../../core/theme/color_schemes.dart';
import '../../../shared/models/queue_ticket.dart';
import '../../../shared/models/salon.dart';
import '../../../shared/widgets/active_queue_card.dart';
import '../../../shared/widgets/salon_card.dart';
import '../../auth/services/auth_scope.dart';
import '../../queue/data/queue_repository.dart';
import '../../queue/screens/customer_queue_screen.dart';
import '../../salon/data/salon_repository.dart';
import '../../salon/screens/salon_details_screen.dart';

/// Screen for 1-Tap Easy Booking & Live Queue Token generation
class EasyBookingScreen extends StatefulWidget {
  const EasyBookingScreen({super.key});

  @override
  State<EasyBookingScreen> createState() => _EasyBookingScreenState();
}

class _EasyBookingScreenState extends State<EasyBookingScreen> {
  final SalonRepository _salonRepo = SalonRepository();
  final QueueRepository _queueRepo = QueueRepository();

  List<Salon> _salons = [];
  QueueTicket? _activeTicket;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final auth = AuthScope.of(context, listen: false);
    final userId = auth.currentUser?.id;

    if (userId != null) {
      _activeTicket = await _queueRepo.fetchActiveTicketForCustomer(userId);
    }

    final list = await _salonRepo.fetchSalons();

    if (!mounted) return;
    setState(() {
      _salons = list.where((s) => s.isQueueOpen).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColorSchemes.ivory,
      appBar: AppBar(
        title: const Text('1-Tap Easy Booking'),
        backgroundColor: AppColorSchemes.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColorSchemes.navy,
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Banner ──────────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColorSchemes.navy, Color(0xFF1E3A5F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.touch_app_rounded, color: AppColorSchemes.gold, size: 28),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Instant Digital Queue Token',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Select any open salon below to view services and join its live queue in 1 tap.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Active Queue Ticket (if customer is currently in a queue) ──
              if (_activeTicket != null && (_activeTicket!.isWaiting || _activeTicket!.isInChair)) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ActiveQueueCard(
                    ticket: _activeTicket!,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomerQueueScreen(ticket: _activeTicket!),
                        ),
                      ).then((_) => _loadData());
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Open Salons List ───────────────────────────────────────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Available Open Salons',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColorSchemes.charcoal,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(color: AppColorSchemes.gold),
                  ),
                )
              else if (_salons.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(Icons.storefront_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No open salons available for booking right now',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _salons.length,
                  itemBuilder: (context, idx) {
                    final salon = _salons[idx];
                    return SalonCard(
                      salon: salon,
                      isFavorite: false,
                      onFavoriteTap: () {},
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SalonDetailsScreen(salon: salon),
                          ),
                        ).then((_) => _loadData());
                      },
                      onJoinQueue: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SalonDetailsScreen(salon: salon),
                          ),
                        ).then((_) => _loadData());
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
