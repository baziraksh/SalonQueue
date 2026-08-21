import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
import 'customer_search_screen.dart';
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
    // 1. Instant frame-1 cache retrieval to display cached salons immediately without spinner
    final cached = _salonRepo.getCachedSalons(
      state: _selectedState == 'All States' ? null : _selectedState,
      city: (_selectedLocation == 'All India' || _selectedLocation == 'Near Me') ? null : (_selectedCity ?? _selectedLocation),
      district: _selectedDistrict,
      pincode: _selectedPincode,
      search: _searchController.text.trim(),
      category: (_selectedCategory == 'All' || _selectedCategory == 'Favorites') ? null : _selectedCategory,
      sortBy: _sortBy,
      userLat: _userLat,
      userLng: _userLng,
    );
    if (cached.isNotEmpty) {
      _salons = cached;
      _isLoading = false;
    }

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
    // Only set loading indicator if we don't already have salons on screen
    if (_salons.isEmpty) {
      setState(() => _isLoading = true);
    }

    final auth = AuthScope.of(context, listen: false);
    final userId = auth.currentUser?.id;

    final isAllIndia = (_selectedLocation == 'All India' || _selectedLocation == 'All Cities');
    final isAllStates = (_selectedState == 'All States' || _selectedState == 'All');
    final isNearMe = (_selectedLocation == 'Near Me');

    // Run salon query and ticket query concurrently in parallel for maximum speed
    final salonFuture = _salonRepo.fetchSalons(
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

    final ticketsFuture = (userId != null)
        ? Future.wait([
            _queueRepo.fetchActiveTicketForCustomer(userId),
            _queueRepo.fetchLatestTicketForCustomer(userId),
          ])
        : Future.value(<dynamic>[null, null]);

    try {
      final results = await Future.wait([salonFuture, ticketsFuture]);
      var list = results[0] as List<Salon>;

      if (userId != null) {
        final ticketData = results[1];
        _activeTicket = ticketData[0] as QueueTicket?;
        _latestTicket = ticketData[1] as QueueTicket?;
        if (_latestTicket != null) {
          _latestTicketSalon = await _salonRepo.fetchSalonById(_latestTicket!.salonId);
        }
      }

      if (_selectedCategory == 'Favorites' || _currentTabIndex == 3) {
        list = list.where((s) => _favoriteSalonIds.contains(s.id)).toList();
      }

      if (!mounted) return;
      setState(() {
        _salons = list;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Exact Location Selector Modal matching Reference Image 2
  void showAllIndiaLocationSelector() {
    final locationSearchCtrl = TextEditingController();
    List<LocationSuggestion> searchResults = [];
    bool isSearching = false;
    Timer? debounceTimer;

    // Canonical list of Popular Cities across India using the existing dataset
    const popularCities = [
      {'city': 'Bhubaneswar', 'state': 'Odisha', 'district': 'Khurda'},
      {'city': 'Cuttack', 'state': 'Odisha', 'district': 'Cuttack'},
      {'city': 'Pune', 'state': 'Maharashtra', 'district': 'Pune'},
      {'city': 'Mumbai', 'state': 'Maharashtra', 'district': 'Mumbai City'},
      {'city': 'Bengaluru', 'state': 'Karnataka', 'district': 'Bangalore Urban'},
      {'city': 'Delhi', 'state': 'Delhi', 'district': 'Central Delhi'},
      {'city': 'Hyderabad', 'state': 'Telangana', 'district': 'Hyderabad'},
      {'city': 'Kolkata', 'state': 'West Bengal', 'district': 'Kolkata'},
      {'city': 'Chennai', 'state': 'Tamil Nadu', 'district': 'Chennai'},
      {'city': 'Ahmedabad', 'state': 'Gujarat', 'district': 'Ahmedabad'},
      {'city': 'Jaipur', 'state': 'Rajasthan', 'district': 'Jaipur'},
      {'city': 'Chandigarh', 'state': 'Punjab', 'district': 'Chandigarh'},
      {'city': 'Angul', 'state': 'Odisha', 'district': 'Angul'},
      {'city': 'Pallahara', 'state': 'Odisha', 'district': 'Angul'},
      {'city': 'Rourkela', 'state': 'Odisha', 'district': 'Sundargarh'},
      {'city': 'Berhampur', 'state': 'Odisha', 'district': 'Ganjam'},
      {'city': 'Sambalpur', 'state': 'Odisha', 'district': 'Sambalpur'},
      {'city': 'Puri', 'state': 'Odisha', 'district': 'Puri'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
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
                  // 1. Header with Close X
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Location across India 🇮🇳',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                        onPressed: () {
                          debounceTimer?.cancel();
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 2. Search Field
                  TextField(
                    controller: locationSearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search locality, street, city or PIN code...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6D28D9)),
                      suffixIcon: isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6D28D9)),
                              ),
                            )
                          : (locationSearchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
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
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
                      ),
                    ),
                    onChanged: performSearch,
                  ),
                  const SizedBox(height: 12),

                  // 3. Quick Action Chips: Near Me & All India
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.navigation_rounded, size: 15, color: Color(0xFFD4AF5A)),
                          label: const Text('📍 Near Me'),
                          backgroundColor: const Color(0xFF10233F),
                          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                          avatar: const Icon(Icons.public, size: 16, color: Color(0xFF6D28D9)),
                          label: const Text('All India 🇮🇳'),
                          backgroundColor: Colors.white,
                          labelStyle: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700, fontSize: 12.5),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  const SizedBox(height: 16),

                  // 4. Section Title or Search Results
                  if (searchResults.isEmpty && locationSearchCtrl.text.trim().isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8, left: 4),
                      child: Text(
                        'Popular Cities',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],

                  // 5. Popular Cities List or Live Search Results
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (isSearching && searchResults.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(color: Color(0xFF6D28D9)),
                          );
                        }

                        if (searchResults.isNotEmpty) {
                          return ListView.separated(
                            itemCount: searchResults.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                            itemBuilder: (context, idx) {
                              final item = searchResults[idx];
                              return ListTile(
                                leading: const Icon(
                                  Icons.location_on_outlined,
                                  color: Color(0xFF6D28D9),
                                  size: 22,
                                ),
                                title: Text(
                                  item.title,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111827)),
                                ),
                                subtitle: Text(
                                  item.subtitle,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  debounceTimer?.cancel();
                                  setState(() {
                                    _selectedLocation = (item.city != null && item.state != null)
                                        ? '${item.city}, ${item.state}'
                                        : item.title;
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
                                leading: const Icon(
                                  Icons.location_on_outlined,
                                  color: Color(0xFF6D28D9),
                                  size: 22,
                                ),
                                title: Text(
                                  'Find Salons in "$queryText"',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111827)),
                                ),
                                subtitle: const Text(
                                  'Search salons by this area or locality name',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF9CA3AF)),
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
                            ],
                          );
                        }

                        // Default: Popular Cities List (Exact Match to Image 2)
                        return ListView.builder(
                          itemCount: popularCities.length,
                          itemBuilder: (context, idx) {
                            final item = popularCities[idx];
                            final cityName = item['city']!;
                            final stateName = item['state']!;
                            final districtName = item['district'];

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              leading: const Icon(
                                Icons.apartment_rounded,
                                color: Color(0xFF6D28D9),
                                size: 24,
                              ),
                              title: Text(
                                cityName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFF111827),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              subtitle: Text(
                                stateName,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              onTap: () {
                                debounceTimer?.cancel();
                                final estCoords = LocationSuggestionService.getEstimatedCoordinates(
                                  cityName,
                                  stateName,
                                );
                                final resolvedDistrict = districtName ??
                                    IndiaLocations.resolveDistrictForCity(cityName, stateName) ??
                                    cityName;
                                setState(() {
                                  _selectedState = stateName;
                                  _selectedLocation = '$cityName, $stateName';
                                  _selectedCity = cityName;
                                  _selectedDistrict = resolvedDistrict;
                                  _selectedPincode = null;
                                  _userLat = estCoords.latitude;
                                  _userLng = estCoords.longitude;
                                });
                                Navigator.of(ctx).pop();
                                _loadData();
                              },
                            );
                          },
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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

              const SizedBox(height: 12),

              // ── 5. Nearby Salons (Horizontal Scroll) ───────────────────
              _buildNearbySalonsSection(),

              const SizedBox(height: 12),

              // ── 6. Popular Services (Horizontal Icons) ─────────────────
              _buildPopularServicesSection(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Top Header Widget ───────────────────────────────────────────────────
  Widget _buildTopHeader(BuildContext context) {
    final auth = AuthScope.of(context); // Listen to real-time auth/profile changes
    final user = auth.currentUser;
    final avatar = user?.avatarUrl;
    final fullName = user?.fullName?.trim();
    final firstName = (fullName != null && fullName.isNotEmpty)
        ? fullName.split(' ').first
        : 'Rakesh';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
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
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Find and book the best salons',
                  style: TextStyle(
                    fontSize: 13,
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
                width: 40,
                height: 40,
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
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Badge.count(
                    count: _unreadNotifsCount,
                    isLabelVisible: _unreadNotifsCount > 0,
                    backgroundColor: const Color(0xFFE91E63),
                    textColor: Colors.white,
                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 9),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF111827),
                      size: 20,
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
              const SizedBox(width: 10),

              // Profile Avatar (Dark navy circular button showing customer's actual profile photo)
              GestureDetector(
                onTap: () {
                  setState(() => _currentTabIndex = 4);
                },
                child: Container(
                  width: 40,
                  height: 40,
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
                  child: ClipOval(
                    child: _buildAvatarImage(avatar),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage(String? path) {
    if (path == null || path.trim().isEmpty) {
      return const Icon(Icons.person, size: 20, color: Color(0xFFD4AF5A));
    }
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        key: ValueKey(trimmed),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 20, color: Color(0xFFD4AF5A)),
      );
    } else if (trimmed.startsWith('data:image')) {
      try {
        final base64Str = trimmed.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          key: ValueKey(trimmed.hashCode),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 20, color: Color(0xFFD4AF5A)),
        );
      } catch (_) {
        return const Icon(Icons.person, size: 20, color: Color(0xFFD4AF5A));
      }
    } else {
      final file = File(trimmed);
      if (file.existsSync()) {
        return Image.file(
          file,
          key: ValueKey(trimmed),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 20, color: Color(0xFFD4AF5A)),
        );
      }
      return const Icon(Icons.person, size: 20, color: Color(0xFFD4AF5A));
    }
  }

  void _openSearchScreen({String? query, String? category}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerSearchScreen(
          initialQuery: query,
          initialCategory: category,
          initialLocation: _selectedLocation,
        ),
      ),
    ).then((_) => _loadData());
  }

  // ── 2. Search Area ─────────────────────────────────────────────────────────
  Widget _buildSearchArea() {
    return GestureDetector(
      onTap: () => _openSearchScreen(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(
              Icons.search_rounded,
              color: Color(0xFF6B7280),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                readOnly: true,
                onTap: () => _openSearchScreen(),
                decoration: const InputDecoration(
                  hintText: 'Search salon, services or location',
                  hintStyle: TextStyle(
                    fontSize: 13,
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
            // Right-side manual search & location/options button
            InkWell(
              onTap: showAllIndiaLocationSelector,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFF111827),
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. Promotional Banner ──────────────────────────────────────────────────
  Widget _buildPromotionalBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      height: 145,
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
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Left Content
          Positioned(
            left: 18,
            top: 14,
            bottom: 14,
            right: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skip the Wait',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.15,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Book Your',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.15,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Slot Now',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.15,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_salons.isNotEmpty) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SalonDetailsScreen(salon: _salons.first),
                        ),
                      ).then((_) => _loadData());
                    } else {
                      _openSearchScreen();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF111827),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Book Now',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right Salon Chair Visual (Exact match to Image 1)
          Positioned(
            right: 6,
            bottom: 2,
            top: 2,
            width: 140,
            child: Image.asset(
              'assets/images/salon_chair.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomRight,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(
                  Icons.chair_rounded,
                  size: 70,
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
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
              InkWell(
                onTap: () => _openSearchScreen(),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6D28D9),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Horizontal List of Salon Cards
        if (_isLoading)
          const SizedBox(
            height: 165,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF6D28D9)),
            ),
          )
        else if (_salons.isEmpty)
          _buildEmptyNearbySalons()
        else
          SizedBox(
            height: 165,
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
        width: 165,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F3F5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    color: const Color(0xFF1E293B),
                    child: _buildSalonCardImage(salon.effectiveCoverImage),
                  ),
                ),
                // Heart Favorite Button on bottom-right of image (Matching Image 1)
                Positioned(
                  bottom: 6,
                  right: 6,
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
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_rounded,
                        color: const Color(0xFFEF4444),
                        size: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Card Body
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    salon.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 15),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          '$rating ($reviews)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        distanceStr,
                        style: const TextStyle(
                          fontSize: 11,
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
          height: 100,
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
            height: 100,
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
      height: 100,
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
          size: 32,
        ),
      ),
    );
  }

  Widget _buildEmptyNearbySalons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFEDE9FE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_outlined, color: Color(0xFF6D28D9), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No Salons in this View',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Change location or clear search to find salons.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
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
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
              InkWell(
                onTap: () => _openSearchScreen(category: 'All'),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6D28D9),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

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
                  setState(() => _selectedCategory = filter);
                  _openSearchScreen(category: filter);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6D28D9)
                            : const Color(0xFFF3E8FF), // Light pastel purple
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF6D28D9)
                              : const Color(0xFFE9D5FF),
                          width: 1.0,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: const Color(0xFF6D28D9).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? Colors.white : const Color(0xFF6D28D9),
                        size: 21,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 11,
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
