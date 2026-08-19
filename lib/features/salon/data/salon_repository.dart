// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../core/config/app_config.dart';
import '../../../shared/models/salon.dart';
import '../../../shared/models/salon_service.dart';

/// Data repository for discovering salons across all Indian States & Cities,
/// calculating live distances, rush levels, and owner salon management.
class SalonRepository {
  SalonRepository({supabase.SupabaseClient? client}) : _client = client;

  final supabase.SupabaseClient? _client;
  static final HttpClient _directHttpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..badCertificateCallback = ((_, __, ___) => true);

  /// Dedicated in-memory owner salon storage isolated strictly per auth.uid()
  static final Map<String, Salon> _ownerSalonsCache = {};

  /// Clears in-memory salon cache on user logout to prevent cross-account data leakage
  static void clearCache() {
    _ownerSalonsCache.clear();
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
  void _updateOwnerSalonInMemory(String salonId, Salon Function(Salon current) updater, {String? ownerId}) {
    // 1. Update in owner-isolated cache
    bool found = false;
    for (final entry in _ownerSalonsCache.entries) {
      if (entry.value.id == salonId ||
          entry.key == salonId ||
          (ownerId != null && (entry.key == ownerId || entry.value.ownerId == ownerId))) {
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

    // 2. Update in fallbackSalons if it matches
    final idx = fallbackSalons.indexWhere((s) => s.id == salonId || (ownerId != null && s.ownerId == ownerId));
    if (idx != -1) {
      fallbackSalons[idx] = updater(fallbackSalons[idx]);
      found = true;
    }

    // 3. If brand new, seed in cache
    if (!found) {
      final base = Salon(
        id: salonId,
        ownerId: ownerId,
        name: 'My Salon & Spa',
        address: '',
        city: '',
      );
      final updated = updater(base);
      if (ownerId != null && ownerId.isNotEmpty) {
        _ownerSalonsCache[ownerId] = updated;
      }
      if (salonId.isNotEmpty) {
        _ownerSalonsCache[salonId] = updated;
      }
      unawaited(_saveSalonToDisk(updated));
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

  /// Real registered salons cache only (No demo fake profiles)
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
      return Stream.value(_ownerSalonsCache.values.toList());
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
    } catch (_) {
      return Stream.periodic(const Duration(seconds: 4))
          .asyncMap((_) => fetchSalons(
                state: state,
                city: city,
                district: district,
                pincode: pincode,
                search: search,
                category: category,
                sortBy: sortBy,
                userLat: userLat,
                userLng: userLng,
              ));
    }
  }

  Future<List<dynamic>?> _fetchSalonsViaDirectHttp() async {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      final uri = Uri.parse('${AppConfig.supabaseUrl}/rest/v1/salons?select=*&order=created_at.desc');
      final req = await _directHttpClient.getUrl(uri).timeout(const Duration(seconds: 5));
      req.headers.set('apikey', AppConfig.supabaseAnonKey);
      req.headers.set('Authorization', 'Bearer ${AppConfig.supabaseAnonKey}');
      req.headers.set('Accept', 'application/json');
      final res = await req.close().timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final list = jsonDecode(body) as List<dynamic>;
        debugPrint('[SalonRepository] _fetchSalonsViaDirectHttp SUCCESS: loaded ${list.length} salons directly from database');
        return list;
      } else {
        final err = await res.transform(utf8.decoder).join();
        debugPrint('[SalonRepository] _fetchSalonsViaDirectHttp status ${res.statusCode}: $err');
      }
    } catch (e) {
      debugPrint('[SalonRepository] _fetchSalonsViaDirectHttp error: $e');
    }
    return null;
  }

  /// Fetches real registered salons from database filtered by state, district, city/village/area, pincode, or search query.
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
    final client = this.client;
    List<Salon> result = [];

    if (client != null) {
      try {
        final response = await client
            .from('salons')
            .select('*, services(*)')
            .order('created_at', ascending: false);

        for (final raw in (response as List)) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(raw as Map);
          final rawServices = map['services'] as List? ?? [];
          final services = rawServices
              .map((s) => SalonService.fromJson(Map<String, dynamic>.from(s as Map)))
              .toList();

          // Live waiting count from active tickets in DB
          try {
            final ticketsCount = await client
                .from('queue_tickets')
                .select('id')
                .eq('salon_id', map['id'])
                .eq('status', 'WAITING');
            map['waiting_count'] = (ticketsCount as List).length;
          } catch (_) {
            map['waiting_count'] = 0;
          }

          final salon = Salon.fromJson(
            map,
            services: services,
            userLat: userLat,
            userLng: userLng,
          );

          result.add(salon);
          _ownerSalonsCache[salon.ownerId ?? salon.id] = salon;
          _ownerSalonsCache[salon.id] = salon;
        }
      } on supabase.PostgrestException catch (pe) {
        if (pe.code == '431' || pe.message.contains('431') || pe.details?.toString().contains('431') == true) {
          debugPrint('[SalonRepository] Caught HTTP 431. Clearing bloated session to unblock DB...');
          try {
            await client.auth.signOut();
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('[SalonRepository] fetchSalons DB query notice: $e');
      }
    }

    // Direct clean REST query fallback if SDK query returned 0 salons (guarantees cross-device live fetching)
    if (result.isEmpty && AppConfig.isSupabaseConfigured) {
      try {
        final directList = await _fetchSalonsViaDirectHttp();
        if (directList != null && directList.isNotEmpty) {
          for (final raw in directList) {
            final Map<String, dynamic> map = Map<String, dynamic>.from(raw as Map);
            final rawServices = map['services'] as List? ?? [];
            final services = rawServices
                .map((s) => SalonService.fromJson(Map<String, dynamic>.from(s as Map)))
                .toList();

            final salon = Salon.fromJson(
              map,
              services: services,
              userLat: userLat,
              userLng: userLng,
            );

            result.add(salon);
            _ownerSalonsCache[salon.ownerId ?? salon.id] = salon;
            _ownerSalonsCache[salon.id] = salon;
          }
        }
      } catch (e) {
        debugPrint('[SalonRepository] Direct HTTP query notice: $e');
      }
    }

    // Merge in any locally registered owner salons that were provisioned
    for (final s in _ownerSalonsCache.values) {
      if (!result.any((existing) => existing.id == s.id || (s.ownerId != null && existing.ownerId == s.ownerId))) {
        final dist = s.calculateDistance(userLat, userLng);
        result.add(s.copyWith(distanceKm: dist));
      }
    }

    // Normalize search terms
    String? cleanCity = city?.trim();
    String? cleanDistrict = district?.trim();
    String? cleanPincode = pincode?.trim();
    String? cleanState = state?.trim();

    if (cleanCity != null &&
        (cleanCity.isEmpty ||
            cleanCity.toLowerCase() == 'all' ||
            cleanCity.toLowerCase() == 'all cities' ||
            cleanCity.toLowerCase() == 'all india' ||
            cleanCity.toLowerCase() == 'all locations')) {
      cleanCity = null;
    }

    if (cleanState != null &&
        (cleanState.isEmpty ||
            cleanState.toLowerCase() == 'all' ||
            cleanState.toLowerCase() == 'all states')) {
      cleanState = null;
    }

    var filtered = result;

    // 1. Filter by State
    if (cleanState != null && cleanState.isNotEmpty) {
      final sState = cleanState.toLowerCase();
      filtered = filtered.where((s) =>
          s.state.toLowerCase().contains(sState) ||
          s.city.toLowerCase().contains(sState) ||
          s.district.toLowerCase().contains(sState) ||
          s.address.toLowerCase().contains(sState)).toList();
    }

    // 2. Filter by District
    if (cleanDistrict != null && cleanDistrict.isNotEmpty) {
      final d = cleanDistrict.toLowerCase();
      filtered = filtered.where((s) =>
          s.district.toLowerCase().contains(d) ||
          s.city.toLowerCase().contains(d) ||
          s.address.toLowerCase().contains(d) ||
          s.state.toLowerCase().contains(d)).toList();
    }

    // 3. Filter by City / Village / Area / Locality
    if (cleanCity != null && cleanCity.isNotEmpty) {
      final c = cleanCity.toLowerCase();
      final cityMatches = filtered.where((s) =>
          s.city.toLowerCase().contains(c) ||
          c.contains(s.city.toLowerCase()) ||
          s.district.toLowerCase().contains(c) ||
          c.contains(s.district.toLowerCase()) ||
          s.address.toLowerCase().contains(c) ||
          c.contains(s.address.toLowerCase()) ||
          s.name.toLowerCase().contains(c) ||
          c.contains(s.name.toLowerCase()) ||
          s.state.toLowerCase().contains(c)).toList();

      if (cityMatches.isNotEmpty) {
        filtered = cityMatches;
      } else if (maxRadiusKm != null && maxRadiusKm > 0) {
        filtered = filtered.where((s) => (s.distanceKm ?? 999) <= maxRadiusKm).toList();
      } else {
        filtered = [];
      }
    }

    // 4. Filter by Pincode
    if (cleanPincode != null && cleanPincode.isNotEmpty) {
      filtered = filtered.where((s) =>
          (s.pincode != null && s.pincode!.contains(cleanPincode)) ||
          s.address.contains(cleanPincode)).toList();
    }

    // 5. Filter by Proximity Radius if specified
    if (maxRadiusKm != null && maxRadiusKm > 0 && (cleanCity == null || cleanCity.isEmpty)) {
      final radiusMatches = filtered.where((s) => (s.distanceKm ?? 999) <= maxRadiusKm).toList();
      if (radiusMatches.isNotEmpty) {
        filtered = radiusMatches;
      }
    }

    // 6. Filter by Search Query (searches village, area, salon name, owner, services, etc.)
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      final queryMatches = filtered.where((s) =>
          s.name.toLowerCase().contains(q) ||
          (s.ownerName != null && s.ownerName!.toLowerCase().contains(q)) ||
          s.address.toLowerCase().contains(q) ||
          s.city.toLowerCase().contains(q) ||
          s.district.toLowerCase().contains(q) ||
          s.state.toLowerCase().contains(q) ||
          (s.pincode != null && s.pincode!.contains(q)) ||
          (s.description != null && s.description!.toLowerCase().contains(q)) ||
          s.services.any((svc) => svc.name.toLowerCase().contains(q))).toList();

      if (queryMatches.isNotEmpty) {
        filtered = queryMatches;
      } else {
        // Fallback: If strict location narrowed to 0, match search across all salons in DB
        final globalMatches = result.where((s) =>
            s.name.toLowerCase().contains(q) ||
            (s.ownerName != null && s.ownerName!.toLowerCase().contains(q)) ||
            s.address.toLowerCase().contains(q) ||
            s.city.toLowerCase().contains(q) ||
            s.district.toLowerCase().contains(q) ||
            s.state.toLowerCase().contains(q) ||
            (s.pincode != null && s.pincode!.contains(q)) ||
            (s.description != null && s.description!.toLowerCase().contains(q)) ||
            s.services.any((svc) => svc.name.toLowerCase().contains(q))).toList();
        filtered = globalMatches;
      }
    }

    final catFiltered = _filterByCategory(filtered, category);
    final sorted = _sortSalons(catFiltered, sortBy);

    debugPrint(
      '[SalonSearch] state=$cleanState, district=$cleanDistrict, city=$cleanCity, '
      'search="$search" | Total in DB: ${result.length}, Results: ${sorted.length}',
    );

    return sorted;
  }

