import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/color_schemes.dart';
import '../../../shared/data/india_locations.dart';
import '../../../shared/models/queue_ticket.dart';
import '../../../shared/models/salon.dart';
import '../../../shared/widgets/active_queue_card.dart';
import '../../auth/services/auth_scope.dart';
import 'customer_history_screen.dart';
import 'customer_profile_screen.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/screens/customer_notifications_screen.dart';
import '../../queue/data/queue_repository.dart';
import '../../queue/screens/customer_queue_screen.dart';
import '../../qr/screens/qr_scanner_screen.dart';
import '../../salon/data/salon_repository.dart';
import '../../salon/screens/salon_details_screen.dart';
import '../services/location_suggestion_service.dart';

/// Customer Home & All-India Salon Discovery Dashboard
/// Redesigned in modern clean white/purple/pink aesthetic matching reference.
class CustomerEntryScreen extends StatefulWidget {
  const CustomerEntryScreen({super.key});

  @override
  State<CustomerEntryScreen> createState() => _CustomerEntryScreenState();
}

class _CustomerEntryScreenState extends State<CustomerEntryScreen> {
  final SalonRepository _salonRepo = SalonRepository();
  final QueueRepository _queueRepo = QueueRepository();
  final NotificationRepository _notifRepo = NotificationRepository();

  int _currentTabIndex = 0;

