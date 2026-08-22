import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/color_schemes.dart';
import '../../../shared/models/queue_ticket.dart';
import '../../../shared/models/salon.dart';
import '../../../shared/models/salon_service.dart';
import '../../auth/services/auth_scope.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/screens/owner_notifications_screen.dart';
import '../../queue/data/queue_repository.dart';
import '../data/salon_repository.dart';
import 'chairs_timings_screen.dart';
import 'manage_services_screen.dart';
import 'owner_profile_screen.dart';
import 'salon_analytics_screen.dart';
import 'salon_location_screen.dart';
import 'salon_qr_screen.dart';
import 'store_info_screen.dart';
import '../../support/screens/support_center_screen.dart';

/// Salon Owner Live Queue Command Center
/// Redesigned in luxury Navy (#14243A) & Gold (#C9A45C) SalonQueue SaaS aesthetic.
class SalonEntryScreen extends StatefulWidget {
  const SalonEntryScreen({super.key});

  @override
  State<SalonEntryScreen> createState() => _SalonEntryScreenState();
}

class _SalonEntryScreenState extends State<SalonEntryScreen> {
  final SalonRepository _salonRepo = SalonRepository();
  final QueueRepository _queueRepo = QueueRepository();
  final NotificationRepository _notifRepo = NotificationRepository();

  int _selectedBottomNavIndex = 0;