  /// Fetches a single salon by ID or Owner ID
  Future<Salon?> fetchSalonById(String salonId) async {
    final trimmedId = salonId.trim();
    if (trimmedId.isEmpty) return null;

    final client = this.client;
    if (client == null) {
      final matches = fallbackSalons.where((s) => s.id == trimmedId || s.ownerId == trimmedId);
      if (matches.isNotEmpty) return matches.first;
      if (_ownerSalonsCache.containsKey(trimmedId)) return _ownerSalonsCache[trimmedId];
      final byOwner = _ownerSalonsCache.values.where((s) => s.id == trimmedId || s.ownerId == trimmedId);
      if (byOwner.isNotEmpty) return byOwner.first;
      return null;
    }

    try {
      final resList = await client
          .from('salons')
          .select('*, services(*)')
          .or('id.eq.$trimmedId,owner_id.eq.$trimmedId')
          .limit(1);

      if ((resList as List).isNotEmpty) {
        final map = Map<String, dynamic>.from(resList.first as Map);
        final rawServices = map['services'] as List? ?? [];
        final services = rawServices
            .map((s) => SalonService.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList();

        try {
          final tickets = await client
              .from('queue_tickets')
              .select('id')
              .eq('salon_id', map['id'])
              .eq('status', 'WAITING');
          map['waiting_count'] = (tickets as List).length;
        } catch (_) {
          map['waiting_count'] = 0;
        }

        final salon = Salon.fromJson(map, services: services);
        _ownerSalonsCache[salon.ownerId ?? salon.id] = salon;
        return salon;
      }

      if (_ownerSalonsCache.containsKey(trimmedId)) return _ownerSalonsCache[trimmedId];
      final byOwner = _ownerSalonsCache.values.where((s) => s.id == trimmedId || s.ownerId == trimmedId);
      if (byOwner.isNotEmpty) return byOwner.first;

      final matches = fallbackSalons.where((s) => s.id == trimmedId || s.ownerId == trimmedId);
      return matches.isNotEmpty ? matches.first : null;
    } catch (e) {
      debugPrint('[SalonRepository] fetchSalonById error: $e');
      if (_ownerSalonsCache.containsKey(trimmedId)) return _ownerSalonsCache[trimmedId];
      final byOwner = _ownerSalonsCache.values.where((s) => s.id == trimmedId || s.ownerId == trimmedId);
      if (byOwner.isNotEmpty) return byOwner.first;
      final matches = fallbackSalons.where((s) => s.id == trimmedId || s.ownerId == trimmedId);
      return matches.isNotEmpty ? matches.first : null;
    }
  }

  /// Fetches the salon owned by the current salon owner with strict per-owner data isolation
  Future<Salon?> fetchOwnerSalon(String ownerId) async {
    if (ownerId.isEmpty) return null;

    // 1. In-memory cache check
    if (_ownerSalonsCache.containsKey(ownerId)) {
      return _ownerSalonsCache[ownerId];
    }

    // 2. Local disk persistent cache check (restores immediately even after logout / cold restart)
    final diskSalon = await _loadSalonFromDisk(ownerId);
    if (diskSalon != null) {
      _ownerSalonsCache[ownerId] = diskSalon;
      _ownerSalonsCache[diskSalon.id] = diskSalon;
    }

    final client = this.client;
    if (client != null) {
      try {
        final resList = await client
            .from('salons')
            .select('*, services(*)')
            .eq('owner_id', ownerId)
            .order('updated_at', ascending: false)
            .limit(1);

        if ((resList as List).isNotEmpty) {
          final map = Map<String, dynamic>.from(resList.first as Map);
          final rawServices = map['services'] as List? ?? [];
          final services = rawServices
              .map((s) => SalonService.fromJson(Map<String, dynamic>.from(s as Map)))
              .toList();

          final remoteSalon = Salon.fromJson(map, services: services);

          // Merge disk customizations with remote DB row
          final finalSalon = diskSalon != null
              ? diskSalon.copyWith(
                  id: remoteSalon.id.isNotEmpty ? remoteSalon.id : diskSalon.id,
                  name: remoteSalon.name.isNotEmpty && remoteSalon.name != 'My Salon & Spa'
                      ? remoteSalon.name
                      : diskSalon.name,
                  description: remoteSalon.description ?? diskSalon.description,
                  phone: remoteSalon.phone ?? diskSalon.phone,
                  address: remoteSalon.address.isNotEmpty && remoteSalon.address != 'Main Market Road'
                      ? remoteSalon.address
                      : diskSalon.address,
                  city: remoteSalon.city.isNotEmpty && remoteSalon.city != 'Angul'
                      ? remoteSalon.city
                      : diskSalon.city,
                  district: remoteSalon.district.isNotEmpty ? remoteSalon.district : diskSalon.district,
                  state: remoteSalon.state.isNotEmpty ? remoteSalon.state : diskSalon.state,
                  coverImageUrl: remoteSalon.coverImageUrl ?? diskSalon.coverImageUrl,
                  bannerUrl: remoteSalon.bannerUrl ?? diskSalon.bannerUrl,
                  ownerAvatarUrl: remoteSalon.ownerAvatarUrl ?? diskSalon.ownerAvatarUrl,
                  ownerName: remoteSalon.ownerName ?? diskSalon.ownerName,
                  galleryImages: remoteSalon.galleryImages.isNotEmpty
                      ? remoteSalon.galleryImages
                      : diskSalon.galleryImages,
                  services: services.isNotEmpty ? services : diskSalon.services,
                )
              : remoteSalon;

          _ownerSalonsCache[ownerId] = finalSalon;
          _ownerSalonsCache[finalSalon.id] = finalSalon;
          unawaited(_saveSalonToDisk(finalSalon));
          return finalSalon;
        }

        // If not in DB but exists on local disk, sync local disk up to database
        if (diskSalon != null) {
          unawaited(_updateSalonInDb(diskSalon.id, diskSalon.toJson(), ownerId: ownerId));
          return diskSalon;
        }

        // Brand new owner without existing salon — provision a dedicated salon row for this auth.uid()
        try {
          String initialOwnerName = 'Salon Owner';
          try {
            final profile = await client.from('profiles').select('full_name').eq('id', ownerId).maybeSingle();
            if (profile != null && profile['full_name'] != null && profile['full_name'].toString().isNotEmpty) {
              initialOwnerName = profile['full_name'].toString();
            }
          } catch (_) {}

          final inserted = await client.from('salons').insert({
            'owner_id': ownerId,
            'name': 'My Salon & Spa',
            'owner_name': initialOwnerName,
            'description': 'Welcome to our premium salon.',
            'address': 'Main Market Road',
            'city': 'Angul',
            'district': 'Angul',
            'state': 'Odisha',
            'active_chairs': 3,
            'is_queue_open': true,
            'is_verified': true,
            'is_active': true,
            'is_published': true,
            'opening_time': '09:00 AM',
            'closing_time': '09:00 PM',
          }).select('*, services(*)').maybeSingle();

          if (inserted != null) {
            final map = Map<String, dynamic>.from(inserted);
            final salonId = map['id'] as String;

            try {
              final defaultServices = [
                {'salon_id': salonId, 'name': 'Classic Haircut', 'category': 'Hair', 'price': 150.0, 'duration_minutes': 25, 'is_active': true},
                {'salon_id': salonId, 'name': 'Beard Trim & Styling', 'category': 'Beard', 'price': 80.0, 'duration_minutes': 15, 'is_active': true},
                {'salon_id': salonId, 'name': 'Hair Spa & Scalp Massage', 'category': 'Spa', 'price': 250.0, 'duration_minutes': 30, 'is_active': true},
              ];
              final insertedServices = await client.from('services').insert(defaultServices).select();
              final services = (insertedServices as List)
                  .map((s) => SalonService.fromJson(Map<String, dynamic>.from(s as Map)))
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
          debugPrint('[SalonRepository] auto-provision owner salon error: $insertErr');
        }
      } catch (e) {
        debugPrint('[SalonRepository] fetchOwnerSalon error: $e');
      }
    }

    // Fallback: Return diskSalon or default isolated salon
    if (diskSalon != null) {
      return diskSalon;
    }

    final isolatedSalon = Salon(
      id: ownerId,
      ownerId: ownerId,
      name: 'My Salon & Spa',
      description: 'Welcome to our premium salon.',
      address: 'Main Market Road',
      city: 'Angul',
      district: 'Angul',
      state: 'Odisha',
      activeChairs: 3,
      isQueueOpen: true,
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

  /// Helper to update a salon row in Supabase, matching by owner_id or id
  Future<void> _updateSalonInDb(
    String salonId,
    Map<String, dynamic> updateData, {
    String? ownerId,
  }) async {
    final activeClient = client;
    final effectiveOwnerId =
        ownerId ?? activeClient?.auth.currentUser?.id;

    if (effectiveOwnerId == null || effectiveOwnerId.isEmpty) return;

    // 1. Retrieve current salon from cache or disk to construct a FULL, complete record
    Salon? existing = _ownerSalonsCache[effectiveOwnerId] ??
        _ownerSalonsCache.values.cast<Salon?>().firstWhere(
              (s) => s != null && (s.id == salonId || s.ownerId == effectiveOwnerId),
              orElse: () => null,
            );

    existing ??= await _loadSalonFromDisk(effectiveOwnerId);

    // 2. Immediately save local copy to memory and disk
    final localUpdated = (existing != null)
        ? existing.copyWith(
            name: updateData['name'] ?? existing.name,
            description: updateData['description'] ?? existing.description,
            phone: updateData.containsKey('phone') ? updateData['phone'] : existing.phone,
            address: updateData['address'] ?? existing.address,
            city: updateData['city'] ?? existing.city,
            district: updateData['district'] ?? existing.district,
            state: updateData['state'] ?? existing.state,
            pincode: updateData.containsKey('pincode') ? updateData['pincode'] : existing.pincode,
            activeChairs: updateData['active_chairs'] ?? existing.activeChairs,
            isQueueOpen: updateData['is_queue_open'] ?? existing.isQueueOpen,
            openingTime: updateData['opening_time'] ?? existing.openingTime,
            closingTime: updateData['closing_time'] ?? existing.closingTime,
            coverImageUrl: updateData.containsKey('cover_image_url')
                ? updateData['cover_image_url']
                : existing.coverImageUrl,
            bannerUrl: updateData.containsKey('banner_url')
                ? updateData['banner_url']
                : existing.bannerUrl,
            ownerName: updateData['owner_name'] ?? existing.ownerName,
            ownerAvatarUrl: updateData.containsKey('owner_avatar_url')
                ? updateData['owner_avatar_url']
                : existing.ownerAvatarUrl,
            galleryImages: updateData['gallery_images'] != null
                ? List<String>.from(updateData['gallery_images'])
                : existing.galleryImages,
          )
        : Salon.fromJson(updateData);

    _ownerSalonsCache[effectiveOwnerId] = localUpdated;
    if (localUpdated.id.isNotEmpty) {
      _ownerSalonsCache[localUpdated.id] = localUpdated;
    }
    unawaited(_saveSalonToDisk(localUpdated));

    if (activeClient == null) return;

    try {
      debugPrint('[SalonSave] ownerId = $effectiveOwnerId, updateData = $updateData');

      // 3. Prepare partial payload with only non-null updated fields
      final partialPayload = Map<String, dynamic>.from(updateData);
      partialPayload['updated_at'] = DateTime.now().toUtc().toIso8601String();

      // 4. Try partial update by owner_id
      bool updated = false;

      final resOwner = await activeClient
          .from('salons')
          .update(partialPayload)
          .eq('owner_id', effectiveOwnerId)
          .select('*, services(*)');

      if ((resOwner as List).isNotEmpty) {
        final map = Map<String, dynamic>.from(resOwner.first as Map);
        final rawServices = map['services'] as List? ?? [];
        final services = rawServices
            .map((s) => SalonService.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList();
        final updatedSalon = Salon.fromJson(map, services: services);
        _ownerSalonsCache[effectiveOwnerId] = updatedSalon;
        if (updatedSalon.id.isNotEmpty) {
          _ownerSalonsCache[updatedSalon.id] = updatedSalon;
        }
        unawaited(_saveSalonToDisk(updatedSalon));
        updated = true;
        debugPrint('[SalonSave] Updated existing salon by owner_id: ${updatedSalon.id} (${updatedSalon.name}) at ${updatedSalon.city}, ${updatedSalon.district}, ${updatedSalon.state}');
      }

      // If no row matched owner_id, try update by id
      if (!updated && salonId.isNotEmpty && salonId.length == 36 && !salonId.startsWith('salon-')) {
        final resId = await activeClient
            .from('salons')
            .update(partialPayload)
            .eq('id', salonId)
            .select('*, services(*)');

        if ((resId as List).isNotEmpty) {
          final map = Map<String, dynamic>.from(resId.first as Map);
          final rawServices = map['services'] as List? ?? [];
          final services = rawServices
              .map((s) => SalonService.fromJson(Map<String, dynamic>.from(s as Map)))
              .toList();
          final updatedSalon = Salon.fromJson(map, services: services);
          _ownerSalonsCache[effectiveOwnerId] = updatedSalon;
          _ownerSalonsCache[updatedSalon.id] = updatedSalon;
          unawaited(_saveSalonToDisk(updatedSalon));
          updated = true;
          debugPrint('[SalonSave] Updated existing salon by id: ${updatedSalon.id} (${updatedSalon.name})');
        }
      }

      // If salon does not exist in DB yet, insert the fullPayload
      if (!updated) {
        final fullPayload = <String, dynamic>{
          'owner_id': effectiveOwnerId,
          'name': updateData['name'] ?? existing?.name ?? 'My Salon & Spa',
          'description': updateData['description'] ?? existing?.description ?? 'Welcome to our premium salon.',
          'phone': updateData.containsKey('phone') ? updateData['phone'] : existing?.phone,
          'address': updateData['address'] ?? existing?.address ?? 'Main Market Road',
          'city': updateData['city'] ?? existing?.city ?? 'Angul',
          'district': updateData['district'] ?? existing?.district ?? 'Angul',
          'state': updateData['state'] ?? existing?.state ?? 'Odisha',
          'pincode': updateData.containsKey('pincode') ? updateData['pincode'] : existing?.pincode,
          'active_chairs': updateData['active_chairs'] ?? existing?.activeChairs ?? 3,
          'is_queue_open': updateData['is_queue_open'] ?? existing?.isQueueOpen ?? true,
          'is_verified': true,
          'is_active': true,
          'is_published': true,
          'opening_time': updateData['opening_time'] ?? existing?.openingTime ?? '09:00 AM',
          'closing_time': updateData['closing_time'] ?? existing?.closingTime ?? '09:00 PM',
          'cover_image_url': updateData.containsKey('cover_image_url')
              ? updateData['cover_image_url']
              : existing?.coverImageUrl,
          'banner_url': updateData.containsKey('banner_url')
              ? updateData['banner_url']
              : existing?.bannerUrl,
          'owner_name': updateData['owner_name'] ?? existing?.ownerName ?? 'Salon Owner',
          'owner_avatar_url': updateData.containsKey('owner_avatar_url')
              ? updateData['owner_avatar_url']
              : existing?.ownerAvatarUrl,
          'gallery_images': updateData['gallery_images'] ?? existing?.galleryImages ?? [],
          if (updateData['latitude'] != null || existing?.latitude != null)
            'latitude': updateData['latitude'] ?? existing?.latitude,
          if (updateData['longitude'] != null || existing?.longitude != null)
            'longitude': updateData['longitude'] ?? existing?.longitude,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };

        final resInsert = await activeClient
            .from('salons')
            .insert(fullPayload)
            .select('*, services(*)');

        if ((resInsert as List).isNotEmpty) {
          final map = Map<String, dynamic>.from(resInsert.first as Map);
          final rawServices = map['services'] as List? ?? [];
          final services = rawServices
              .map((s) => SalonService.fromJson(Map<String, dynamic>.from(s as Map)))
              .toList();
          final updatedSalon = Salon.fromJson(map, services: services);
          _ownerSalonsCache[effectiveOwnerId] = updatedSalon;
          _ownerSalonsCache[updatedSalon.id] = updatedSalon;
          unawaited(_saveSalonToDisk(updatedSalon));
          debugPrint('[SalonSave] Inserted brand new salon in DB: ${updatedSalon.id} (${updatedSalon.name})');
        }
      }
    } catch (e) {
      debugPrint('[SalonRepository] _updateSalonInDb error: $e');
    }
  }

  /// Updates queue open/closed status for salon owner
  Future<void> setQueueStatus(String salonId, bool isOpen, {String? ownerId}) async {
    _updateOwnerSalonInMemory(salonId, (s) => s.copyWith(isQueueOpen: isOpen), ownerId: ownerId);
    await _updateSalonInDb(salonId, {'is_queue_open': isOpen}, ownerId: ownerId);
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

    await _updateSalonInDb(
      salonId,
      {
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
      },
      ownerId: ownerId,
    );
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
      (s) => s.copyWith(
        name: name,
        description: description,
        phone: phone,
      ),
      ownerId: ownerId,
    );

    await _updateSalonInDb(
      salonId,
      {
        'name': name,
        'description': description,
        'phone': phone,
      },
      ownerId: ownerId,
    );
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

    await _updateSalonInDb(
      salonId,
      payload,
      ownerId: ownerId,
    );
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

    await _updateSalonInDb(
      salonId,
      {
        'active_chairs': activeChairs,
        'opening_time': openingTime,
        'closing_time': closingTime,
      },
      ownerId: ownerId,
    );
  }

  /// Updates salon main cover image
  Future<void> updateCoverImage({
    required String salonId,
    String? ownerId,
    required String? coverImageUrl,
  }) async {
    _updateOwnerSalonInMemory(
      salonId,
      (s) => s.copyWith(
        coverImageUrl: coverImageUrl,
        bannerUrl: coverImageUrl,
      ),
      ownerId: ownerId,
    );

    await _updateSalonInDb(
      salonId,
      {
        'cover_image_url': coverImageUrl,
        'banner_url': coverImageUrl,
      },
      ownerId: ownerId,
    );
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
    _updateOwnerSalonInMemory(
      salonId,
      (s) {
        currentGallery = [...s.galleryImages, imageUrl];
        return s.copyWith(galleryImages: currentGallery);
      },
      ownerId: ownerId,
    );

    await _updateSalonInDb(
      salonId,
      {'gallery_images': currentGallery},
      ownerId: ownerId,
    );
  }

  /// Removes a photo from the salon gallery
  Future<void> removeGalleryImage({
    required String salonId,
    String? ownerId,
    required String imageUrl,
  }) async {
    List<String> updatedGallery = [];
    _updateOwnerSalonInMemory(
      salonId,
      (s) {
        updatedGallery = s.galleryImages.where((img) => img != imageUrl).toList();
        return s.copyWith(galleryImages: updatedGallery);
      },
      ownerId: ownerId,
    );

    await _updateSalonInDb(
      salonId,
      {'gallery_images': updatedGallery},
      ownerId: ownerId,
    );
  }

  /// Adds a new service
  Future<SalonService?> addService({
    required String salonId,
    required String name,
    required String category,
    required double price,
    required int durationMinutes,
  }) async {
    final client = this.client;
    final newSvc = SalonService(
      id: 'svc-${DateTime.now().millisecondsSinceEpoch}',
      salonId: salonId,
      name: name,
      category: category,
      price: price,
      durationMinutes: durationMinutes,
      isActive: true,
    );

    _updateOwnerSalonInMemory(
      salonId,
      (s) => s.copyWith(services: [...s.services, newSvc]),
    );

    if (client == null) {
      return newSvc;
    }

    try {
      final res = await client.from('services').insert({
        'salon_id': salonId,
        'name': name,
        'category': category,
        'price': price,
        'duration_minutes': durationMinutes,
        'is_active': true,
      }).select().single();

      return SalonService.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('[SalonRepository] addService error: $e');
      return newSvc;
    }
  }

  /// Updates an existing service
  Future<void> updateService({
    required String serviceId,
    required String name,
    required String category,
    required double price,
    required int durationMinutes,
    required bool isActive,
  }) async {
    for (final entry in _ownerSalonsCache.entries) {
      final s = entry.value;
      final svcIdx = s.services.indexWhere((svc) => svc.id == serviceId);
      if (svcIdx != -1) {
        final updatedServices = List<SalonService>.from(s.services);
        updatedServices[svcIdx] = updatedServices[svcIdx].copyWith(
          name: name,
          category: category,
          price: price,
          durationMinutes: durationMinutes,
          isActive: isActive,
        );
        _ownerSalonsCache[entry.key] = s.copyWith(services: updatedServices);
      }
    }

    final client = this.client;
    if (client == null) return;

    try {
      await client.from('services').update({
        'name': name,
        'category': category,
        'price': price,
        'duration_minutes': durationMinutes,
        'is_active': isActive,
      }).eq('id', serviceId);
    } catch (e) {
      debugPrint('[SalonRepository] updateService error: $e');
    }
  }

  /// Deletes a service
  Future<void> deleteService(String serviceId) async {
    for (final entry in _ownerSalonsCache.entries) {
      final s = entry.value;
      if (s.services.any((svc) => svc.id == serviceId)) {
        final updatedServices = s.services.where((svc) => svc.id != serviceId).toList();
        _ownerSalonsCache[entry.key] = s.copyWith(services: updatedServices);
      }
    }

    final client = this.client;
    if (client == null) return;

    try {
      await client.from('services').delete().eq('id', serviceId);
    } catch (e) {
      debugPrint('[SalonRepository] deleteService error: $e');
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
    var result = list.map((s) {
      final dist = s.calculateDistance(userLat, userLng);
      return s.copyWith(distanceKm: dist);
    }).toList();

    if (pincode != null && pincode.isNotEmpty) {
      result = result.where((s) =>
          s.pincode == pincode ||
          s.address.contains(pincode)).toList();
    }

    if (state != null && state.isNotEmpty && state.toLowerCase() != 'all' && state.toLowerCase() != 'all states') {
      final sState = state.toLowerCase();
      result = result.where((s) =>
          s.state.toLowerCase().contains(sState) ||
          s.city.toLowerCase().contains(sState) ||
          s.district.toLowerCase().contains(sState) ||
          s.address.toLowerCase().contains(sState)).toList();
    }

    if (district != null && district.isNotEmpty) {
      final d = district.toLowerCase();
      result = result.where((s) =>
          s.district.toLowerCase().contains(d) ||
          s.city.toLowerCase().contains(d) ||
          s.address.toLowerCase().contains(d)).toList();
    }

    if (city != null && city.isNotEmpty && city.toLowerCase() != 'all' && city.toLowerCase() != 'all cities' && city.toLowerCase() != 'all india') {
      final c = city.toLowerCase();
      final cityMatches = result.where((s) =>
          s.city.toLowerCase().contains(c) ||
          s.district.toLowerCase().contains(c) ||
          s.address.toLowerCase().contains(c) ||
          s.state.toLowerCase().contains(c)).toList();
      if (cityMatches.isNotEmpty) {
        result = cityMatches;
      } else if (maxRadiusKm != null && maxRadiusKm > 0) {
        result = result.where((s) => (s.distanceKm ?? 999) <= maxRadiusKm).toList();
      } else {
        result = [];
      }
    }

    if (maxRadiusKm != null && maxRadiusKm > 0 && (city == null || city.isEmpty || city.toLowerCase() == 'all india' || city.toLowerCase() == 'all cities')) {
      final radiusMatches = result.where((s) => (s.distanceKm ?? 999) <= maxRadiusKm).toList();
      if (radiusMatches.isNotEmpty) {
        result = radiusMatches;
      }
    }

    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      result = result.where((s) =>
          s.name.toLowerCase().contains(q) ||
          (s.ownerName != null && s.ownerName!.toLowerCase().contains(q)) ||
          s.address.toLowerCase().contains(q) ||
          s.city.toLowerCase().contains(q) ||
          s.district.toLowerCase().contains(q) ||
          s.state.toLowerCase().contains(q) ||
          (s.pincode != null && s.pincode!.contains(q)) ||
          (s.description != null && s.description!.toLowerCase().contains(q)) ||
          s.services.any((svc) => svc.name.toLowerCase().contains(q))).toList();
    }

    final catFiltered = _filterByCategory(result, category);
    return _sortSalons(catFiltered, sortBy);
  }

  List<Salon> _filterByCategory(List<Salon> list, String? category) {
    if (category == null || category.isEmpty || category == 'All' || category == 'Favorites') {
      return list;
    }
    return list.where((s) =>
        s.services.any((svc) => svc.category.toLowerCase() == category.toLowerCase()) ||
        s.name.toLowerCase().contains(category.toLowerCase())).toList();
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
        sorted.sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));
        break;
    }
    return sorted;
  }
}
