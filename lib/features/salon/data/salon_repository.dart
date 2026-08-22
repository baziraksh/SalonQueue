// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../core/config/app_config.dart';
import '../../../shared/models/salon.dart';
import '../../../shared/models/salon_service.dart';

/// Data repository for discovering salons across all Indian States & Cities,
/// calculating live distances, rush levels, and owner salon & service management.
///
/// SUPABASE IS THE SINGLE SOURCE OF TRUTH FOR ALL SALON & SERVICE DATA.
class SalonRepository {
  SalonRepository({supabase.SupabaseClient? client}) : _client = client;

  final supabase.SupabaseClient? _client;

  /// Dedicated in-memory owner salon storage isolated strictly per auth.uid() (UI performance only)
  static final Map<String, Salon> _ownerSalonsCache = {};

  /// Dedicated in-memory services cache for offline test and rapid lookup
  static final Map<String, List<SalonService>> _inMemoryServicesCache = {};

  /// Clears in-memory salon cache on user logout to prevent cross-account data leakage
  static void clearCache() {
    _ownerSalonsCache.clear();
    _inMemoryServicesCache.clear();
  }

  /// Controls whether disk persistence is active (can be toggled in test suites)
  static bool enableDiskPersistence = true;

  static SharedPreferences? _prefsInstance;
  static final Map<String, String> _diskFallbackStorage = {};

  static Future<SharedPreferences?> _getPrefs() async {
    if (!enableDiskPersistence) return null;
    if (_prefsInstance != null) return _prefsInstance;
    try {
      _prefsInstance = await SharedPreferences.getInstance();
      return _prefsInstance;
    } catch (_) {
      return null;
    }
  }

  /// Canonical location normalization helper: trims, lowercases, and collapses repeated whitespace.
  static String normalizeLocation(String? value) {
    if (value == null) return '';
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Saves an owner's salon to persistent disk storage (SharedPreferences)
  static Future<void> _saveSalonToDisk(Salon salon) async {
    final ownerId = salon.ownerId ?? salon.id;
    if (ownerId.isEmpty) return;
    final jsonStr = jsonEncode(salon.toJson());
    _diskFallbackStorage['owner_salon_$ownerId'] = jsonStr;
    if (salon.id.isNotEmpty && salon.id != ownerId) {
      _diskFallbackStorage['owner_salon_${salon.id}'] = jsonStr;
    }

    try {
      final prefs = await _getPrefs();
      if (prefs == null) return;
      await prefs.setString('owner_salon_$ownerId', jsonStr);
      if (salon.id.isNotEmpty && salon.id != ownerId) {
        await prefs.setString('owner_salon_${salon.id}', jsonStr);
      }
    } catch (e) {
      debugPrint('[SalonRepository] _saveSalonToDisk notice: $e');
    }
  }

  /// Loads an owner's salon from persistent disk storage (SharedPreferences)
  static Future<Salon?> _loadSalonFromDisk(String ownerId) async {
    if (ownerId.isEmpty) return null;
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        final raw = prefs.getString('owner_salon_$ownerId');
        if (raw != null && raw.isNotEmpty) {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          return Salon.fromJson(map);
        }
      }
    } catch (e) {
      debugPrint('[SalonRepository] _loadSalonFromDisk notice: $e');
    }

    if (_diskFallbackStorage.containsKey('owner_salon_$ownerId')) {
      try {
        final raw = _diskFallbackStorage['owner_salon_$ownerId']!;
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return Salon.fromJson(map);
      } catch (_) {}
    }