  Salon? _salon;
  List<QueueTicket> _tickets = [];
  StreamSubscription<List<QueueTicket>>? _queueSub;
  StreamSubscription<List<AppNotification>>? _notifSub;
  int _unreadNotifsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifyAccess());
    _loadSalonAndQueue();
    _loadNotifications();
  }

  void _verifyAccess() {
    if (!mounted) return;
    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;
    if (user != null && user.isAuthenticated && !user.role.isSalonOwner) {
      AppRouter.navigateToCustomerEntry(context);
    }
  }

  @override
  void dispose() {
    _queueSub?.cancel();
    _notifSub?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    final auth = AuthScope.of(context, listen: false);
    final ownerId = auth.currentUser?.id ?? '';
    if (ownerId.isEmpty) return;

    _notifSub?.cancel();
    _notifSub = _notifRepo
        .streamNotifications(ownerId)
        .listen(
          (notifs) {
            if (mounted) {
              setState(() {
                _unreadNotifsCount = notifs.where((n) => !n.isRead).length;
              });
            }
          },
          onError: (err) {
            debugPrint('[SalonEntryScreen] notif stream error: $err');
          },
        );

    final unread = await _notifRepo.getUnreadCount(ownerId);
    if (!mounted) return;
    setState(() {
      _unreadNotifsCount = unread;
    });
  }

  Future<void> _loadSalonAndQueue() async {
    setState(() => _isLoading = true);

    final auth = AuthScope.of(context, listen: false);
    final ownerId = auth.currentUser?.id ?? '';

    _loadNotifications();

    final salon = await _salonRepo.fetchOwnerSalon(ownerId);
    if (salon != null) {
      _queueSub?.cancel();
      _queueSub = _queueRepo
          .streamLiveQueueForSalon(salon.id)
          .listen(
            (liveTickets) {
              if (mounted) {
                setState(() {
                  _tickets = liveTickets;
                });
              }
            },
            onError: (err) {
              debugPrint(
                '[SalonEntryScreen] streamLiveQueueForSalon error: $err',
              );
            },
          );

      final queue = await _queueRepo.fetchLiveQueueForSalon(salon.id);
      if (!mounted) return;
      setState(() {
        _salon = salon;
        _tickets = queue;
        _isLoading = false;
      });
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<QueueTicket> get _inChairTickets =>
      _tickets.where((t) => t.status == QueueStatus.inChair).toList();

  List<QueueTicket> get _waitingTickets =>
      _tickets.where((t) => t.status == QueueStatus.waiting).toList();

  Future<void> _handleToggleQueue(bool isOpen) async {
    if (_salon == null) return;
    setState(() {
      _salon = _salon!.copyWith(isQueueOpen: isOpen);
    });
    await _salonRepo.setQueueStatus(
      _salon!.id,
      isOpen,
      ownerId: _salon!.ownerId,
    );
  }

  Future<void> _handleCallNext(QueueTicket ticket) async {
    final assignedChair = _inChairTickets.length + 1;
    await _queueRepo.updateTicketStatus(
      ticketId: ticket.id,
      status: QueueStatus.inChair,
      chairNumber: assignedChair,
    );
    _loadSalonAndQueue();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Called ${ticket.customerName} to Chair #$assignedChair!',
        ),
        backgroundColor: AppColorSchemes.navy,
      ),
    );
  }

  Future<void> _handleFinishService(QueueTicket ticket) async {
    await _queueRepo.updateTicketStatus(
      ticketId: ticket.id,
      status: QueueStatus.completed,
    );
    _loadSalonAndQueue();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Service completed for ${ticket.customerName}.'),
        backgroundColor: AppColorSchemes.available,
      ),
    );
  }

  Future<void> _handleSkipTicket(QueueTicket ticket) async {
    await _queueRepo.updateTicketStatus(
      ticketId: ticket.id,
      status: QueueStatus.skipped,
    );
    _loadSalonAndQueue();
  }

  Future<void> _handleCancelTicket(QueueTicket ticket) async {
    await _queueRepo.cancelTicket(ticket.id);
    _loadSalonAndQueue();
  }

  void _showAddWalkInDialog() {
    if (_salon == null) return;

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final Set<String> selectedServiceIds = {};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColorSchemes.navy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
                    color: AppColorSchemes.navy,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Add Walk-in Token',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColorSchemes.charcoal,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name *',
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: AppColorSchemes.navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        prefixIcon: Icon(
                          Icons.phone_outlined,
                          color: AppColorSchemes.navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Services:',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColorSchemes.charcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._salon!.services.map((svc) {
                      final isSelected = selectedServiceIds.contains(svc.id);
                      return CheckboxListTile(
                        dense: true,
                        activeColor: AppColorSchemes.navy,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${svc.name} (₹${svc.price.toStringAsFixed(0)})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          '~${svc.durationMinutes} mins',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        value: isSelected,
                        onChanged: (val) {
                          setModalState(() {
                            if (val == true) {
                              selectedServiceIds.add(svc.id);
                            } else {
                              selectedServiceIds.remove(svc.id);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter customer name'),
                      ),
                    );
                    return;
                  }

                  final chosenServices = _salon!.services
                      .where((s) => selectedServiceIds.contains(s.id))
                      .toList();

                  final servicesToUse = chosenServices.isNotEmpty
                      ? chosenServices
                      : (_salon!.services.isNotEmpty
                            ? [_salon!.services.first]
                            : [
                                SalonService(
                                  id: 'svc-general',
                                  salonId: _salon!.id,
                                  name: 'General Grooming',
                                  category: 'Hair',
                                  price: 150.0,
                                  durationMinutes: 20,
                                ),
                              ]);

                  await _queueRepo.joinQueue(
                    salonId: _salon!.id,
                    customerId: null,
                    customerName: nameController.text.trim(),
                    customerPhone: phoneController.text.trim(),
                    selectedServices: servicesToUse,
                  );

                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  _loadSalonAndQueue();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColorSchemes.gold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  'Generate Token',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColorSchemes.ivory,
        appBar: _buildAppBar(context),
        drawer: _buildOwnerDrawer(context),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColorSchemes.gold),
              )
            : RefreshIndicator(
                color: AppColorSchemes.navy,
                onRefresh: _loadSalonAndQueue,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 1. Master Queue Toggle Banner ────────────────────
                      _buildMasterQueueBanner(),

                      const SizedBox(height: 16),

                      // ── 2. Live Metric Stat Cards ─────────────────────────
                      _buildLiveMetricCards(),

                      const SizedBox(height: 16),

                      // ── 3. Quick Action Hub ──────────────────────────────
                      _buildQuickActionHub(context),

                      const SizedBox(height: 24),

                      // ── 4. Currently Serving (In Chair) Section ──────────
                      _buildCurrentlyServingSection(),

                      const SizedBox(height: 24),

                      // ── 5. Live Waiting Queue Section ────────────────────
                      _buildLiveWaitingQueueSection(),

                      const SizedBox(
                        height: 90,
                      ), // Spacing for FAB & Bottom Nav
                    ],
                  ),
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddWalkInDialog,
          backgroundColor: AppColorSchemes.gold,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.person_add_rounded, size: 20),
          label: const Text(
            '+ Add Walk-in',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
        ),
        bottomNavigationBar: _buildOwnerBottomNav(context),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── APP BAR & HEADER ──────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      titleSpacing: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(
            Icons.menu_rounded,
            color: AppColorSchemes.navy,
            size: 26,
          ),
          tooltip: 'Navigation Menu',
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _salon?.name ?? 'Royal Cuts & Grooming Lounge',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColorSchemes.charcoal,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: AppColorSchemes.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'OWNER DASHBOARD',
                  style: TextStyle(
                    color: AppColorSchemes.navy,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Badge.count(
            count: _unreadNotifsCount,
            isLabelVisible: _unreadNotifsCount > 0,
            backgroundColor: AppColorSchemes.gold,
            textColor: Colors.white,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: AppColorSchemes.navy,
              size: 25,
            ),
          ),
          tooltip: 'Notifications',
          visualDensity: VisualDensity.compact,
          onPressed: () {
            final auth = AuthScope.of(context, listen: false);
            final ownerId = auth.currentUser?.id ?? _salon?.ownerId ?? '';
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => OwnerNotificationsScreen(ownerId: ownerId),
                  ),
                )
                .then((_) => _loadNotifications());
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── OWNER NAVIGATION DRAWER ───────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildOwnerDrawer(BuildContext context) {
    final auth = AuthScope.of(context, listen: false);
    final ownerEmail = auth.currentUser?.email ?? 'owner@salonqueue.app';
    final ownerDisplayName =
        (auth.currentUser?.fullName != null &&
            auth.currentUser!.fullName!.trim().isNotEmpty)
        ? auth.currentUser!.fullName!
        : ((_salon?.ownerName != null && _salon!.ownerName!.trim().isNotEmpty)
              ? _salon!.ownerName!
              : 'Salon Owner');
    final avatar = auth.currentUser?.avatarUrl ?? _salon?.ownerAvatarUrl;
    final salonName = (_salon?.name != null && _salon!.name.trim().isNotEmpty)
        ? _salon!.name
        : 'My Salon & Spa';

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // ── Drawer Header ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColorSchemes.navy, AppColorSchemes.navyLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColorSchemes.gold.withValues(
                      alpha: 0.3,
                    ),
                    child: CircleAvatar(
                      radius: 27,
                      backgroundColor: AppColorSchemes.navy,
                      child: avatar != null && avatar.isNotEmpty
                          ? ClipOval(child: _buildDrawerAvatar(avatar))
                          : const Icon(
                              Icons.person,
                              size: 32,
                              color: AppColorSchemes.gold,
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    ownerDisplayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2, bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColorSchemes.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'SALON OWNER',
                      style: TextStyle(
                        color: AppColorSchemes.goldLight,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Text(
                    salonName,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    ownerEmail,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // ── Navigation Items ───────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerSectionLabel('PROFILE & BRAND'),
                  ListTile(
                    leading: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColorSchemes.navy,
                    ),
                    title: const Text(
                      'Owner Profile',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Cover photo, gallery & owner info',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.pop(context);
                      if (_salon != null) {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => OwnerProfileScreen(
                                  salon: _salon!,
                                  onUpdated: _loadSalonAndQueue,
                                ),
                              ),
                            )
                            .then((_) => _loadSalonAndQueue());
                      }
                    },
                  ),

                  const Divider(height: 16),
                  _buildDrawerSectionLabel('STORE MANAGEMENT'),
                  ListTile(
                    leading: const Icon(
                      Icons.storefront_rounded,
                      color: AppColorSchemes.navy,
                    ),
                    title: const Text(
                      'Store Information',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Name, description & phone',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.pop(context);
                      if (_salon != null) {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => StoreInfoScreen(salon: _salon!),
                              ),
                            )
                            .then((_) => _loadSalonAndQueue());
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.location_on_rounded,
                      color: AppColorSchemes.navy,
                    ),
                    title: const Text(
                      'Salon Location',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Address, state, district & city',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.pop(context);
                      if (_salon != null) {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    SalonLocationScreen(salon: _salon!),
                              ),
                            )
                            .then((_) => _loadSalonAndQueue());
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.schedule_rounded,
                      color: AppColorSchemes.navy,
                    ),
                    title: const Text(
                      'Chairs & Timings',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Capacity & operating hours',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.pop(context);
                      if (_salon != null) {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ChairsTimingsScreen(salon: _salon!),
                              ),
                            )
                            .then((_) => _loadSalonAndQueue());
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.content_cut_rounded,
                      color: AppColorSchemes.navy,
                    ),
                    title: const Text(
                      'Services & Pricing',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Add, edit prices & manage rate card',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.pop(context);
                      if (_salon != null) {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ManageServicesScreen(salon: _salon!),
                              ),
                            )
                            .then((_) => _loadSalonAndQueue());
                      }
                    },
                  ),

                  const Divider(height: 16),
                  _buildDrawerSectionLabel('SUPPORT & ALERTS'),
                  ListTile(
                    leading: const Icon(
                      Icons.help_outline_rounded,
                      color: AppColorSchemes.navy,
                    ),
                    title: const Text(
                      'Help & Support',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Owner FAQs & submit ticket',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const SupportCenterScreen(isOwner: true),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Badge.count(
                      count: _unreadNotifsCount,
                      isLabelVisible: _unreadNotifsCount > 0,
                      backgroundColor: AppColorSchemes.gold,
                      textColor: Colors.white,
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: AppColorSchemes.navy,
                      ),
                    ),
                    title: const Text(
                      'Notifications',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Live queue joins & system updates',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.pop(context);
                      final auth = AuthScope.of(context, listen: false);
                      final ownerId =
                          auth.currentUser?.id ?? _salon?.ownerId ?? '';
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  OwnerNotificationsScreen(ownerId: ownerId),
                            ),
                          )
                          .then((_) => _loadNotifications());
                    },
                  ),

                  const Divider(height: 16),
                  _buildDrawerSectionLabel('ACCOUNT'),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
                    title: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => _showLogoutConfirmDialog(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.grey.shade500,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildDrawerAvatar(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: 54,
        height: 54,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.person, size: 32, color: AppColorSchemes.gold),
      );
    } else if (path.startsWith('data:image')) {
      try {
        final base64Str = path.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, width: 54, height: 54, fit: BoxFit.cover);
      } catch (_) {
        return const Icon(Icons.person, size: 32, color: AppColorSchemes.gold);
      }
    } else {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, width: 54, height: 54, fit: BoxFit.cover);
      }
      return const Icon(Icons.person, size: 32, color: AppColorSchemes.gold);
    }
  }

  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 10),
            Text('Logout', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final auth = AuthScope.of(context, listen: false);
              await auth.signOut();
              if (!context.mounted) return;
              AppRouter.navigateToWelcomeAfterLogout(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── 1. MASTER QUEUE TOGGLE BANNER ─────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMasterQueueBanner() {
    final isOpen = _salon?.isQueueOpen ?? true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOpen ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOpen ? AppColorSchemes.available : AppColorSchemes.busy)
                .withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isOpen ? AppColorSchemes.available : AppColorSchemes.busy,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOpen
                  ? Icons.check_circle_outline_rounded
                  : Icons.pause_circle_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen ? 'QUEUE IS OPEN' : 'QUEUE IS PAUSED',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: isOpen
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB91C1C),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOpen
                      ? 'Customers can join the live queue'
                      : 'New tokens are temporarily paused',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isOpen,
            activeThumbColor: AppColorSchemes.available,
            activeTrackColor: const Color(0xFFBBF7D0),
            inactiveThumbColor: AppColorSchemes.busy,
            inactiveTrackColor: const Color(0xFFFECDD3),
            onChanged: _handleToggleQueue,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── 2. LIVE METRIC STAT CARDS ─────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLiveMetricCards() {
    return Row(
      children: [
        Expanded(
          child: _buildLuxuryStatCard(
            title: 'IN CHAIR',
            subtitle: 'Serving Now',
            value: _inChairTickets.length.toString(),
            icon: Icons.chair_alt_rounded,
            badgeColor: AppColorSchemes.navy,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildLuxuryStatCard(
            title: 'WAITING',
            subtitle: 'In Live Line',
            value: _waitingTickets.length.toString(),
            icon: Icons.people_alt_outlined,
            badgeColor: AppColorSchemes.gold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildLuxuryStatCard(
            title: 'CHAIRS',
            subtitle: 'Capacity',
            value: '${_salon?.activeChairs ?? 3}',
            icon: Icons.event_seat_rounded,
            badgeColor: AppColorSchemes.available,
          ),
        ),
      ],
    );
  }

  Widget _buildLuxuryStatCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: badgeColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: badgeColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColorSchemes.charcoal,
              letterSpacing: 0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── 3. QUICK ACTION HUB ───────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildQuickActionHub(BuildContext context) {
    if (_salon == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Operations',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColorSchemes.charcoal,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildQuickActionChip(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Add Walk-in',
                color: AppColorSchemes.gold,
                onTap: _showAddWalkInDialog,
              ),
              const SizedBox(width: 8),
              _buildQuickActionChip(
                icon: Icons.qr_code_2_rounded,
                label: 'Store QR',
                color: AppColorSchemes.navy,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SalonQrScreen(salon: _salon!),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildQuickActionChip(
                icon: Icons.menu_book_rounded,
                label: 'Services & Pricing',
                color: AppColorSchemes.navy,
                onTap: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => ManageServicesScreen(salon: _salon!),
                        ),
                      )
                      .then((_) => _loadSalonAndQueue());
                },
              ),
              const SizedBox(width: 8),
              _buildQuickActionChip(
                icon: Icons.analytics_outlined,
                label: 'Analytics',
                color: AppColorSchemes.navy,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SalonAnalyticsScreen(
                        salon: _salon!,
                        tickets: _tickets,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildQuickActionChip(
                icon: Icons.person_rounded,
                label: 'Owner Profile',
                color: AppColorSchemes.navy,
                onTap: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => OwnerProfileScreen(
                            salon: _salon!,
                            onUpdated: _loadSalonAndQueue,
                          ),
                        ),
                      )
                      .then((_) => _loadSalonAndQueue());
                },
              ),
              const SizedBox(width: 8),
              _buildQuickActionChip(
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
                color: AppColorSchemes.navy,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SupportCenterScreen(isOwner: true),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color == AppColorSchemes.gold
                    ? AppColorSchemes.charcoal
                    : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── 4. CURRENTLY SERVING (IN CHAIR) SECTION ───────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCurrentlyServingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Currently Serving',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColorSchemes.charcoal,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColorSchemes.navy,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_inChairTickets.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_inChairTickets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.chair_outlined,
                  size: 40,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                const Text(
                  'No customers currently in chair',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColorSchemes.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Call a waiting customer below to start service.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          )
        else
          ..._inChairTickets.map((ticket) => _buildInChairCard(ticket)),
      ],
    );
  }

  Widget _buildInChairCard(QueueTicket ticket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColorSchemes.gold.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColorSchemes.navy.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Chair Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColorSchemes.navy, AppColorSchemes.navyLight],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'CHAIR #${ticket.chairNumber ?? 1}',
                  style: const TextStyle(
                    color: AppColorSchemes.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Token Number
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColorSchemes.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ticket.formattedToken,
                  style: const TextStyle(
                    color: AppColorSchemes.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),

              // Complete Service Action
              ElevatedButton.icon(
                onPressed: () => _handleFinishService(ticket),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text(
                  'Finish',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColorSchemes.available,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColorSchemes.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ticket.serviceNames.join(' • '),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${ticket.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColorSchemes.navy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── 5. LIVE WAITING QUEUE SECTION ─────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLiveWaitingQueueSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Live Queue',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColorSchemes.charcoal,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColorSchemes.gold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_waitingTickets.length} waiting',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _showAddWalkInDialog,
              icon: const Icon(
                Icons.add_rounded,
                size: 16,
                color: AppColorSchemes.gold,
              ),
              label: const Text(
                '+ Add Walk-in',
                style: TextStyle(
                  color: AppColorSchemes.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_waitingTickets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.hourglass_empty_rounded,
                  size: 44,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 10),
                const Text(
                  'No customers waiting',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColorSchemes.charcoal,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'New customers will appear here when they join your queue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ..._waitingTickets.map((ticket) => _buildWaitingTicketCard(ticket)),
      ],
    );
  }

  Widget _buildWaitingTicketCard(QueueTicket ticket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Token Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: Text(
                  ticket.formattedToken,
                  style: const TextStyle(
                    color: Color(0xFFC2410C),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Customer info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColorSchemes.charcoal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ticket.serviceNames.join(' • '),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Total Price
              Text(
                '₹${ticket.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: AppColorSchemes.charcoal,
                ),
              ),
              const SizedBox(width: 4),

              // Share Button
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.share_rounded,
                  color: AppColorSchemes.available,
                  size: 20,
                ),
                tooltip: 'Share Token update',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Token ${ticket.formattedToken} ready to share with ${ticket.customerName} (${ticket.customerPhone ?? "Counter"})',
                      ),
                      backgroundColor: AppColorSchemes.navy,
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Action Buttons: Cancel, Skip, Call Next / Sit
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => _handleCancelTicket(ticket),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _handleSkipTicket(ticket),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColorSchemes.navy,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _handleCallNext(ticket),
                icon: const Icon(Icons.call_rounded, size: 16),
                label: const Text(
                  'Call Next / Sit',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColorSchemes.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── BOTTOM NAVIGATION ─────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildOwnerBottomNav(BuildContext context) {
    if (_salon == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BottomNavigationBar(
          currentIndex: _selectedBottomNavIndex,
          onTap: (idx) {
            setState(() => _selectedBottomNavIndex = idx);
            if (idx == 1) {
              // Services
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => ManageServicesScreen(salon: _salon!),
                    ),
                  )
                  .then((_) => _loadSalonAndQueue());
            } else if (idx == 2) {
              // Store QR
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SalonQrScreen(salon: _salon!),
                ),
              );
            } else if (idx == 3) {
              // Analytics
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      SalonAnalyticsScreen(salon: _salon!, tickets: _tickets),
                ),
              );
            } else if (idx == 4) {
              // Owner Profile
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => OwnerProfileScreen(
                        salon: _salon!,
                        onUpdated: _loadSalonAndQueue,
                      ),
                    ),
                  )
                  .then((_) => _loadSalonAndQueue());
            }
          },
          backgroundColor: Colors.white,
          selectedItemColor: AppColorSchemes.navy,
          unselectedItemColor: Colors.grey.shade400,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book_rounded),
              label: 'Services',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_2_rounded),
              activeIcon: Icon(Icons.qr_code_2_rounded),
              label: 'QR Code',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics_rounded),
              label: 'Analytics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