  String _selectedState = 'All States';
  String _selectedLocation = 'All India'; // Shows all registered live salons by default
  String? _selectedCity;
  String? _selectedDistrict;
  String? _selectedPincode;
  double _userLat = 18.5204;
  double _userLng = 73.8567;
  String _selectedCategory = 'All';
  String _sortBy = 'nearest'; // 'nearest', 'rush', 'rating'
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _favoriteSalonIds = {};
  List<Salon> _salons = [];
  QueueTicket? _activeTicket;
  QueueTicket? _latestTicket;
  Salon? _latestTicketSalon;
  bool _isLoading = true;
  int _unreadNotifsCount = 0;
  StreamSubscription<List<AppNotification>>? _notifSubscription;
  StreamSubscription<List<Salon>>? _salonsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifyAccess());
    _loadData();
    _loadNotifications();
    _setupSalonsAutoFetch();
  }

  void _setupSalonsAutoFetch() {
    _salonsSub?.cancel();
    _salonsSub = _salonRepo.streamSalons().listen((_) {
      if (mounted && !_isLoading) {
        _loadData();
      }
    });
  }

  void _verifyAccess() {
    if (!mounted) return;
    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;
    if (user != null && user.isAuthenticated && user.role.isSalonOwner) {
      AppRouter.navigateToSalonEntry(context);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notifSubscription?.cancel();
    _salonsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    final auth = AuthScope.of(context, listen: false);
    final userId = auth.currentUser?.id ?? 'customer-demo';

    try {
      final unread = await _notifRepo.getUnreadCount(userId);
      if (mounted) setState(() => _unreadNotifsCount = unread);
    } catch (_) {}

    _notifSubscription?.cancel();
    _notifSubscription = _notifRepo.streamNotifications(userId).listen((notifs) {
      if (mounted) {
        setState(() {
          _unreadNotifsCount = notifs.where((n) => !n.isRead).length;
        });
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final auth = AuthScope.of(context, listen: false);
    final userId = auth.currentUser?.id;

    if (userId != null) {
      _activeTicket = await _queueRepo.fetchActiveTicketForCustomer(userId);
      _latestTicket = await _queueRepo.fetchLatestTicketForCustomer(userId);
      if (_latestTicket != null) {
        _latestTicketSalon = await _salonRepo.fetchSalonById(_latestTicket!.salonId);
      }
    }

    final isAllIndia = (_selectedLocation == 'All India' || _selectedLocation == 'All Cities');
    final isAllStates = (_selectedState == 'All States' || _selectedState == 'All');
    final isNearMe = (_selectedLocation == 'Near Me');

    var list = await _salonRepo.fetchSalons(
      state: isAllStates ? null : _selectedState,
      city: (isAllIndia || isNearMe) ? null : (_selectedCity ?? _selectedLocation),
      district: _selectedDistrict,
      pincode: _selectedPincode,
      search: _searchController.text.trim(),
      category: (_selectedCategory == 'All' || _selectedCategory == 'Favorites')
          ? null
          : _selectedCategory,
      sortBy: _sortBy,
      userLat: _userLat,
      userLng: _userLng,
      maxRadiusKm: isNearMe ? 25.0 : null,
    );

    if (_selectedCategory == 'Favorites' || _currentTabIndex == 3) {
      list = list.where((s) => _favoriteSalonIds.contains(s.id)).toList();
    }

    if (!mounted) return;
    setState(() {
      _salons = list;
      _isLoading = false;
    });
  }

  void _showAllIndiaLocationSelector() {
    final locationSearchCtrl = TextEditingController();
    String? modalSelectedState;
    List<LocationSuggestion> searchResults = [];
    bool isSearching = false;
    Timer? debounceTimer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final allStates = IndiaLocations.getAllStates();

          void performSearch(String query) {
            debounceTimer?.cancel();
            if (query.trim().isEmpty) {
              setModalState(() {
                searchResults = [];
                isSearching = false;
              });
              return;
            }

            setModalState(() => isSearching = true);
            debounceTimer = Timer(const Duration(milliseconds: 300), () async {
              final results = await LocationSuggestionService.searchLocationSuggestions(query);
              if (ctx.mounted) {
                setModalState(() {
                  searchResults = results;
                  isSearching = false;
                });
              }
            });
          }

          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.82,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Select Location across India 🇮🇳',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColorSchemes.charcoal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          debounceTimer?.cancel();
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search Location Input (Live Maps Suggestions)
                  TextField(
                    controller: locationSearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search locality, street, city, or PIN code...',
                      prefixIcon: const Icon(Icons.search, color: AppColorSchemes.navy),
                      suffixIcon: isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColorSchemes.gold),
                              ),
                            )
                          : (locationSearchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    locationSearchCtrl.clear();
                                    debounceTimer?.cancel();
                                    setModalState(() {
                                      searchResults = [];
                                      isSearching = false;
                                    });
                                  },
                                )
                              : null),
                    ),
                    onChanged: performSearch,
                  ),
                  const SizedBox(height: 12),

                  // Quick Action Chips: Near Me & All India
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.my_location, size: 16, color: AppColorSchemes.gold),
                          label: const Text('📍 Near Me'),
                          backgroundColor: AppColorSchemes.navy,
                          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          onPressed: () {
                            debounceTimer?.cancel();
                            setState(() {
                              _selectedLocation = 'Near Me';
                              _selectedCity = null;
                              _selectedDistrict = null;
                              _selectedState = 'All States';
                              _selectedPincode = null;
                              _userLat = 18.5204;
                              _userLng = 73.8567;
                              _sortBy = 'nearest';
                            });
                            Navigator.of(ctx).pop();
                            _loadData();
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.public, size: 16, color: AppColorSchemes.navy),
                          label: const Text('All India 🇮🇳'),
                          onPressed: () {
                            debounceTimer?.cancel();
                            setState(() {
                              _selectedLocation = 'All India';
                              _selectedState = 'All States';
                              _selectedCity = null;
                              _selectedDistrict = null;
                              _selectedPincode = null;
                            });
                            Navigator.of(ctx).pop();
                            _loadData();
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 24),

                  // Search Results (Live Maps Suggestions) or State/District Drilldown
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (isSearching && searchResults.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(color: AppColorSchemes.gold),
                          );
                        }

                        if (searchResults.isNotEmpty) {
                          return ListView.builder(
                            itemCount: searchResults.length,
                            itemBuilder: (context, idx) {
                              final item = searchResults[idx];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColorSchemes.navy.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: AppColorSchemes.navy,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  item.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                subtitle: Text(
                                  item.subtitle,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  debounceTimer?.cancel();
                                  setState(() {
                                    _selectedLocation = item.title;
                                    _selectedCity = item.city ?? item.title;
                                    _selectedDistrict = item.district;
                                    _selectedState = item.state ?? 'All States';
                                    _selectedPincode = item.pincode;
                                    _userLat = item.latitude;
                                    _userLng = item.longitude;
                                  });
                                  Navigator.of(ctx).pop();
                                  _loadData();
                                },
                              );
                            },
                          );
                        }

                        if (locationSearchCtrl.text.trim().isNotEmpty && !isSearching) {
                          final queryText = locationSearchCtrl.text.trim();
                          return ListView(
                            children: [
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColorSchemes.gold.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.place_rounded,
                                    color: AppColorSchemes.navy,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  'Find Salons in "$queryText"',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColorSchemes.navy),
                                ),
                                subtitle: const Text(
                                  'Search salons by this village, area, or locality name',
                                  style: TextStyle(fontSize: 12),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColorSchemes.gold),
                                onTap: () {
                                  debounceTimer?.cancel();
                                  setState(() {
                                    _selectedLocation = queryText;
                                    _selectedCity = queryText;
                                    _selectedDistrict = null;
                                    _selectedState = 'All States';
                                    _selectedPincode = null;
                                  });
                                  Navigator.of(ctx).pop();
                                  _loadData();
                                },
                              ),
                              if (searchResults.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text(
                                      'Tap above to search for salons in "$queryText"',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        }

                        if (modalSelectedState == null) {
                          return ListView.builder(
                            itemCount: allStates.length,
                            itemBuilder: (context, idx) {
                              final stateName = allStates[idx];
                              final count = IndiaLocations.getDistrictsForState(stateName).length;
                              return ListTile(
                                leading: const Icon(Icons.flag_outlined, color: AppColorSchemes.navy),
                                title: Text(stateName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('$count districts/cities'),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColorSchemes.gold),
                                onTap: () {
                                  setModalState(() {
                                    modalSelectedState = stateName;
                                  });
                                },
                              );
                            },
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () =>
                                      setModalState(() => modalSelectedState = null),
                                ),
                                Expanded(
                                  child: Text(
                                    modalSelectedState!,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    debounceTimer?.cancel();
                                    final estCoords = LocationSuggestionService.getEstimatedCoordinates(
                                      modalSelectedState!,
                                      modalSelectedState!,
                                    );
                                    setState(() {
                                      _selectedState = modalSelectedState!;
                                      _selectedLocation = 'All Cities';
                                      _selectedCity = null;
                                      _selectedDistrict = null;
                                      _selectedPincode = null;
                                      _userLat = estCoords.latitude;
                                      _userLng = estCoords.longitude;
                                    });
                                    Navigator.of(ctx).pop();
                                    _loadData();
                                  },
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  child: const Text('View All', style: TextStyle(color: AppColorSchemes.gold, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const Divider(),
                            Expanded(
                              child: ListView(
                                children: IndiaLocations.getDistrictsForState(modalSelectedState!)
                                    .map((district) {
                                  return ListTile(
                                    leading: const Icon(Icons.location_on_outlined, color: AppColorSchemes.navy),
                                    title: Text(district),
                                    onTap: () {
                                      debounceTimer?.cancel();
                                      final estCoords = LocationSuggestionService.getEstimatedCoordinates(
                                        district,
                                        modalSelectedState!,
                                      );
                                      final resolvedDistrict = IndiaLocations.resolveDistrictForCity(
                                        district,
                                        modalSelectedState!,
                                      ) ?? district;
                                      setState(() {
                                        _selectedState = modalSelectedState!;
                                        _selectedLocation = district;
                                        _selectedCity = district;
                                        _selectedDistrict = resolvedDistrict;
                                        _selectedPincode = null;
                                        _userLat = estCoords.latitude;
                                        _userLng = estCoords.longitude;
                                      });
                                      Navigator.of(ctx).pop();
                                      _loadData();
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
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
        backgroundColor: Colors.white,
        drawer: _buildAppDrawer(context),
        body: _buildCurrentTabBody(context),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  /// Switch body based on bottom navigation index (Home, Bookings, Scan, My Queue, Profile)
  Widget _buildCurrentTabBody(BuildContext context) {
    switch (_currentTabIndex) {
      case 1: // Bookings / History Tab
        return const CustomerHistoryScreen();
      case 3: // My Queue Tab
        return _buildMyQueueTab();
      case 4: // Profile Tab
        return const CustomerProfileScreen();
      case 0: // Home Tab (Main Redesigned Screen)
      default:
        return _buildHomeScreen(context);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── HOME SCREEN (TAB 0) ──────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHomeScreen(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: const Color(0xFF6D28D9),
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Top Header ──────────────────────────────────────────
              _buildTopHeader(context),

              // ── 2. Search Area ─────────────────────────────────────────
              _buildSearchArea(),

              // ── 3. Active Queue Card (if active) ───────────────────────
              if (_activeTicket != null && (_activeTicket!.isWaiting || _activeTicket!.isInChair)) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
              ],

              // ── 4. Promotional Banner (Orange → Pink → Purple) ─────────
              _buildPromotionalBanner(),

              const SizedBox(height: 24),

              // ── 5. Nearby Salons (Horizontal Scroll) ───────────────────
              _buildNearbySalonsSection(),

              const SizedBox(height: 24),

              // ── 6. Popular Services (Horizontal Icons) ─────────────────
              _buildPopularServicesSection(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Top Header Widget ───────────────────────────────────────────────────
  Widget _buildTopHeader(BuildContext context) {
    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;
    final avatar = user?.avatarUrl;
    final fullName = user?.fullName?.trim();
    final firstName = (fullName != null && fullName.isNotEmpty)
        ? fullName.split(' ').first
        : 'Rakesh';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: User Greeting & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hi, $firstName 👋',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                const Text(
                  'Find and book the best salons',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Right: Notification Bell & Profile Avatar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Notification Bell (White circular button with border & shadow)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Badge.count(
                    count: _unreadNotifsCount,
                    isLabelVisible: _unreadNotifsCount > 0,
                    backgroundColor: const Color(0xFFE91E63),
                    textColor: Colors.white,
                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 9.5),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF111827),
                      size: 22,
                    ),
                  ),
                  tooltip: 'Notifications',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CustomerNotificationsScreen(),
                      ),
                    ).then((_) => _loadNotifications());
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Profile Avatar (Dark navy circular button)
              GestureDetector(
                onTap: () {
                  setState(() => _currentTabIndex = 4);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10233F),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10233F).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: avatar != null && avatar.isNotEmpty
                      ? ClipOval(
                          child: _buildAvatarImage(avatar),
                        )
                      : const Icon(
                          Icons.person,
                          size: 22,
                          color: Color(0xFFD4AF5A),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.person, size: 22, color: Color(0xFFD4AF5A)),
      );
    }
    return const Icon(Icons.person, size: 22, color: Color(0xFFD4AF5A));
  }

  // ── 2. Search Area ─────────────────────────────────────────────────────────
  Widget _buildSearchArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(
            Icons.search_rounded,
            color: Color(0xFF6B7280),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _loadData(),
              onSubmitted: (_) => _loadData(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
              decoration: const InputDecoration(
                hintText: 'Search salon, services or location',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF9CA3AF),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF9CA3AF)),
              onPressed: () {
                _searchController.clear();
                _loadData();
              },
            ),
          // Right-side manual search & location/options button
          InkWell(
            onTap: _showAllIndiaLocationSelector,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Color(0xFF111827),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Promotional Banner ──────────────────────────────────────────────────
  Widget _buildPromotionalBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF5A1F), // Vibrant Orange
            Color(0xFFE91E63), // Hot Pink
            Color(0xFF6D28D9), // Deep Purple
          ],
          stops: [0.0, 0.45, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Left Content
          Positioned(
            left: 22,
            top: 22,
            bottom: 22,
            right: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Skip the Wait',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -0.3,
                  ),
                ),
                const Text(
                  'Book Your',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -0.3,
                  ),
                ),
                const Text(
                  'Slot Now',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () {
                    if (_salons.isNotEmpty) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SalonDetailsScreen(salon: _salons.first),
                        ),
                      ).then((_) => _loadData());
                    } else {
                      _showAllIndiaLocationSelector();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF111827),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Book Now',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right Salon Chair Visual
          Positioned(
            right: 6,
            bottom: 6,
            top: 10,
            child: Image.asset(
              'assets/images/salon_chair.png',
              height: 185,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(
                  Icons.chair_rounded,
                  size: 90,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Nearby Salons Section ───────────────────────────────────────────────
  Widget _buildNearbySalonsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nearby Salons',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = 'All';
                    _searchController.clear();
                  });
                  _loadData();
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6D28D9),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Horizontal List of Salon Cards
        if (_isLoading)
          const SizedBox(
            height: 210,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF6D28D9)),
            ),
          )
        else if (_salons.isEmpty)
          _buildEmptyNearbySalons()
        else
          SizedBox(
            height: 215,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _salons.length,
              itemBuilder: (context, idx) {
                final salon = _salons[idx];
                return _buildHorizontalSalonCard(salon);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildHorizontalSalonCard(Salon salon) {
    final isFav = _favoriteSalonIds.contains(salon.id);
    final rating = salon.rating > 0 ? salon.rating.toStringAsFixed(1) : '4.8';
    final reviews = salon.reviewCount > 0 ? salon.reviewCount : 126;
    final distanceStr = salon.distanceKm != null
        ? '${salon.distanceKm!.toStringAsFixed(1)} km'
        : '2.4 km';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SalonDetailsScreen(salon: salon),
          ),
        ).then((_) => _loadData());
      },
      child: Container(
        width: 185,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF1F3F5)),
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
            // Top Image with Favorite Overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    color: const Color(0xFF1E293B),
                    child: _buildSalonCardImage(salon.effectiveCoverImage),
                  ),
                ),
                // Heart Favorite Button
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isFav) {
                          _favoriteSalonIds.remove(salon.id);
                        } else {
                          _favoriteSalonIds.add(salon.id);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: const Color(0xFFEF4444),
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Card Body
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    salon.name,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          '$rating ($reviews)',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        distanceStr,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalonCardImage(String? imagePath) {
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        return Image.network(
          imagePath,
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackSalonImage(),
        );
      } else if (imagePath.startsWith('data:image')) {
        try {
          final base64Str = imagePath.split(',').last;
          final bytes = base64Decode(base64Str);
          return Image.memory(
            bytes,
            height: 120,
            width: double.infinity,
            fit: BoxFit.cover,
          );
        } catch (_) {
          return _buildFallbackSalonImage();
        }
      }
    }
    return _buildFallbackSalonImage();
  }

  Widget _buildFallbackSalonImage() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1E293B),
            Color(0xFF334155),
            Color(0xFF475569),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.storefront_rounded,
          color: Color(0xFFD4AF5A),
          size: 36,
        ),
      ),
    );
  }

  Widget _buildEmptyNearbySalons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFEDE9FE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_outlined, color: Color(0xFF6D28D9), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No Salons in this View',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Change location or clear search to find salons.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. Popular Services Section ────────────────────────────────────────────
  Widget _buildPopularServicesSection() {
    final servicesList = [
      {'name': 'Haircut', 'icon': Icons.content_cut_rounded, 'filter': 'Hair'},
      {'name': 'Beard', 'icon': Icons.face_retouching_natural, 'filter': 'Beard'},
      {'name': 'Hair Color', 'icon': Icons.brush_rounded, 'filter': 'Color'},
      {'name': 'Spa', 'icon': Icons.spa_rounded, 'filter': 'Spa'},
      {'name': 'More', 'icon': Icons.more_horiz_rounded, 'filter': 'All'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Popular Services',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() => _selectedCategory = 'All');
                  _loadData();
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6D28D9),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Horizontal Row of 5 Service Icons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: servicesList.map((srv) {
              final name = srv['name'] as String;
              final icon = srv['icon'] as IconData;
              final filter = srv['filter'] as String;
              final isSelected = _selectedCategory == filter;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = (_selectedCategory == filter) ? 'All' : filter;
                  });
                  _loadData();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6D28D9)
                            : const Color(0xFFF3E8FF), // Light purple / lavender
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF6D28D9)
                              : const Color(0xFFE9D5FF),
                          width: 1.2,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: const Color(0xFF6D28D9).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? Colors.white : const Color(0xFF6D28D9),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── OTHER TABS (My Queue, Favorites) ──────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  /// My Queue Tab (Index 2)
  Widget _buildMyQueueTab() {
    if (_activeTicket != null && (_activeTicket!.isWaiting || _activeTicket!.isInChair)) {
      return CustomerQueueScreen(
        ticket: _activeTicket!,
        salon: _latestTicketSalon,
      );
    }

    if (_latestTicket != null && _latestTicket!.isCompleted) {
      final salonName = (_latestTicketSalon?.name != null && _latestTicketSalon!.name.isNotEmpty)
          ? _latestTicketSalon!.name
          : 'Salon';
      final salonAddress = _latestTicketSalon?.address ?? '';

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Queue & Recent Token',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColorSchemes.charcoal),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CustomerHistoryScreen()),
                      ).then((_) => _loadData());
                    },
                    icon: const Icon(Icons.history_rounded, size: 16, color: AppColorSchemes.navy),
                    label: const Text('All History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Recent Completed Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF14243A), Color(0xFF1E3650)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF14243A).withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'RECENT TOKEN',
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
                            color: const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'COMPLETED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _latestTicket!.formattedToken,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              salonName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              salonAddress,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 44),
                      ],
                    ),

                    const Divider(color: Colors.white24, height: 28),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Services: ${_latestTicket!.serviceNames.join(", ")}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          '₹${_latestTicket!.totalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Color(0xFFC9A45C),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CustomerQueueScreen(
                                    ticket: _latestTicket!,
                                    salon: _latestTicketSalon,
                                  ),
                                ),
                              ).then((_) => _loadData());
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white54),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('View Token Details'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => setState(() => _currentTabIndex = 0),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColorSchemes.gold,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Book Next Visit'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Banner
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColorSchemes.navy.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.storefront_rounded, color: AppColorSchemes.navy, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ready for another grooming?',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Browse top-rated salons nearby and join queues with zero wait time.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
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

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColorSchemes.navy.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.confirmation_number_outlined, size: 64, color: AppColorSchemes.navy),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Active Queue Ticket',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColorSchemes.charcoal),
              ),
              const SizedBox(height: 8),
              Text(
                'You have not joined any salon queue yet. Search nearby salons on the Home tab and join a queue in 1 tap!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => setState(() => _currentTabIndex = 0),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('EXPLORE SALONS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColorSchemes.gold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  // ═══════════════════════════════════════════════════════════════════════════
  // ── 10. BOTTOM NAVIGATION BAR ─────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (idx) {
            if (idx == 2) {
              // Quick QR Scan action
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              ).then((_) => _loadData());
              return;
            }
            setState(() => _currentTabIndex = idx);
            if (idx == 0) _loadData();
          },
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFFE91E63), // Pink/Purple active accent matching reference
          unselectedItemColor: const Color(0xFF9CA3AF),
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today_rounded),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF10233F),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x3310233F),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFD4AF5A), size: 22),
              ),
              label: 'Scan',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.confirmation_number_outlined),
              activeIcon: Icon(Icons.confirmation_number_rounded),
              label: 'My Queue',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── APP DRAWER ────────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAppDrawer(BuildContext context) {
    final auth = AuthScope.of(context, listen: false);

    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColorSchemes.navy, AppColorSchemes.navyLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColorSchemes.gold, width: 1),
                  ),
                  child: const Icon(Icons.content_cut, color: AppColorSchemes.gold, size: 24),
                ),
                const SizedBox(height: 10),
                const Text(
                  'SALON QUEUE',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const Text(
                  AppConstants.appTaglineShort,
                  style: TextStyle(color: AppColorSchemes.goldLight, fontSize: 11),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner, color: AppColorSchemes.navy),
            title: const Text('Scan Salon QR Code'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              ).then((_) => _loadData());
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
            title: const Text('Sign Out', style: TextStyle(color: Color(0xFFEF4444))),
            onTap: () async {
              Navigator.pop(context);
              await auth.signOut();
              if (!context.mounted) return;
              AppRouter.navigateToWelcomeAfterLogout(context);
            },
          ),
        ],
      ),
    );
  }
}