    return null;
  }

  /// Updates an owner's salon in memory without mutating other accounts
  void _updateOwnerSalonInMemory(
    String salonId,
    Salon Function(Salon current) updater, {
    String? ownerId,
  }) {
    bool found = false;
    for (final entry in _ownerSalonsCache.entries) {
      if (entry.value.id == salonId ||
          entry.key == salonId ||
          (ownerId != null &&
              (entry.key == ownerId || entry.value.ownerId == ownerId))) {
        final updated = updater(entry.value);
        _ownerSalonsCache[entry.key] = updated;
        unawaited(_saveSalonToDisk(updated));
        found = true;
      }
    }

    if (!found && ownerId != null && _ownerSalonsCache.containsKey(ownerId)) {
      final updated = updater(_ownerSalonsCache[ownerId]!);
      _ownerSalonsCache[ownerId] = updated;
      unawaited(_saveSalonToDisk(updated));
      found = true;
    }

    final idx = fallbackSalons.indexWhere(
      (s) => s.id == salonId || (ownerId != null && s.ownerId == ownerId),
    );
    if (idx != -1) {
      fallbackSalons[idx] = updater(fallbackSalons[idx]);
      found = true;
    }
  }

  supabase.SupabaseClient? get client {
    if (_client != null) return _client;
    try {
      return supabase.Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// In-memory test fixture salons (strictly used in offline widget/unit tests when client is null)
  static final List<Salon> fallbackSalons = [];

  /// Real-time live stream of salons auto-fetching from Supabase database
  Stream<List<Salon>> streamSalons({
    String? state,
    String? city,
    String? district,
    String? pincode,
    String? search,
    String? category,
    String sortBy = 'nearest',
    double userLat = 18.5204,
    double userLng = 73.8567,
  }) {
    final activeClient = client;
    if (activeClient == null) {
      return Stream.value(
        _filterLocalSalons(
          fallbackSalons.isNotEmpty
              ? fallbackSalons
              : _ownerSalonsCache.values.toList(),
          state: state,
          city: city,
          district: district,
          pincode: pincode,
          search: search,
          category: category,
          sortBy: sortBy,
          userLat: userLat,
          userLng: userLng,
        ),
      );
    }

    try {
      return activeClient
          .from('salons')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .asyncMap((_) async {
            return await fetchSalons(
              state: state,
              city: city,
              district: district,
              pincode: pincode,
              search: search,
              category: category,
              sortBy: sortBy,
              userLat: userLat,
              userLng: userLng,
            );
          });
    } catch (e) {
      debugPrint('[SalonRepository] streamSalons fallback to polling: $e');
      return Stream.periodic(const Duration(seconds: 4)).asyncMap(
        (_) => fetchSalons(
          state: state,
          city: city,
          district: district,
          pincode: pincode,
          search: search,
          category: category,
          sortBy: sortBy,
          userLat: userLat,
          userLng: userLng,
        ),
      );
    }
  }

  /// Key for persistent local disk storage of salons
  static const String _customerSalonsDiskKey = 'cached_customer_salons_v1';

  /// Static in-memory cache of evaluated salons for instant frame-1 rendering
  static List<Salon> _cachedCustomerSalons = [];

  /// Preloads persistent disk cache into memory during startup
  static Future<void> initDiskCache() async {
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        final raw = prefs.getString(_customerSalonsDiskKey);
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw) as List<dynamic>;
          final list = <Salon>[];
          for (final item in decoded) {
            try {
              if (item is Map<String, dynamic>) {
                list.add(Salon.fromJson(item));
              } else if (item is Map) {
                list.add(Salon.fromJson(Map<String, dynamic>.from(item)));
              }
            } catch (_) {}
          }
          if (list.isNotEmpty) {
            _cachedCustomerSalons = list;
          }
        }
      }
    } catch (e) {
      debugPrint('[SalonRepository] initDiskCache notice: $e');
    }
  }

  /// Asynchronously saves salons to persistent disk storage (SharedPreferences)
  static Future<void> _saveCustomerSalonsToDisk(List<Salon> salons) async {
    if (salons.isEmpty) return;
    try {
      final encoded = jsonEncode(salons.map((s) => s.toJson()).toList());
      _diskFallbackStorage[_customerSalonsDiskKey] = encoded;
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString(_customerSalonsDiskKey, encoded);
      }
    } catch (e) {
      debugPrint('[SalonRepository] _saveCustomerSalonsToDisk error: $e');
    }
  }

  /// Synchronously retrieve cached salons for zero-latency frame 1 UI display
  List<Salon> getCachedSalons({
    String? state,
    String? city,
    String? district,
    String? pincode,
    String? search,
    String? category,
    String sortBy = 'nearest',
    double userLat = 18.5204,
    double userLng = 73.8567,
    double? maxRadiusKm,
  }) {
    if (_cachedCustomerSalons.isEmpty) {
      if (_diskFallbackStorage.containsKey(_customerSalonsDiskKey)) {
        try {
          final raw = _diskFallbackStorage[_customerSalonsDiskKey]!;
          final decoded = jsonDecode(raw) as List<dynamic>;
          final list = <Salon>[];
          for (final item in decoded) {
            try {
              if (item is Map<String, dynamic>) {
                list.add(Salon.fromJson(item));
              } else if (item is Map) {
                list.add(Salon.fromJson(Map<String, dynamic>.from(item)));
              }
            } catch (_) {}
          }
          if (list.isNotEmpty) {
            _cachedCustomerSalons = list;
          }
        } catch (_) {}
      }
    }

    if (_cachedCustomerSalons.isEmpty) return [];
    return _filterAndSortSalons(
      _cachedCustomerSalons,
      state: state,
      city: city,
      district: district,
      pincode: pincode,
      search: search,
      category: category,
      sortBy: sortBy,
      userLat: userLat,
      userLng: userLng,
      maxRadiusKm: maxRadiusKm,
    );
  }

  /// Fetches real registered salons from database with high-performance parallel batch querying.
  /// SUPABASE DATABASE IS THE SINGLE SOURCE OF TRUTH FOR CUSTOMER DISCOVERY.
  Future<List<Salon>> fetchSalons({
    String? state,
    String? city,
    String? district,
    String? pincode,
    String? search,
    String? category,
    String sortBy = 'nearest',
    double userLat = 18.5204,
    double userLng = 73.8567,
    double? maxRadiusKm,
  }) async {
    final activeClient = client;
    debugPrint('[Supabase] host = ${AppConfig.supabaseHostname}');

    List<Salon> dbSalons = [];
    String? databaseError;

    if (activeClient != null) {
      try {
        // Parallel batch fetch for both salons and all services in ONE single roundtrip
        final results = await Future.wait([
          activeClient
              .from('salons')
              .select('*')
              .not('owner_id', 'is', null)
              .order('created_at', ascending: false),
          activeClient
              .from('services')
              .select('*')
              .order('name', ascending: true),
        ]);

        final salonsResponse = (results[0] as List);
        final servicesResponse = (results[1] as List);

        final servicesBySalonId = <String, List<SalonService>>{};
        for (final raw in servicesResponse) {
          try {
            final map = Map<String, dynamic>.from(raw as Map);
            final sId = map['salon_id'] as String?;
            if (sId != null && sId.isNotEmpty) {
              servicesBySalonId
                  .putIfAbsent(sId, () => [])
                  .add(SalonService.fromJson(map));
            }
          } catch (_) {}
        }

        for (final raw in salonsResponse) {
          final map = Map<String, dynamic>.from(raw as Map);
          final salonId = map['id'] as String?;
          final salonName = (map['name'] as String? ?? '').trim();
          if (salonId == null || salonName.isEmpty) continue;

          final services = servicesBySalonId[salonId] ?? [];
          final salon = Salon.fromJson(
            map,
            services: services,
            userLat: userLat,
            userLng: userLng,
          );
          dbSalons.add(salon);
        }

        // Store into static cache and persist to disk for instant future loads
        _cachedCustomerSalons = List<Salon>.from(dbSalons);
        unawaited(_saveCustomerSalonsToDisk(dbSalons));
      } catch (e) {
        databaseError = e.toString();
        debugPrint('[SalonRepository] fetchSalons database query error: $e');
        if (databaseError.contains('431') ||
            databaseError.contains('Too Large')) {
          try {
            await activeClient.auth.signOut();
          } catch (_) {}
        }
        // Fallback to cached salons on network error
        if (dbSalons.isEmpty && _cachedCustomerSalons.isNotEmpty) {
          dbSalons = List<Salon>.from(_cachedCustomerSalons);
        }
      }
    } else {
      // Offline/unit-test mock mode when client is null
      dbSalons = fallbackSalons.isNotEmpty
          ? List<Salon>.from(fallbackSalons)
          : _ownerSalonsCache.values.toList();
    }

    final sorted = _filterAndSortSalons(
      dbSalons,
      state: state,
      city: city,
      district: district,
      pincode: pincode,
      search: search,
      category: category,
      sortBy: sortBy,
      userLat: userLat,
      userLng: userLng,
      maxRadiusKm: maxRadiusKm,
    );

    debugPrint(
      '[SalonDB][CUSTOMER_FETCH] state = ${state ?? "null"}, district = ${district ?? "null"}, '
      'city = ${city ?? "null"}, search = "${search ?? ""}", rowsReturned = ${sorted.length}, '
      'databaseError = $databaseError',
    );

    return sorted;
  }

  /// Internal high-performance helper to evaluate distance, filters, and sort orders
  List<Salon> _filterAndSortSalons(
    List<Salon> sourceSalons, {
    String? state,
    String? city,
    String? district,
    String? pincode,
    String? search,
    String? category,
    String sortBy = 'nearest',
    double userLat = 18.5204,
    double userLng = 73.8567,
    double? maxRadiusKm,
  }) {
    // 1. Calculate distances for all candidate salons
    var evaluated = sourceSalons.map((s) {
      final dist = s.calculateDistance(userLat, userLng);
      return s.copyWith(distanceKm: dist);
    }).toList();

    // 2. Canonical normalization of filter parameters
    final normState = normalizeLocation(state);
    final normDistrict = normalizeLocation(district);
    final normCity = normalizeLocation(city);
    final normPincode = normalizeLocation(pincode);
    final normSearch = normalizeLocation(search);

    final isAllStates =
        normState.isEmpty || normState == 'all' || normState == 'all states';
    final isAllCities =
        normCity.isEmpty ||
        normCity == 'all' ||
        normCity == 'all cities' ||
        normCity == 'all india' ||
        normCity == 'all locations';
    final isAllDistricts =
        normDistrict.isEmpty ||
        normDistrict == 'all' ||
        normDistrict == 'all districts';

    var filtered = evaluated;

    // 3. Filter by State
    if (!isAllStates) {
      filtered = filtered.where((s) {
        final sState = normalizeLocation(s.state);
        final sAddr = normalizeLocation(s.address);
        final sCity = normalizeLocation(s.city);
        final sDist = normalizeLocation(s.district);
        return sState.contains(normState) ||
            normState.contains(sState) ||
            sAddr.contains(normState) ||
            sCity.contains(normState) ||
            sDist.contains(normState);
      }).toList();
    }

    // 4. Filter by District
    if (!isAllDistricts) {
      filtered = filtered.where((s) {
        final sDist = normalizeLocation(s.district);
        final sCity = normalizeLocation(s.city);
        final sAddr = normalizeLocation(s.address);
        final sState = normalizeLocation(s.state);
        return sDist.contains(normDistrict) ||
            normDistrict.contains(sDist) ||
            sCity.contains(normDistrict) ||
            normDistrict.contains(sCity) ||
            sAddr.contains(normDistrict) ||
            sState.contains(normDistrict);
      }).toList();
    }

    // 5. Filter by City / Village / Locality
    if (!isAllCities) {
      final cityMatches = filtered.where((s) {
        final sCity = normalizeLocation(s.city);
        final sDist = normalizeLocation(s.district);
        final sAddr = normalizeLocation(s.address);
        final sName = normalizeLocation(s.name);
        final sState = normalizeLocation(s.state);
        return sCity.contains(normCity) ||
            normCity.contains(sCity) ||
            sDist.contains(normCity) ||
            normDistrict.contains(sCity) ||
            sAddr.contains(normCity) ||
            normCity.contains(sAddr) ||
            sName.contains(normCity) ||
            normCity.contains(sName) ||
            sState.contains(normCity);
      }).toList();

      if (cityMatches.isNotEmpty) {
        filtered = cityMatches;
      } else if (maxRadiusKm != null && maxRadiusKm > 0) {
        filtered = evaluated
            .where((s) => (s.distanceKm ?? 999) <= maxRadiusKm)
            .toList();
      } else {
        filtered = [];
      }
    }

    // 6. Filter by Pincode
    if (normPincode.isNotEmpty) {
      filtered = filtered.where((s) {
        final sPin = normalizeLocation(s.pincode);
        final sAddr = normalizeLocation(s.address);
        return sPin.contains(normPincode) || sAddr.contains(normPincode);
      }).toList();
    }

    // 7. Filter by Search Query (Case-Insensitive)
    if (normSearch.isNotEmpty) {
      final queryMatches = filtered.where((s) {
        final sName = normalizeLocation(s.name);
        final sOwner = normalizeLocation(s.ownerName);
        final sAddr = normalizeLocation(s.address);
        final sCity = normalizeLocation(s.city);
        final sDist = normalizeLocation(s.district);
        final sState = normalizeLocation(s.state);
        final sPin = normalizeLocation(s.pincode);
        final sDesc = normalizeLocation(s.description);
        final hasService = s.services.any(
          (svc) => normalizeLocation(svc.name).contains(normSearch),
        );

        return sName.contains(normSearch) ||
            sOwner.contains(normSearch) ||
            sAddr.contains(normSearch) ||
            sCity.contains(normSearch) ||
            sDist.contains(normSearch) ||
            sState.contains(normSearch) ||
            sPin.contains(normSearch) ||
            sDesc.contains(normSearch) ||
            hasService;
      }).toList();

      filtered = queryMatches;
    }

    final catFiltered = _filterByCategory(filtered, category);
    return _sortSalons(catFiltered, sortBy);
  }

  /// Fetches a single salon by ID or Owner ID directly from Supabase, including fresh services
  Future<Salon?> fetchSalonById(String salonId) async {
    final trimmedId = salonId.trim();
    if (trimmedId.isEmpty) return null;

    final client = this.client;
    if (client == null) {
      if (_ownerSalonsCache.containsKey(trimmedId)) {
        return _ownerSalonsCache[trimmedId];
      }
      final byOwner = _ownerSalonsCache.values.where(
        (s) => s.id == trimmedId || s.ownerId == trimmedId,
      );
      if (byOwner.isNotEmpty) return byOwner.first;
      final matches = fallbackSalons.where(
        (s) => s.id == trimmedId || s.ownerId == trimmedId,
      );
      if (matches.isNotEmpty) return matches.first;
      return null;
    }

    try {
      final resList = await client
          .from('salons')
          .select('*')
          .or('id.eq.$trimmedId,owner_id.eq.$trimmedId')
          .limit(1);

      if ((resList as List).isNotEmpty) {
        final map = Map<String, dynamic>.from(resList.first as Map);
        final realSalonId = map['id'] as String;

        // Fetch live services from public.services
        final services = await fetchServices(realSalonId);

        try {
          final tickets = await client
              .from('queue_tickets')
              .select('id')
              .eq('salon_id', realSalonId)
              .eq('status', 'WAITING');
          map['waiting_count'] = (tickets as List).length;
        } catch (_) {
          map['waiting_count'] = 0;
        }

        final salon = Salon.fromJson(map, services: services);
        _ownerSalonsCache[salon.ownerId ?? salon.id] = salon;
        _ownerSalonsCache[salon.id] = salon;
        return salon;
      }

      if (_ownerSalonsCache.containsKey(trimmedId)) {
        return _ownerSalonsCache[trimmedId];
      }
      final byOwner = _ownerSalonsCache.values.where(
        (s) => s.id == trimmedId || s.ownerId == trimmedId,
      );
      if (byOwner.isNotEmpty) return byOwner.first;

      final matches = fallbackSalons.where(
        (s) => s.id == trimmedId || s.ownerId == trimmedId,
      );
      return matches.isNotEmpty ? matches.first : null;
    } catch (e) {
      debugPrint('[SalonRepository] fetchSalonById error: $e');
      if (_ownerSalonsCache.containsKey(trimmedId)) {
        return _ownerSalonsCache[trimmedId];
      }
      final byOwner = _ownerSalonsCache.values.where(
        (s) => s.id == trimmedId || s.ownerId == trimmedId,
      );
      if (byOwner.isNotEmpty) return byOwner.first;
      final matches = fallbackSalons.where(
        (s) => s.id == trimmedId || s.ownerId == trimmedId,
      );
      return matches.isNotEmpty ? matches.first : null;
    }
  }

  /// Fetches the salon owned by the current salon owner from Supabase.
  /// If no salon exists in the database for this owner, provisions exactly ONE canonical row.
  Future<Salon?> fetchOwnerSalon(String ownerId) async {
    if (ownerId.isEmpty) return null;

    final client = this.client;
    if (client != null) {
      try {
        final resList = await client
            .from('salons')
            .select('*')
            .eq('owner_id', ownerId)
            .limit(1);

        if ((resList as List).isNotEmpty) {
          final map = Map<String, dynamic>.from(resList.first as Map);
          final realSalonId = map['id'] as String;

          // Fetch fresh services
          final services = await fetchServices(realSalonId);

          final remoteSalon = Salon.fromJson(map, services: services);
          _ownerSalonsCache[ownerId] = remoteSalon;
          _ownerSalonsCache[remoteSalon.id] = remoteSalon;
          unawaited(_saveSalonToDisk(remoteSalon));
          return remoteSalon;
        }

        // Brand new owner without existing salon — provision exactly ONE dedicated salon row
        try {
          String initialOwnerName = 'Salon Owner';
          try {
            final profile = await client
                .from('profiles')
                .select('full_name')
                .eq('id', ownerId)
                .maybeSingle();
            if (profile != null &&
                profile['full_name'] != null &&
                profile['full_name'].toString().isNotEmpty) {
              initialOwnerName = profile['full_name'].toString();
            }
          } catch (_) {}

          final defaultSalonName =
              (initialOwnerName.isNotEmpty && initialOwnerName != 'Salon Owner')
              ? "$initialOwnerName's Salon"
              : 'My Salon';

          final inserted = await client
              .from('salons')
              .insert({
                'owner_id': ownerId,
                'name': defaultSalonName,
                'owner_name': initialOwnerName,
                'description': 'Welcome to our salon.',
                'address': '',
                'city': '',
                'district': '',
                'state': '',
                'active_chairs': 1,
                'rating': 0.0,
                'review_count': 0,
                'is_queue_open': true,
                'is_verified': false,
                'is_active': true,
                'is_published': true,
                'opening_time': '09:00 AM',
                'closing_time': '09:00 PM',
              })
              .select('*')
              .maybeSingle();

          if (inserted != null) {
            final map = Map<String, dynamic>.from(inserted);
            final salonId = map['id'] as String;

            try {
              final defaultServices = [
                {
                  'salon_id': salonId,
                  'name': 'Haircut',
                  'category': 'Hair',
                  'price': 150.0,
                  'duration_minutes': 25,
                  'is_active': true,
                },
                {
                  'salon_id': salonId,
                  'name': 'Beard Grooming',
                  'category': 'Beard',
                  'price': 80.0,
                  'duration_minutes': 15,
                  'is_active': true,
                },
              ];
              final insertedServices = await client
                  .from('services')
                  .insert(defaultServices)
                  .select();
              final services = (insertedServices as List)
                  .map(
                    (s) => SalonService.fromJson(
                      Map<String, dynamic>.from(s as Map),
                    ),
                  )
                  .toList();
              final salon = Salon.fromJson(map, services: services);
              _ownerSalonsCache[ownerId] = salon;
              _ownerSalonsCache[salon.id] = salon;
              unawaited(_saveSalonToDisk(salon));
              return salon;
            } catch (_) {}

            final salon = Salon.fromJson(map, services: []);
            _ownerSalonsCache[ownerId] = salon;
            _ownerSalonsCache[salon.id] = salon;
            unawaited(_saveSalonToDisk(salon));
            return salon;
          }
        } catch (insertErr) {
          debugPrint(
            '[SalonRepository] auto-provision owner salon error: $insertErr',
          );
        }
      } catch (e) {
        debugPrint('[SalonRepository] fetchOwnerSalon error: $e');
      }
    }

    // Fallback: Local disk cache or in-memory cache when offline or in test environment
    final diskSalon = await _loadSalonFromDisk(ownerId);
    if (diskSalon != null) {
      _ownerSalonsCache[ownerId] = diskSalon;
      return diskSalon;
    }

    if (_ownerSalonsCache.containsKey(ownerId)) {
      return _ownerSalonsCache[ownerId];
    }

    final isolatedSalon = Salon(
      id: ownerId,
      ownerId: ownerId,
      name: 'My Salon',
      description: 'Welcome to our salon.',
      address: '',
      city: '',
      district: '',
      state: '',
      activeChairs: 1,
      rating: 0.0,
      reviewCount: 0,
      isQueueOpen: true,
      isVerified: false,
      openingTime: '09:00 AM',
      closingTime: '09:00 PM',
      ownerName: 'Salon Owner',
      ownerAvatarUrl: null,
      coverImageUrl: null,
      bannerUrl: null,
      galleryImages: const [],
      services: const [],
    );

    _ownerSalonsCache[ownerId] = isolatedSalon;
    unawaited(_saveSalonToDisk(isolatedSalon));
    return isolatedSalon;
  }

  /// Saves and persists salon data directly to Supabase public.salons.
  /// Awaits database response and rethrows errors so callers know if write succeeded.
  Future<Salon> _updateSalonInDb(
    String salonId,
    Map<String, dynamic> updateData, {
    String? ownerId,
  }) async {
    final activeClient = client;
    final effectiveOwnerId = ownerId ?? activeClient?.auth.currentUser?.id;

    if (effectiveOwnerId == null ||
        effectiveOwnerId.isEmpty ||
        activeClient == null) {
      final existing =
          _ownerSalonsCache[salonId] ??
          _ownerSalonsCache[effectiveOwnerId] ??
          fallbackSalons.cast<Salon?>().firstWhere(
            (s) =>
                s != null &&
                (s.id == salonId ||
                    (effectiveOwnerId != null &&
                        s.ownerId == effectiveOwnerId)),
            orElse: () => null,
          );
      final base =
          existing ??
          Salon(
            id: salonId,
            ownerId: effectiveOwnerId ?? salonId,
            name: updateData['name'] ?? 'My Salon & Spa',
            address: updateData['address'] ?? '',
            city: updateData['city'] ?? '',
          );
      final localUpdated = base.copyWith(
        name: updateData['name'] ?? base.name,
        description: updateData['description'] ?? base.description,
        phone: updateData.containsKey('phone')
            ? updateData['phone']
            : base.phone,
        address: updateData['address'] ?? base.address,
        city: updateData['city'] ?? base.city,
        district: updateData['district'] ?? base.district,
        state: updateData['state'] ?? base.state,
        pincode: updateData.containsKey('pincode')
            ? updateData['pincode']
            : base.pincode,
        latitude: updateData.containsKey('latitude')
            ? (updateData['latitude'] as num?)?.toDouble()
            : base.latitude,
        longitude: updateData.containsKey('longitude')
            ? (updateData['longitude'] as num?)?.toDouble()
            : base.longitude,
        activeChairs: updateData['active_chairs'] ?? base.activeChairs,
        isQueueOpen: updateData['is_queue_open'] ?? base.isQueueOpen,
        openingTime: updateData['opening_time'] ?? base.openingTime,
        closingTime: updateData['closing_time'] ?? base.closingTime,
        coverImageUrl: updateData.containsKey('cover_image_url')
            ? updateData['cover_image_url']
            : base.coverImageUrl,
        bannerUrl: updateData.containsKey('banner_url')
            ? updateData['banner_url']
            : base.bannerUrl,
        ownerName: updateData['owner_name'] ?? base.ownerName,
        ownerAvatarUrl: updateData.containsKey('owner_avatar_url')
            ? updateData['owner_avatar_url']
            : base.ownerAvatarUrl,
        galleryImages: updateData['gallery_images'] != null
            ? List<String>.from(updateData['gallery_images'])
            : base.galleryImages,
      );
      if (effectiveOwnerId != null && effectiveOwnerId.isNotEmpty) {
        _ownerSalonsCache[effectiveOwnerId] = localUpdated;
      }
      _ownerSalonsCache[salonId] = localUpdated;
      _ownerSalonsCache[localUpdated.id] = localUpdated;
      return localUpdated;
    }

    try {
      final partialPayload = Map<String, dynamic>.from(updateData);
      partialPayload['updated_at'] = DateTime.now().toUtc().toIso8601String();

      // Check if row exists for owner
      final existingRows = await activeClient
          .from('salons')
          .select('*')
          .eq('owner_id', effectiveOwnerId);

      Map<String, dynamic> savedRow;

      if ((existingRows as List).isNotEmpty) {
        final resUpdate = await activeClient
            .from('salons')
            .update(partialPayload)
            .eq('owner_id', effectiveOwnerId)
            .select('*');

        if ((resUpdate as List).isEmpty) {
          throw Exception(
            'Failed to update salon record for owner $effectiveOwnerId',
          );
        }
        savedRow = Map<String, dynamic>.from(resUpdate.first as Map);
      } else {
        // First-time insert
        partialPayload['owner_id'] = effectiveOwnerId;
        partialPayload.putIfAbsent('name', () => 'My Salon & Spa');
        partialPayload.putIfAbsent(
          'description',
          () => 'Welcome to our premium salon.',
        );
        partialPayload.putIfAbsent('address', () => 'Main Market Road');
        partialPayload.putIfAbsent('city', () => 'Angul');
        partialPayload.putIfAbsent('district', () => 'Angul');
        partialPayload.putIfAbsent('state', () => 'Odisha');
        partialPayload.putIfAbsent('active_chairs', () => 3);
        partialPayload.putIfAbsent('is_queue_open', () => true);
        partialPayload.putIfAbsent('is_verified', () => true);
        partialPayload.putIfAbsent('is_active', () => true);
        partialPayload.putIfAbsent('is_published', () => true);
        partialPayload.putIfAbsent('opening_time', () => '09:00 AM');
        partialPayload.putIfAbsent('closing_time', () => '09:00 PM');
        partialPayload.putIfAbsent('gallery_images', () => []);

        final resInsert = await activeClient
            .from('salons')
            .insert(partialPayload)
            .select('*');

        if ((resInsert as List).isEmpty) {
          throw Exception(
            'Failed to insert new salon record for owner $effectiveOwnerId',
          );
        }
        savedRow = Map<String, dynamic>.from(resInsert.first as Map);
      }

      final savedSalon = Salon.fromJson(savedRow);
      _ownerSalonsCache[effectiveOwnerId] = savedSalon;
      _ownerSalonsCache[savedSalon.id] = savedSalon;
      unawaited(_saveSalonToDisk(savedSalon));

      debugPrint(
        '[SalonDB][SAVE] authUserId = $effectiveOwnerId, salonId = ${savedSalon.id}, '
        'name = "${savedSalon.name}", state = "${savedSalon.state}", district = "${savedSalon.district}", '
        'city = "${savedSalon.city}", databaseSuccess = true, databaseError = null',
      );

      return savedSalon;
    } catch (e) {
      debugPrint(
        '[SalonDB][SAVE] authUserId = $effectiveOwnerId, salonId = $salonId, '
        'name = "${updateData['name']}", state = "${updateData['state']}", '
        'district = "${updateData['district']}", city = "${updateData['city']}", '
        'databaseSuccess = false, databaseError = $e',
      );
      rethrow;
    }
  }

  /// Updates queue open/closed status for salon owner
  Future<void> setQueueStatus(
    String salonId,
    bool isOpen, {
    String? ownerId,
  }) async {
    _updateOwnerSalonInMemory(
      salonId,
      (s) => s.copyWith(isQueueOpen: isOpen),
      ownerId: ownerId,
    );
    await _updateSalonInDb(salonId, {
      'is_queue_open': isOpen,
    }, ownerId: ownerId);
  }

  /// Updates salon profile details, state, district, city, working hours, and chairs
  Future<void> updateSalonDetails({
    required String salonId,
    String? ownerId,
    required String name,
    required String description,
    required String address,
    required String city,
    required String district,
    required String state,
    String? pincode,
    required String phone,
    required int activeChairs,
    required String openingTime,
    required String closingTime,
  }) async {
    _updateOwnerSalonInMemory(
      salonId,
      (s) => s.copyWith(
        name: name,
        description: description,
        address: address,
        city: city,
        district: district,
        state: state,
        pincode: pincode,
        phone: phone,
        activeChairs: activeChairs,
        openingTime: openingTime,
        closingTime: closingTime,
      ),
      ownerId: ownerId,
    );

    await _updateSalonInDb(salonId, {
      'name': name,
      'description': description,
      'address': address,
      'city': city,
      'district': district,
      'state': state,
      'pincode': pincode,
      'phone': phone,
      'active_chairs': activeChairs,
      'opening_time': openingTime,
      'closing_time': closingTime,
    }, ownerId: ownerId);
  }

  /// Updates only store information (Name, Description, Phone)
  Future<void> updateStoreInfo({
    required String salonId,
    String? ownerId,
    required String name,
    required String description,
    required String phone,
  }) async {
    _updateOwnerSalonInMemory(
      salonId,
      (s) => s.copyWith(name: name, description: description, phone: phone),
      ownerId: ownerId,
    );

    await _updateSalonInDb(salonId, {
      'name': name,
      'description': description,
      'phone': phone,
    }, ownerId: ownerId);
  }

  /// Updates only store location (State, District, City, Address, Pincode, Coordinates)
  Future<void> updateSalonLocation({
    required String salonId,
    String? ownerId,
    required String state,
    required String district,
    required String city,
    required String address,
    String? pincode,
    double? latitude,
    double? longitude,
  }) async {
    _updateOwnerSalonInMemory(
      salonId,
      (s) => s.copyWith(
        state: state,
        district: district,
        city: city,
        address: address,
        pincode: pincode,
        latitude: latitude ?? s.latitude,
        longitude: longitude ?? s.longitude,
      ),
      ownerId: ownerId,
    );

    final payload = <String, dynamic>{
      'state': state,
      'district': district,
      'city': city,
      'address': address,
      'pincode': pincode,
    };
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;

    await _updateSalonInDb(salonId, payload, ownerId: ownerId);
  }

  /// Updates chairs count and opening/closing hours
  Future<void> updateChairsTimings({
    required String salonId,
    String? ownerId,
    required int activeChairs,
    required String openingTime,
    required String closingTime,
  }) async {
    _updateOwnerSalonInMemory(
      salonId,
      (s) => s.copyWith(
        activeChairs: activeChairs,
        openingTime: openingTime,
        closingTime: closingTime,
      ),
      ownerId: ownerId,
    );

    await _updateSalonInDb(salonId, {
      'active_chairs': activeChairs,
      'opening_time': openingTime,
      'closing_time': closingTime,
    }, ownerId: ownerId);
  }

  /// Updates salon main cover image
  Future<void> updateCoverImage({
    required String salonId,
    String? ownerId,
    required String? coverImageUrl,
  }) async {
    _updateOwnerSalonInMemory(
      salonId,
      (s) => s.copyWith(coverImageUrl: coverImageUrl, bannerUrl: coverImageUrl),
      ownerId: ownerId,
    );

    await _updateSalonInDb(salonId, {
      'cover_image_url': coverImageUrl,
      'banner_url': coverImageUrl,
    }, ownerId: ownerId);
  }

  /// Updates owner profile information and avatar photo
  Future<void> updateOwnerProfile({
    required String salonId,
    String? ownerId,
    String? ownerName,
    String? ownerAvatarUrl,
    bool clearAvatar = false,
  }) async {
    _updateOwnerSalonInMemory(
      salonId,
      (s) => s.copyWith(
        ownerName: ownerName,
        ownerAvatarUrl: clearAvatar ? null : ownerAvatarUrl,
        clearOwnerAvatar: clearAvatar,
      ),
      ownerId: ownerId,
    );

    final updateData = <String, dynamic>{};
    if (ownerName != null) updateData['owner_name'] = ownerName;
    if (clearAvatar) {
      updateData['owner_avatar_url'] = null;
    } else if (ownerAvatarUrl != null) {
      updateData['owner_avatar_url'] = ownerAvatarUrl;
    }

    if (updateData.isNotEmpty) {
      await _updateSalonInDb(salonId, updateData, ownerId: ownerId);
    }
  }

  /// Adds a photo to the salon gallery
  Future<void> addGalleryImage({
    required String salonId,
    String? ownerId,
    required String imageUrl,
  }) async {
    List<String> currentGallery = [];
    _updateOwnerSalonInMemory(salonId, (s) {
      currentGallery = [...s.galleryImages, imageUrl];
      return s.copyWith(galleryImages: currentGallery);
    }, ownerId: ownerId);

    await _updateSalonInDb(salonId, {
      'gallery_images': currentGallery,
    }, ownerId: ownerId);
  }

  /// Removes a photo from the salon gallery
  Future<void> removeGalleryImage({
    required String salonId,
    String? ownerId,
    required String imageUrl,
  }) async {
    List<String> updatedGallery = [];
    _updateOwnerSalonInMemory(salonId, (s) {
      updatedGallery = s.galleryImages.where((img) => img != imageUrl).toList();
      return s.copyWith(galleryImages: updatedGallery);
    }, ownerId: ownerId);

    await _updateSalonInDb(salonId, {
      'gallery_images': updatedGallery,
    }, ownerId: ownerId);
  }

  /// Fetches real services for a salon directly from Supabase public.services.
  Future<List<SalonService>> fetchServices(
    String salonId, {
    bool onlyActive = false,
  }) async {
    if (salonId.isEmpty) return [];
    final activeClient = client;

    if (activeClient == null) {
      final fromMem = _inMemoryServicesCache[salonId];
      if (fromMem != null && fromMem.isNotEmpty) {
        return onlyActive
            ? fromMem.where((s) => s.isActive).toList()
            : List.from(fromMem);
      }
      final fromCache =
          _ownerSalonsCache[salonId]?.services ??
          fallbackSalons
              .cast<Salon?>()
              .firstWhere((s) => s?.id == salonId, orElse: () => null)
              ?.services ??
          [];
      return onlyActive
          ? fromCache.where((s) => s.isActive).toList()
          : fromCache;
    }

    try {
      var query = activeClient
          .from('services')
          .select('*')
          .eq('salon_id', salonId);

      if (onlyActive) {
        query = query.eq('is_active', true);
      }

      final res = await query.order('name', ascending: true);
      final list = (res as List)
          .map(
            (r) => SalonService.fromJson(Map<String, dynamic>.from(r as Map)),
          )
          .toList();

      // Synchronize in-memory cache
      _inMemoryServicesCache[salonId] = list;
      for (final entry in _ownerSalonsCache.entries) {
        if (entry.value.id == salonId) {
          _ownerSalonsCache[entry.key] = entry.value.copyWith(services: list);
        }
      }

      return list;
    } catch (e) {
      debugPrint('[SalonRepository] fetchServices error: $e');
      final fromMem = _inMemoryServicesCache[salonId];
      if (fromMem != null) {
        return onlyActive
            ? fromMem.where((s) => s.isActive).toList()
            : List.from(fromMem);
      }
      final fromCache = _ownerSalonsCache[salonId]?.services ?? [];
      return onlyActive
          ? fromCache.where((s) => s.isActive).toList()
          : fromCache;
    }
  }

  /// Real-time stream of services for a salon
  Stream<List<SalonService>> streamServices(
    String salonId, {
    bool onlyActive = false,
  }) {
    if (salonId.isEmpty) return Stream.value([]);
    final activeClient = client;

    if (activeClient == null) {
      final fromMem = _inMemoryServicesCache[salonId];
      if (fromMem != null && fromMem.isNotEmpty) {
        return Stream.value(
          onlyActive ? fromMem.where((s) => s.isActive).toList() : fromMem,
        );
      }
      final fromCache = _ownerSalonsCache[salonId]?.services ?? [];
      return Stream.value(
        onlyActive ? fromCache.where((s) => s.isActive).toList() : fromCache,
      );
    }

    try {
      return activeClient
          .from('services')
          .stream(primaryKey: ['id'])
          .eq('salon_id', salonId)
          .map((rows) {
            var list = rows
                .map((r) => SalonService.fromJson(Map<String, dynamic>.from(r)))
                .toList();
            if (onlyActive) {
              list = list.where((s) => s.isActive).toList();
            }
            list.sort((a, b) => a.name.compareTo(b.name));
            return list;
          });
    } catch (e) {
      debugPrint('[SalonRepository] streamServices fallback to polling: $e');
      return Stream.periodic(
        const Duration(seconds: 3),
      ).asyncMap((_) => fetchServices(salonId, onlyActive: onlyActive));
    }
  }

  /// Adds a new service directly to Supabase public.services.
  /// Returns the actual database-generated SalonService row.
  Future<SalonService> addService({
    required String salonId,
    required String name,
    required String category,
    required double price,
    required int durationMinutes,
    bool isActive = true,
  }) async {
    final activeClient = client;

    if (activeClient == null) {
      final newSvc = SalonService(
        id: 'svc-${DateTime.now().millisecondsSinceEpoch}',
        salonId: salonId,
        name: name,
        category: category,
        price: price,
        durationMinutes: durationMinutes,
        isActive: isActive,
      );
      _inMemoryServicesCache.putIfAbsent(salonId, () => []);
      _inMemoryServicesCache[salonId]!.removeWhere((s) => s.id == newSvc.id);
      _inMemoryServicesCache[salonId]!.add(newSvc);
      _updateOwnerSalonInMemory(
        salonId,
        (s) => s.copyWith(services: [...s.services, newSvc]),
      );
      return newSvc;
    }

    try {
      final res = await activeClient
          .from('services')
          .insert({
            'salon_id': salonId,
            'name': name,
            'category': category,
            'price': price,
            'duration_minutes': durationMinutes,
            'is_active': isActive,
          })
          .select()
          .single();

      final createdSvc = SalonService.fromJson(Map<String, dynamic>.from(res));

      _inMemoryServicesCache.putIfAbsent(salonId, () => []);
      _inMemoryServicesCache[salonId]!.removeWhere(
        (s) => s.id == createdSvc.id,
      );
      _inMemoryServicesCache[salonId]!.add(createdSvc);

      _updateOwnerSalonInMemory(
        salonId,
        (s) => s.copyWith(
          services: [
            ...s.services.where((svc) => svc.id != createdSvc.id),
            createdSvc,
          ],
        ),
      );

      debugPrint(
        '[SalonRepository] addService SUCCESS: ${createdSvc.id} (${createdSvc.name})',
      );
      return createdSvc;
    } catch (e) {
      debugPrint('[SalonRepository] addService DB ERROR: $e');
      rethrow;
    }
  }

  /// Updates an existing service in Supabase public.services.
  Future<SalonService> updateService({
    required String serviceId,
    required String name,
    required String category,
    required double price,
    required int durationMinutes,
    required bool isActive,
    String? salonId,
  }) async {
    final activeClient = client;

    if (activeClient == null) {
      SalonService? updatedSvc;
      if (salonId != null && _inMemoryServicesCache.containsKey(salonId)) {
        final idx = _inMemoryServicesCache[salonId]!.indexWhere(
          (s) => s.id == serviceId,
        );
        if (idx != -1) {
          updatedSvc = _inMemoryServicesCache[salonId]![idx].copyWith(
            name: name,
            category: category,
            price: price,
            durationMinutes: durationMinutes,
            isActive: isActive,
          );
          _inMemoryServicesCache[salonId]![idx] = updatedSvc;
        }
      }
      for (final list in _inMemoryServicesCache.values) {
        final idx = list.indexWhere((s) => s.id == serviceId);
        if (idx != -1) {
          updatedSvc = list[idx].copyWith(
            name: name,
            category: category,
            price: price,
            durationMinutes: durationMinutes,
            isActive: isActive,
          );
          list[idx] = updatedSvc;
        }
      }
      for (final entry in _ownerSalonsCache.entries) {
        final s = entry.value;
        final svcIdx = s.services.indexWhere((svc) => svc.id == serviceId);
        if (svcIdx != -1) {
          final updatedServices = List<SalonService>.from(s.services);
          updatedSvc = updatedServices[svcIdx].copyWith(
            name: name,
            category: category,
            price: price,
            durationMinutes: durationMinutes,
            isActive: isActive,
          );
          updatedServices[svcIdx] = updatedSvc;
          _ownerSalonsCache[entry.key] = s.copyWith(services: updatedServices);
        }
      }
      return updatedSvc ??
          SalonService(
            id: serviceId,
            salonId: salonId ?? '',
            name: name,
            category: category,
            price: price,
            durationMinutes: durationMinutes,
            isActive: isActive,
          );
    }

    try {
      final res = await activeClient
          .from('services')
          .update({
            'name': name,
            'category': category,
            'price': price,
            'duration_minutes': durationMinutes,
            'is_active': isActive,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', serviceId)
          .select()
          .single();

      final updatedSvc = SalonService.fromJson(Map<String, dynamic>.from(res));

      for (final list in _inMemoryServicesCache.values) {
        final idx = list.indexWhere((s) => s.id == serviceId);
        if (idx != -1) {
          list[idx] = updatedSvc;
        }
      }

      for (final entry in _ownerSalonsCache.entries) {
        final s = entry.value;
        final svcIdx = s.services.indexWhere((svc) => svc.id == serviceId);
        if (svcIdx != -1) {
          final updatedServices = List<SalonService>.from(s.services);
          updatedServices[svcIdx] = updatedSvc;
          _ownerSalonsCache[entry.key] = s.copyWith(services: updatedServices);
        }
      }

      debugPrint(
        '[SalonRepository] updateService SUCCESS: ${updatedSvc.id} (${updatedSvc.name})',
      );
      return updatedSvc;
    } catch (e) {
      debugPrint('[SalonRepository] updateService DB ERROR: $e');
      rethrow;
    }
  }

  /// Deletes a service from Supabase public.services.
  Future<void> deleteService(String serviceId, {String? salonId}) async {
    final activeClient = client;

    if (activeClient == null) {
      if (salonId != null && _inMemoryServicesCache.containsKey(salonId)) {
        _inMemoryServicesCache[salonId]!.removeWhere((s) => s.id == serviceId);
      }
      for (final list in _inMemoryServicesCache.values) {
        list.removeWhere((s) => s.id == serviceId);
      }
      for (final entry in _ownerSalonsCache.entries) {
        final s = entry.value;
        if (s.services.any((svc) => svc.id == serviceId)) {
          final updatedServices = s.services
              .where((svc) => svc.id != serviceId)
              .toList();
          _ownerSalonsCache[entry.key] = s.copyWith(services: updatedServices);
        }
      }
      return;
    }

    try {
      await activeClient.from('services').delete().eq('id', serviceId);

      for (final list in _inMemoryServicesCache.values) {
        list.removeWhere((s) => s.id == serviceId);
      }

      for (final entry in _ownerSalonsCache.entries) {
        final s = entry.value;
        if (s.services.any((svc) => svc.id == serviceId)) {
          final updatedServices = s.services
              .where((svc) => svc.id != serviceId)
              .toList();
          _ownerSalonsCache[entry.key] = s.copyWith(services: updatedServices);
        }
      }

      debugPrint('[SalonRepository] deleteService SUCCESS: $serviceId');
    } catch (e) {
      debugPrint('[SalonRepository] deleteService DB ERROR: $e');
      rethrow;
    }
  }

  List<Salon> _filterLocalSalons(
    List<Salon> list, {
    String? state,
    String? city,
    String? district,
    String? pincode,
    String? search,
    String? category,
    String sortBy = 'nearest',
    double userLat = 18.5204,
    double userLng = 73.8567,
    double? maxRadiusKm,
  }) {
    final normState = normalizeLocation(state);
    final normDistrict = normalizeLocation(district);
    final normCity = normalizeLocation(city);
    final normPincode = normalizeLocation(pincode);
    final normSearch = normalizeLocation(search);

    final isAllStates =
        normState.isEmpty || normState == 'all' || normState == 'all states';
    final isAllCities =
        normCity.isEmpty ||
        normCity == 'all' ||
        normCity == 'all cities' ||
        normCity == 'all india' ||
        normCity == 'all locations';
    final isAllDistricts =
        normDistrict.isEmpty ||
        normDistrict == 'all' ||
        normDistrict == 'all districts';

    var result = list.map((s) {
      final dist = s.calculateDistance(userLat, userLng);
      return s.copyWith(distanceKm: dist);
    }).toList();

    if (normPincode.isNotEmpty) {
      result = result
          .where(
            (s) =>
                normalizeLocation(s.pincode).contains(normPincode) ||
                normalizeLocation(s.address).contains(normPincode),
          )
          .toList();
    }

    if (!isAllStates) {
      result = result.where((s) {
        final sState = normalizeLocation(s.state);
        final sAddr = normalizeLocation(s.address);
        return sState.contains(normState) ||
            normState.contains(sState) ||
            sAddr.contains(normState);
      }).toList();
    }

    if (!isAllDistricts) {
      result = result.where((s) {
        final sDist = normalizeLocation(s.district);
        final sCity = normalizeLocation(s.city);
        final sAddr = normalizeLocation(s.address);
        return sDist.contains(normDistrict) ||
            normDistrict.contains(sDist) ||
            sCity.contains(normDistrict) ||
            normDistrict.contains(sCity) ||
            sAddr.contains(normDistrict);
      }).toList();
    }

    if (!isAllCities) {
      final cityMatches = result.where((s) {
        final sCity = normalizeLocation(s.city);
        final sDist = normalizeLocation(s.district);
        final sAddr = normalizeLocation(s.address);
        final sName = normalizeLocation(s.name);
        return sCity.contains(normCity) ||
            normCity.contains(sCity) ||
            sDist.contains(normCity) ||
            normDistrict.contains(sCity) ||
            sAddr.contains(normCity) ||
            normCity.contains(sAddr) ||
            sName.contains(normCity) ||
            normCity.contains(sName);
      }).toList();

      if (cityMatches.isNotEmpty) {
        result = cityMatches;
      } else if (maxRadiusKm != null && maxRadiusKm > 0) {
        result = result
            .where((s) => (s.distanceKm ?? 999) <= maxRadiusKm)
            .toList();
      } else {
        result = [];
      }
    }

    if (normSearch.isNotEmpty) {
      result = result.where((s) {
        final sName = normalizeLocation(s.name);
        final sOwner = normalizeLocation(s.ownerName);
        final sAddr = normalizeLocation(s.address);
        final sCity = normalizeLocation(s.city);
        final sDist = normalizeLocation(s.district);
        final sState = normalizeLocation(s.state);
        final sPin = normalizeLocation(s.pincode);
        final sDesc = normalizeLocation(s.description);
        final hasService = s.services.any(
          (svc) => normalizeLocation(svc.name).contains(normSearch),
        );

        return sName.contains(normSearch) ||
            sOwner.contains(normSearch) ||
            sAddr.contains(normSearch) ||
            sCity.contains(normSearch) ||
            sDist.contains(normSearch) ||
            sState.contains(normSearch) ||
            sPin.contains(normSearch) ||
            sDesc.contains(normSearch) ||
            hasService;
      }).toList();
    }

    final catFiltered = _filterByCategory(result, category);
    return _sortSalons(catFiltered, sortBy);
  }

  List<Salon> _filterByCategory(List<Salon> list, String? category) {
    if (category == null ||
        category.isEmpty ||
        category == 'All' ||
        category == 'Favorites') {
      return list;
    }
    return list
        .where(
          (s) =>
              s.services.any(
                (svc) => svc.category.toLowerCase() == category.toLowerCase(),
              ) ||
              s.name.toLowerCase().contains(category.toLowerCase()),
        )
        .toList();
  }

  List<Salon> _sortSalons(List<Salon> list, String sortBy) {
    final sorted = List<Salon>.from(list);
    switch (sortBy) {
      case 'rush':
        sorted.sort((a, b) => a.waitingCount.compareTo(b.waitingCount));
        break;
      case 'rating':
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'nearest':
      default:
        sorted.sort(
          (a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999),
        );
        break;
    }
    return sorted;
  }
}
