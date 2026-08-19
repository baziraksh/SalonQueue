import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/color_schemes.dart';
import '../../../shared/data/india_locations.dart';
import '../../../shared/models/queue_ticket.dart';
import '../../../shared/models/salon.dart';
import '../../../shared/widgets/active_queue_card.dart';
import '../../../shared/widgets/benefit_item.dart';
import '../../../shared/widgets/salon_card.dart';
import '../../../shared/widgets/service_card.dart';
import '../../auth/services/auth_scope.dart';
import 'customer_history_screen.dart';
import 'customer_profile_screen.dart';
import 'easy_booking_screen.dart';
import 'security_privacy_screen.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/screens/customer_notifications_screen.dart';
import '../../queue/data/queue_repository.dart';
import '../../queue/screens/customer_queue_screen.dart';
import '../../qr/screens/qr_scanner_screen.dart';
import '../../salon/data/salon_repository.dart';
import '../../salon/screens/salon_details_screen.dart';
import '../../support/screens/support_center_screen.dart';
import '../services/location_suggestion_service.dart';

/// Customer Home & All-India Salon Discovery Dashboard
/// Redesigned in luxury Navy (#14243A) & Gold (#C9A45C) SalonQueue marketplace aesthetic.
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
  bool _isShowing10KmFallback = false;
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

  bool _isRealtimeOnlyFilter = false;
  bool _isVerifiedOnlyFilter = false;

  final List<Map<String, String>> _categories = [
    {'name': 'All', 'icon': '✨'},
    {'name': 'Favorites', 'icon': '❤️'},
    {'name': 'Hair', 'icon': '✂️'},
    {'name': 'Beard', 'icon': '🧔'},
    {'name': 'Facial', 'icon': '💆'},
    {'name': 'Spa', 'icon': '💈'},
    {'name': 'Color', 'icon': '🎨'},
    {'name': 'Combo', 'icon': '🎁'},
  ];

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

    var list = await _salonRepo.fetchSalons(
      state: isAllStates ? null : _selectedState,
      city: isAllIndia ? null : (_selectedCity ?? _selectedLocation),
      district: _selectedDistrict,
      pincode: _selectedPincode,
      search: _searchController.text.trim(),
      category: (_selectedCategory == 'All' || _selectedCategory == 'Favorites')
          ? null
          : _selectedCategory,
      sortBy: _sortBy,
      userLat: _userLat,
      userLng: _userLng,
    );

    // If exact city/locality search returned 0 items, expand search to nearby and named matches
    bool is10kmFallback = false;
    if (list.isEmpty && !isAllIndia) {
      final queryText = _searchController.text.trim();
      final broaderSalons = await _salonRepo.fetchSalons(
        state: isAllStates ? null : _selectedState,
        search: queryText,
        category: (_selectedCategory == 'All' || _selectedCategory == 'Favorites')
            ? null
            : _selectedCategory,
        sortBy: _sortBy,
        userLat: _userLat,
        userLng: _userLng,
        maxRadiusKm: 25.0,
      );
      if (broaderSalons.isNotEmpty) {
        list = broaderSalons;
        is10kmFallback = true;
      } else if (queryText.isNotEmpty) {
        // Match salon name or service globally across all locations
        final globalMatches = await _salonRepo.fetchSalons(
          search: queryText,
          category: (_selectedCategory == 'All' || _selectedCategory == 'Favorites')
              ? null
              : _selectedCategory,
          sortBy: _sortBy,
          userLat: _userLat,
          userLng: _userLng,
        );
        if (globalMatches.isNotEmpty) {
          list = globalMatches;
        }
      }
    }

    if (_isVerifiedOnlyFilter) {
      list = list.where((s) => s.isVerified).toList();
    }

    if (_isRealtimeOnlyFilter) {
      list = list.where((s) => s.isQueueOpen).toList();
    }

    if (_selectedCategory == 'Favorites' || _currentTabIndex == 3) {
      list = list.where((s) => _favoriteSalonIds.contains(s.id)).toList();
    }

    if (!mounted) return;
    setState(() {
      _salons = list;
      _isShowing10KmFallback = is10kmFallback;
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
        backgroundColor: AppColorSchemes.ivory,
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
    final theme = Theme.of(context);

    return SafeArea(
      child: RefreshIndicator(
        color: AppColorSchemes.navy,
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Top Header ──────────────────────────────────────────
              _buildTopHeader(context),

              // ── 2. Hero Section ────────────────────────────────────────
              _buildHeroSection(),

              // ── 3. Search & Filter Card ────────────────────────────────
              _buildSearchFilterCard(),

              // ── 4. Quick Benefits ──────────────────────────────────────
              _buildQuickBenefits(),

              // ── 5. Active Queue Card (if active) ───────────────────────
              if (_activeTicket != null && (_activeTicket!.isWaiting || _activeTicket!.isInChair))
                ActiveQueueCard(
                  ticket: _activeTicket!,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CustomerQueueScreen(ticket: _activeTicket!),
                      ),
                    ).then((_) => _loadData());
                  },
                ),

              const SizedBox(height: 16),

              // ── 6. Popular Services Section ────────────────────────────
              _buildPopularServicesSection(),

              const SizedBox(height: 20),

              // ── 7. Nearby Salons Section Header ────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nearby Salons',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColorSchemes.charcoal,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Real-time queue & live crowd tracker',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),

                    // Sort Filter Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortBy,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down, color: AppColorSchemes.navy, size: 20),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColorSchemes.navy,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'nearest', child: Text('📍 Nearest')),
                            DropdownMenuItem(value: 'rush', child: Text('🟢 Low Rush')),
                            DropdownMenuItem(value: 'rating', child: Text('⭐ Rating')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _sortBy = val);
                              _loadData();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── 7. Salons List ─────────────────────────────────────────
              if (_isShowing10KmFallback && _salons.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColorSchemes.gold.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColorSchemes.gold.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.near_me, color: Color(0xFFB8860B), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Showing Nearest Salons (within 10 km)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'No direct salon registered in "$_selectedLocation". We found ${_salons.length} nearby verified salons for you.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(color: AppColorSchemes.gold),
                  ),
                )
              else if (_salons.isEmpty)
                _buildEmptySalonsView(theme)
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _salons.length,
                  itemBuilder: (context, idx) {
                    final salon = _salons[idx];
                    final isFav = _favoriteSalonIds.contains(salon.id);

                    return SalonCard(
                      salon: salon,
                      isFavorite: isFav,
                      onFavoriteTap: () {
                        setState(() {
                          if (isFav) {
                            _favoriteSalonIds.remove(salon.id);
                          } else {
                            _favoriteSalonIds.add(salon.id);
                          }
                        });
                        if (_selectedCategory == 'Favorites') {
                          _loadData();
                        }
                      },
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

              const SizedBox(height: 24),

              // ── 8. "How SalonQueue Works" Section ──────────────────────
              _buildHowItWorksSection(),

              const SizedBox(height: 20),

              // ── 9. Notification CTA Card ───────────────────────────────
              _buildNotificationCtaCard(),

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

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Salon Queue Logo & Name
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColorSchemes.navy,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColorSchemes.gold, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColorSchemes.navy.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.content_cut, color: AppColorSchemes.gold, size: 18),
              ),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SALON QUEUE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColorSchemes.navy,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Text(
                    AppConstants.appTaglineShort,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColorSchemes.gold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right: Notification Bell (with Badge) & Customer Profile Avatar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Badge.count(
                  count: _unreadNotifsCount,
                  isLabelVisible: _unreadNotifsCount > 0,
                  backgroundColor: AppColorSchemes.gold,
                  textColor: AppColorSchemes.navy,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: AppColorSchemes.navy,
                    size: 25,
                  ),
                ),
                tooltip: 'Notifications',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CustomerNotificationsScreen(),
                    ),
                  ).then((_) => _loadNotifications());
                },
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() => _currentTabIndex = 4);
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColorSchemes.gold, width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: AppColorSchemes.navy,
                    child: avatar != null && avatar.isNotEmpty
                        ? ClipOval(
                            child: _buildAvatarImage(avatar),
                          )
                        : const Icon(Icons.person, size: 18, color: AppColorSchemes.gold),
                  ),
                ),
              ),
              const SizedBox(
                width: 0,
                height: 0,
                child: Icon(Icons.logout, size: 0),
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
        width: 30,
        height: 30,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.person, size: 18, color: AppColorSchemes.gold),
      );
    }
    return const Icon(Icons.person, size: 18, color: AppColorSchemes.gold);
  }

  // ── 2. Hero Section ────────────────────────────────────────────────────────
  Widget _buildHeroSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColorSchemes.navy,
            Color(0xFF1B2E46),
            Color(0xFF243B55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColorSchemes.navy.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left headline text
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find a Salon.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const Text(
                  'Check the Queue.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const Text(
                  'Get Served.',
                  style: TextStyle(
                    color: AppColorSchemes.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Live queue updates from salons near you.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          // Right decorative graphic
          Expanded(
            flex: 2,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColorSchemes.gold.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.storefront_rounded,
                  color: AppColorSchemes.gold,
                  size: 48,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Search & Filter Card ────────────────────────────────────────────────
  Widget _buildSearchFilterCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location Selector Button
          InkWell(
            onTap: _showAllIndiaLocationSelector,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColorSchemes.ivory,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColorSchemes.gold, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LOCATION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          _selectedLocation == 'All India'
                              ? 'All India 🇮🇳'
                              : (_selectedPincode != null && _selectedPincode!.isNotEmpty
                                  ? '$_selectedLocation, $_selectedState (${_selectedPincode!})'
                                  : '$_selectedLocation, $_selectedState'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColorSchemes.charcoal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: AppColorSchemes.navy),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Search Salon / Haircut TextField
          TextField(
            controller: _searchController,
            onChanged: (_) => _loadData(),
            decoration: InputDecoration(
              hintText: 'Search salon, haircut, facial...',
              prefixIcon: const Icon(Icons.search, color: AppColorSchemes.navy),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _loadData();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              fillColor: AppColorSchemes.ivory,
            ),
          ),

          const SizedBox(height: 12),

          // Large Gold "FIND SALONS" Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColorSchemes.gold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'FIND SALONS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Quick Benefits Grid ─────────────────────────────────────────────────
  Widget _buildQuickBenefits() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: BenefitItem(
              icon: Icons.timer_outlined,
              title: 'Real-time Queue',
              subtitle: 'Live wait times',
              isSelected: _isRealtimeOnlyFilter,
              onTap: () {
                setState(() {
                  _isRealtimeOnlyFilter = !_isRealtimeOnlyFilter;
                  if (_isRealtimeOnlyFilter) _sortBy = 'rush';
                });
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isRealtimeOnlyFilter
                          ? 'Showing salons with active live queue tracking.'
                          : 'Showing all nearby salons.',
                    ),
                    duration: const Duration(seconds: 2),
                    backgroundColor: AppColorSchemes.navy,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: BenefitItem(
              icon: Icons.verified_outlined,
              title: 'Verified Salons',
              subtitle: 'Trusted & rated',
              isSelected: _isVerifiedOnlyFilter,
              onTap: () {
                setState(() {
                  _isVerifiedOnlyFilter = !_isVerifiedOnlyFilter;
                });
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isVerifiedOnlyFilter
                          ? 'Showing verified salons only.'
                          : 'Showing all nearby salons.',
                    ),
                    duration: const Duration(seconds: 2),
                    backgroundColor: AppColorSchemes.navy,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: BenefitItem(
              icon: Icons.touch_app_outlined,
              title: 'Easy Booking',
              subtitle: 'Join in 1 tap',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EasyBookingScreen(),
                  ),
                ).then((_) => _loadData());
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: BenefitItem(
              icon: Icons.shield_outlined,
              title: 'Secure & Safe',
              subtitle: 'Data protected',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SecurityPrivacyScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. Popular Services Horizontal Scroll ──────────────────────────────────
  Widget _buildPopularServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Popular Services',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColorSchemes.charcoal,
                  letterSpacing: -0.2,
                ),
              ),
              if (_selectedCategory != 'All')
                GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = 'All');
                    _loadData();
                  },
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColorSchemes.gold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            itemBuilder: (context, idx) {
              final item = _categories[idx];
              final name = item['name']!;
              final icon = item['icon']!;
              final isSelected = _selectedCategory == name;

              return ServiceCard(
                name: name,
                icon: icon,
                isSelected: isSelected,
                onTap: () {
                  setState(() => _selectedCategory = name);
                  _loadData();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── 8. "How SalonQueue Works" Section ──────────────────────────────────────
  Widget _buildHowItWorksSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColorSchemes.navy,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColorSchemes.navy.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColorSchemes.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lightbulb_outline, color: AppColorSchemes.gold, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'How SalonQueue Works',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Step 1
          _buildHowItWorksStep(
            number: '1',
            title: 'Find a Salon',
            description: 'Search salons near you with live availability and verified reviews.',
          ),
          const SizedBox(height: 12),

          // Step 2
          _buildHowItWorksStep(
            number: '2',
            title: 'Check Queue',
            description: 'See live waiting tokens, chair count, and estimated wait time.',
          ),
          const SizedBox(height: 12),

          // Step 3
          _buildHowItWorksStep(
            number: '3',
            title: 'Join Queue',
            description: 'Join the queue remotely from home and get live position updates.',
          ),
          const SizedBox(height: 12),

          // Step 4
          _buildHowItWorksStep(
            number: '4',
            title: 'Get Served',
            description: 'Reach the salon right when it\'s your turn without wasting time waiting.',
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColorSchemes.gold,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 9. Notification CTA Card ───────────────────────────────────────────────
  Widget _buildNotificationCtaCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColorSchemes.gold.withValues(alpha: 0.4)),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColorSchemes.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_active, color: AppColorSchemes.gold, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Never Miss Your Turn!',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColorSchemes.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Get notified when it\'s almost your turn.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications enabled! You\'ll be alerted before your turn.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColorSchemes.navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('ENABLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptySalonsView(ThemeData theme) {
    if (_isVerifiedOnlyFilter) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColorSchemes.navy.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_outlined, size: 48, color: AppColorSchemes.navy),
              ),
              const SizedBox(height: 14),
              const Text(
                'No verified salons available nearby.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColorSchemes.charcoal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Try selecting another location or browse all salons.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () {
                  setState(() => _isVerifiedOnlyFilter = false);
                  _loadData();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColorSchemes.gold),
                  foregroundColor: AppColorSchemes.navy,
                ),
                child: const Text('Show All Salons', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No salons found in $_selectedLocation',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColorSchemes.charcoal,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Try selecting another city or changing filters.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
      final salonName = _latestTicketSalon?.name ?? 'Salon Lounge';
      final salonAddress = _latestTicketSalon?.address ?? 'Main Road';

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
          selectedItemColor: AppColorSchemes.navy,
          unselectedItemColor: Colors.grey.shade400,
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
                padding: const EdgeInsets.all(7),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColorSchemes.navy, AppColorSchemes.navyLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x3314243A),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: AppColorSchemes.gold, size: 22),
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
          ListTile(
            leading: const Icon(Icons.history, color: AppColorSchemes.navy),
            title: const Text('Visit History & Bookings'),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentTabIndex = 1);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person, color: AppColorSchemes.navy),
            title: const Text('My Profile & Account'),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentTabIndex = 4);
            },
          ),
          ListTile(
            leading: Badge.count(
              count: _unreadNotifsCount,
              isLabelVisible: _unreadNotifsCount > 0,
              backgroundColor: AppColorSchemes.gold,
              textColor: AppColorSchemes.navy,
              child: const Icon(Icons.notifications_outlined, color: AppColorSchemes.navy),
            ),
            title: const Text('Notifications'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CustomerNotificationsScreen(),
                ),
              ).then((_) => _loadNotifications());
            },
          ),
          ListTile(
            leading: const Icon(Icons.shield_outlined, color: AppColorSchemes.navy),
            title: const Text('Security & Privacy'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SecurityPrivacyScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline_rounded, color: AppColorSchemes.navy),
            title: const Text('Help & Support Center'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SupportCenterScreen(isOwner: false),
                ),
              );
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
