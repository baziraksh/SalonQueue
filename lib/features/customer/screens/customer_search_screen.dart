import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../shared/data/india_locations.dart';
import '../../../shared/models/salon.dart';
import '../../salon/data/salon_repository.dart';
import '../../salon/screens/salon_details_screen.dart';
import '../services/location_suggestion_service.dart';

/// Dedicated Customer Search Screen
/// Matches the reference Search UI with dynamic backend data and real-time filters.
class CustomerSearchScreen extends StatefulWidget {
  final String? initialQuery;
  final String? initialCategory;
  final String? initialLocation;

  const CustomerSearchScreen({
    super.key,
    this.initialQuery,
    this.initialCategory,
    this.initialLocation,
  });

  @override
  State<CustomerSearchScreen> createState() => _CustomerSearchScreenState();
}

class _CustomerSearchScreenState extends State<CustomerSearchScreen> {
  final SalonRepository _salonRepo = SalonRepository();

  late final TextEditingController _searchController;
  Timer? _debounceTimer;

  String _selectedLocation = 'Bhubaneswar, Odisha';
  String _selectedState = 'Odisha';
  String? _selectedCity = 'Bhubaneswar';
  String? _selectedDistrict;
  String? _selectedPincode;
  double _userLat = 20.2961;
  double _userLng = 85.8245;

  String _selectedFilter = 'All'; // 'All', 'Men', 'Women', 'Unisex'
  String _sortBy = 'nearest'; // 'nearest', 'rating', 'rush'
  final Set<String> _favoriteSalonIds = {};

  List<Salon> _salons = [];
  bool _isLoading = true;

  final List<String> _filterCategories = ['All', 'Men', 'Women', 'Unisex'];

  static const List<Map<String, String>> _popularIndianCities = [
    {'name': 'Bhubaneswar', 'state': 'Odisha'},
    {'name': 'Cuttack', 'state': 'Odisha'},
    {'name': 'Pune', 'state': 'Maharashtra'},
    {'name': 'Mumbai', 'state': 'Maharashtra'},
    {'name': 'Bengaluru', 'state': 'Karnataka'},
    {'name': 'Delhi', 'state': 'Delhi'},
    {'name': 'Hyderabad', 'state': 'Telangana'},
    {'name': 'Kolkata', 'state': 'West Bengal'},
    {'name': 'Chennai', 'state': 'Tamil Nadu'},
    {'name': 'Jaipur', 'state': 'Rajasthan'},
    {'name': 'Ahmedabad', 'state': 'Gujarat'},
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialLocation != null && widget.initialLocation!.isNotEmpty) {
      _selectedLocation = widget.initialLocation!;
      if (_selectedLocation == 'All India') {
        _selectedState = 'All States';
        _selectedCity = null;
      }
    }
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      _selectedFilter = widget.initialCategory!;
    }
    _loadSalons();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _loadSalons();
    });
  }

  Future<void> _loadSalons() async {
    setState(() => _isLoading = true);

    final isAllIndia = (_selectedLocation == 'All India' || _selectedLocation == 'All Cities');
    final isAllStates = (_selectedState == 'All States' || _selectedState == 'All');
    final isNearMe = (_selectedLocation == 'Near Me');

    try {
      var list = await _salonRepo.fetchSalons(
        state: isAllStates ? null : _selectedState,
        city: (isAllIndia || isNearMe) ? null : (_selectedCity ?? _selectedLocation.split(',').first.trim()),
        district: _selectedDistrict,
        pincode: _selectedPincode,
        search: _searchController.text.trim(),
        category: (_selectedFilter == 'All') ? null : _selectedFilter,
        sortBy: _sortBy,
        userLat: _userLat,
        userLng: _userLng,
        maxRadiusKm: isNearMe ? 25.0 : null,
      );

      if (mounted) {
        setState(() {
          _salons = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleFavorite(String salonId) {
    setState(() {
      if (_favoriteSalonIds.contains(salonId)) {
        _favoriteSalonIds.remove(salonId);
      } else {
        _favoriteSalonIds.add(salonId);
      }
    });
  }

  void _showSortFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sort & Filter Salons',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sort by',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildSortChip('📍 Nearest', 'nearest', setModalState),
                      _buildSortChip('⭐ Rating', 'rating', setModalState),
                      _buildSortChip('🟢 Low Rush', 'rush', setModalState),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _loadSalons();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D28D9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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

  Widget _buildSortChip(String label, String value, StateSetter setModalState) {
    final isSelected = _sortBy == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFFEDE9FE),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFF111827),
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFFE5E7EB),
        width: isSelected ? 1.5 : 1.0,
      ),
      onSelected: (selected) {
        if (selected) {
          setModalState(() => _sortBy = value);
          setState(() => _sortBy = value);
        }
      },
    );
  }

  /// All-India & Local Area Location Selector Bottom Sheet
  void _showLocationSelector() {
    final locationSearchCtrl = TextEditingController();
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
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            void performSearch(String query) {
              debounceTimer?.cancel();
              if (query.trim().length < 2) {
                setModalState(() {
                  searchResults = [];
                  isSearching = false;
                });
                return;
              }
              setModalState(() => isSearching = true);
              debounceTimer = Timer(const Duration(milliseconds: 300), () async {
                final results = await LocationSuggestionService.searchLocationSuggestions(query);
                if (modalCtx.mounted) {
                  setModalState(() {
                    searchResults = results;
                    isSearching = false;
                  });
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.80,
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
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            debounceTimer?.cancel();
                            Navigator.of(ctx).pop();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search input
                    TextField(
                      controller: locationSearchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search locality, street, city or PIN code...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6D28D9)),
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

                    // Quick Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.my_location, size: 16, color: Color(0xFFD4AF5A)),
                            label: const Text('📍 Near Me'),
                            backgroundColor: const Color(0xFF10233F),
                            labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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
                              _loadSalons();
                            },
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            avatar: const Icon(Icons.public, size: 16, color: Color(0xFF6D28D9)),
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
                              _loadSalons();
                            },
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            label: const Text('Bhubaneswar, Odisha'),
                            onPressed: () {
                              debounceTimer?.cancel();
                              setState(() {
                                _selectedLocation = 'Bhubaneswar, Odisha';
                                _selectedCity = 'Bhubaneswar';
                                _selectedDistrict = 'Khordha';
                                _selectedState = 'Odisha';
                                _selectedPincode = '751001';
                                _userLat = 20.2961;
                                _userLng = 85.8245;
                              });
                              Navigator.of(ctx).pop();
                              _loadSalons();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Expanded(
                      child: isSearching
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6D28D9)))
                          : searchResults.isNotEmpty
                              ? ListView.separated(
                                  itemCount: searchResults.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (c, idx) {
                                    final item = searchResults[idx];
                                    return ListTile(
                                      leading: const Icon(Icons.location_on_outlined, color: Color(0xFF6D28D9)),
                                      title: Text(item.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                      subtitle: Text(item.subtitle, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                                      onTap: () {
                                        debounceTimer?.cancel();
                                        setState(() {
                                          _selectedLocation = (item.city != null && item.state != null)
                                              ? '${item.city}, ${item.state}'
                                              : item.title;
                                          _selectedCity = item.city ?? item.title;
                                          _selectedDistrict = item.district;
                                          _selectedState = item.state ?? _selectedState;
                                          _selectedPincode = item.pincode;
                                          _userLat = item.latitude;
                                          _userLng = item.longitude;
                                        });
                                        Navigator.of(ctx).pop();
                                        _loadSalons();
                                      },
                                    );
                                  },
                                )
                              : ListView(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Text(
                                        'Popular Cities',
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF6B7280)),
                                      ),
                                    ),
                                    ..._popularIndianCities.map((city) {
                                      return ListTile(
                                        dense: true,
                                        leading: const Icon(Icons.location_city_rounded, size: 20, color: Color(0xFF6D28D9)),
                                        title: Text(city['name']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                        subtitle: Text(city['state']!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        onTap: () {
                                          debounceTimer?.cancel();
                                          final cityName = city['name']!;
                                          final stateName = city['state']!;
                                          final estCoords = LocationSuggestionService.getEstimatedCoordinates(cityName, stateName);
                                          final resolvedDistrict = IndiaLocations.resolveDistrictForCity(cityName, stateName) ?? cityName;
                                          setState(() {
                                            _selectedLocation = '$cityName, $stateName';
                                            _selectedCity = cityName;
                                            _selectedState = stateName;
                                            _selectedDistrict = resolvedDistrict;
                                            _selectedPincode = null;
                                            _userLat = estCoords.latitude;
                                            _userLng = estCoords.longitude;
                                          });
                                          Navigator.of(ctx).pop();
                                          _loadSalons();
                                        },
                                      );
                                    }),
                                  ],
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── 1. Top Bar with Back Arrow & Centered Title ───────────────────
            _buildTopBar(),

            // ── 2. Location Field ───────────────────────────────────────────
            _buildLocationField(),

            // ── 3. Search Input Field ───────────────────────────────────────
            _buildSearchInputField(),

            // ── 4. Filter Categories Row (All, Men, Women, Unisex, Sliders) ─
            _buildFilterCategoriesRow(),

            const SizedBox(height: 12),

            // ── 5. Search Result Cards List ─────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF6D28D9)),
                    )
                  : _salons.isEmpty
                      ? _buildEmptyResultsView()
                      : RefreshIndicator(
                          color: const Color(0xFF6D28D9),
                          onRefresh: _loadSalons,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: _salons.length,
                            itemBuilder: (context, idx) {
                              final salon = _salons[idx];
                              return _buildSearchResultCard(salon);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Header ─────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Circular Back Button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
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
                size: 18,
                color: Color(0xFF111827),
              ),
            ),
          ),

          // Centered Title
          const Text(
            'Search',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.3,
            ),
          ),

          // Right Spacer to balance Back button width
          const SizedBox(width: 42, height: 42),
        ],
      ),
    );
  }

  // ── Location Field Card ────────────────────────────────────────────────────
  Widget _buildLocationField() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Orange Location Pin
          const Icon(
            Icons.location_on_rounded,
            color: Color(0xFFF59E0B), // Warm amber / orange
            size: 20,
          ),
          const SizedBox(width: 10),

          // Location text & dropdown chevron
          Expanded(
            child: GestureDetector(
              onTap: _showLocationSelector,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedLocation,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF6B7280),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Vertical divider
          Container(
            height: 22,
            width: 1,
            color: const Color(0xFFE5E7EB),
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),

          // Right Current Location crosshairs
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedLocation = 'Near Me';
                _selectedCity = null;
                _selectedState = 'All States';
                _sortBy = 'nearest';
              });
              _loadSalons();
            },
            child: const Icon(
              Icons.my_location_rounded,
              color: Color(0xFF111827),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Input Field ─────────────────────────────────────────────────────
  Widget _buildSearchInputField() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _loadSalons(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
              decoration: const InputDecoration(
                hintText: 'Search salon or service',
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
                _loadSalons();
              },
            ),
        ],
      ),
    );
  }

  // ── Filter Categories Row ──────────────────────────────────────────────────
  Widget _buildFilterCategoriesRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          // Filter Chips (All, Men, Women, Unisex)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterCategories.map((category) {
                  final isSelected = _selectedFilter == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedFilter = category);
                        _loadSalons();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFFE5E7EB),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: const Color(0xFF6D28D9).withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFF111827),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Sliders / Filter Options Button
          GestureDetector(
            onTap: _showSortFilterBottomSheet,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Color(0xFF111827),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Result Card ─────────────────────────────────────────────────────
  Widget _buildSearchResultCard(Salon salon) {
    final isFav = _favoriteSalonIds.contains(salon.id);
    final rating = salon.rating > 0 ? salon.rating.toStringAsFixed(1) : '4.8';
    final reviews = salon.reviewCount > 0 ? salon.reviewCount : 126;
    final distanceStr = salon.distanceKm != null
        ? '${salon.distanceKm!.toStringAsFixed(1)} km'
        : '3.1 km';

    // Wait time: compute dynamically or use salon data
    final waitMinutes = salon.estWaitMinutes > 0 ? salon.estWaitMinutes : (salon.waitingCount * 10 > 0 ? salon.waitingCount * 10 : 20);
    final waitStr = '$waitMinutes–${waitMinutes + 10} min wait';

    final crowdCount = salon.waitingCount > 0 ? salon.waitingCount : (salon.activeChairs > 0 ? salon.activeChairs * 6 : 20);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SalonDetailsScreen(salon: salon),
          ),
        ).then((_) => _loadSalons());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F3F5), width: 1),
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
            // Left: Salon Image with Crowd Count Badge Overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 110,
                    height: 110,
                    color: const Color(0xFF1E293B),
                    child: _buildCardImage(salon.effectiveCoverImage),
                  ),
                ),
                // Bottom-left Crowd count pill
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_alt_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '$crowdCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 14),

            // Right: Salon Details Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row with Heart Favorite Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          salon.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _toggleFavorite(salon.id),
                        child: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF),
                          size: 22,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Rating Row
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '$rating ($reviews)',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Wait Time & Distance Row
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        color: Color(0xFFE91E63),
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          waitStr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        distanceStr,
                        style: const TextStyle(
                          fontSize: 12,
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

  Widget _buildCardImage(String? imagePath) {
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        return Image.network(
          imagePath,
          width: 110,
          height: 110,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
        );
      } else if (imagePath.startsWith('data:image')) {
        try {
          final base64Str = imagePath.split(',').last;
          final bytes = base64Decode(base64Str);
          return Image.memory(
            bytes,
            width: 110,
            height: 110,
            fit: BoxFit.cover,
          );
        } catch (_) {
          return _buildFallbackImage();
        }
      }
    }
    return _buildFallbackImage();
  }

  Widget _buildFallbackImage() {
    return Container(
      width: 110,
      height: 110,
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

  Widget _buildEmptyResultsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF3E8FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Color(0xFF6D28D9),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No salons found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try changing location or searching for another keyword.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedFilter = 'All';
                  _selectedLocation = 'All India';
                  _selectedState = 'All States';
                  _selectedCity = null;
                });
                _loadSalons();
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF6D28D9)),
                foregroundColor: const Color(0xFF6D28D9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Show All India Salons', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
