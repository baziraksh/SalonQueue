import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../../shared/data/india_locations.dart';

/// Represents a location suggestion returned by the location search service.
class LocationSuggestion {
  final String title;
  final String subtitle;
  final String? city;
  final String? district;
  final String? state;
  final String? pincode;
  final double latitude;
  final double longitude;
  final String? rawAddress;

  const LocationSuggestion({
    required this.title,
    required this.subtitle,
    this.city,
    this.district,
    this.state,
    this.pincode,
    required this.latitude,
    required this.longitude,
    this.rawAddress,
  });

  /// Factory from OpenStreetMap / Nominatim JSON item
  factory LocationSuggestion.fromNominatim(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};
    final lat = double.tryParse(json['lat']?.toString() ?? '') ?? 18.5204;
    final lon = double.tryParse(json['lon']?.toString() ?? '') ?? 73.8567;

    final road = address['road'] as String?;
    final suburb =
        address['suburb'] as String? ?? address['neighbourhood'] as String?;
    final city =
        address['city'] as String? ??
        address['town'] as String? ??
        address['municipality'] as String? ??
        address['village'] as String? ??
        address['county'] as String?;
    final district =
        address['county'] as String? ??
        address['state_district'] as String? ??
        city;
    final state = address['state'] as String?;
    final pincode = address['postcode'] as String?;

    // Determine primary display title (e.g. "Saheed Nagar", "FC Road", "Janpath", or City)
    String title =
        suburb ?? road ?? city ?? json['name'] as String? ?? 'Location';
    if (title.isEmpty) title = 'Location';

    // Build concise subtitle: "City, District, State - PIN"
    final subtitleParts = <String>[];
    if (city != null &&
        city.isNotEmpty &&
        city.toLowerCase() != title.toLowerCase()) {
      subtitleParts.add(city);
    }
    if (district != null &&
        district.isNotEmpty &&
        district.toLowerCase() != title.toLowerCase() &&
        (city == null || district.toLowerCase() != city.toLowerCase())) {
      subtitleParts.add(district);
    }
    if (state != null && state.isNotEmpty) {
      subtitleParts.add(state);
    }
    if (pincode != null && pincode.isNotEmpty) {
      subtitleParts.add(pincode);
    }

    final subtitle = subtitleParts.isNotEmpty
        ? subtitleParts.join(', ')
        : (json['display_name'] as String? ?? 'India');

    return LocationSuggestion(
      title: title,
      subtitle: subtitle,
      city: city,
      district: district,
      state: state,
      pincode: pincode,
      latitude: lat,
      longitude: lon,
      rawAddress: json['display_name'] as String?,
    );
  }

  /// Factory from Indian Locations offline database item
  factory LocationSuggestion.fromOfflineLocation({
    required String name,
    required String state,
    String? type,
    String? pincode,
  }) {
    // Known approximate coordinates for Indian State/City centers
    final coords = LocationSuggestionService.getEstimatedCoordinates(
      name,
      state,
    );
    final resolvedDistrict =
        IndiaLocations.resolveDistrictForCity(name, state) ?? name;

    return LocationSuggestion(
      title: name,
      subtitle: resolvedDistrict.toLowerCase() != name.toLowerCase()
          ? '$name, $resolvedDistrict, $state • India'
          : '$state • India ${pincode != null ? "($pincode)" : ""}',
      city: name,
      district: resolvedDistrict,
      state: state,
      pincode: pincode,
      latitude: coords.latitude,
      longitude: coords.longitude,
      rawAddress: '$name, $resolvedDistrict, $state, India',
    );
  }
}

/// Service handling live location suggestions, geocoding, and distance calculations.
class LocationSuggestionService {
  LocationSuggestionService._();

  static final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4);

  /// Calculates Haversine distance in kilometers between two geo-coordinates.
  static double calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distance = earthRadiusKm * c;
    return double.parse(distance.toStringAsFixed(1));
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Searches for location suggestions matching [query].
  /// Blends live OpenStreetMap / Nominatim Places search with the offline [IndiaLocations] database.
  static Future<List<LocationSuggestion>> searchLocationSuggestions(
    String query, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final results = <LocationSuggestion>[];
    final seenTitles = <String>{};

    // 1. First, search live online places / area geocoding
    try {
      final onlineSuggestions = await _fetchOnlineSuggestions(
        cleanQuery,
      ).timeout(timeout);
      for (final s in onlineSuggestions) {
        final key = '${s.title.toLowerCase()}_${s.subtitle.toLowerCase()}';
        if (!seenTitles.contains(key)) {
          seenTitles.add(key);
          results.add(s);
        }
      }
    } catch (e) {
      debugPrint('[LocationSuggestionService] Online search fallback: $e');
    }

    // 2. Supplement with exhaustive offline Indian Locations database
    final offlineMatches = IndiaLocations.searchLocations(cleanQuery);
    for (final m in offlineMatches) {
      final name = m['name'] ?? '';
      final state = m['state'] ?? '';
      final type = m['type'];
      final key = '${name.toLowerCase()}_${state.toLowerCase()}';

      if (!seenTitles.contains(key)) {
        seenTitles.add(key);
        results.add(
          LocationSuggestion.fromOfflineLocation(
            name: name,
            state: state,
            type: type,
          ),
        );
      }
    }

    return results;
  }

  /// Internal HTTP call to Nominatim OpenStreetMap Places API for India
  static Future<List<LocationSuggestion>> _fetchOnlineSuggestions(
    String query,
  ) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&addressdetails=1&limit=8&countrycodes=in',
      );

      final request = await _httpClient
          .getUrl(uri)
          .timeout(const Duration(milliseconds: 800));
      request.headers.set(
        'User-Agent',
        'SalonQueueApp/1.0 (contact: support@salonqueue.app)',
      );
      request.headers.set('Accept', 'application/json');

      final response = await request.close().timeout(
        const Duration(milliseconds: 800),
      );
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(body) as List<dynamic>;

        return decoded
            .whereType<Map<String, dynamic>>()
            .map((item) => LocationSuggestion.fromNominatim(item))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Geocodes an address, city, district, state, and pincode to resolve `(lat, lng)` coordinates.
  static Future<Map<String, double>> geocodeAddress({
    required String address,
    required String city,
    required String district,
    required String state,
    String? pincode,
  }) async {
    final queryParts = <String>[];
    if (address.isNotEmpty) queryParts.add(address);
    if (city.isNotEmpty) queryParts.add(city);
    if (district.isNotEmpty && district.toLowerCase() != city.toLowerCase()) {
      queryParts.add(district);
    }
    if (state.isNotEmpty) queryParts.add(state);
    if (pincode != null && pincode.isNotEmpty) queryParts.add(pincode);
    queryParts.add('India');

    final fullQuery = queryParts.join(', ');

    try {
      final suggestions = await searchLocationSuggestions(fullQuery);
      if (suggestions.isNotEmpty) {
        return {
          'latitude': suggestions.first.latitude,
          'longitude': suggestions.first.longitude,
        };
      }
    } catch (e) {
      debugPrint('[LocationSuggestionService] Geocoding notice: $e');
    }

    // Fallback: Use known city/state center coordinates
    final fallbackCoords = getEstimatedCoordinates(
      city.isNotEmpty ? city : district,
      state,
    );
    return {
      'latitude': fallbackCoords.latitude,
      'longitude': fallbackCoords.longitude,
    };
  }

  /// Fallback coordinate lookup for major Indian regions/cities
  static ({double latitude, double longitude}) getEstimatedCoordinates(
    String cityOrDistrict,
    String state,
  ) {
    final clean = cityOrDistrict.toLowerCase().trim();
    final cleanState = state.toLowerCase().trim();

    // Specific City Coordinates
    if (clean.contains('pune')) {
      return (latitude: 18.5204, longitude: 73.8567);
    }
    if (clean.contains('mumbai') || clean.contains('bandra') || clean.contains('andheri')) {
      return (latitude: 19.0760, longitude: 72.8777);
    }
    if (clean.contains('angul')) {
      return (latitude: 20.8398, longitude: 85.1013);
    }
    if (clean.contains('bhubaneswar')) {
      return (latitude: 20.2961, longitude: 85.8245);
    }
    if (clean.contains('cuttack')) {
      return (latitude: 20.4625, longitude: 85.8828);
    }
    if (clean.contains('bangalore') || clean.contains('bengaluru') || clean.contains('koramangala') || clean.contains('indiranagar')) {
      return (latitude: 12.9716, longitude: 77.5946);
    }
    if (clean.contains('delhi') || clean.contains('connaught') || clean.contains('dwarka')) {
      return (latitude: 28.6139, longitude: 77.2090);
    }
    if (clean.contains('hyderabad') || clean.contains('secunderabad')) {
      return (latitude: 17.3850, longitude: 78.4867);
    }
    if (clean.contains('chennai')) {
      return (latitude: 13.0827, longitude: 80.2707);
    }
    if (clean.contains('kolkata')) {
      return (latitude: 22.5726, longitude: 88.3639);
    }
    if (clean.contains('ahmedabad')) {
      return (latitude: 23.0225, longitude: 72.5714);
    }
    if (clean.contains('jaipur')) {
      return (latitude: 26.9124, longitude: 75.7873);
    }
    if (clean.contains('lucknow')) {
      return (latitude: 26.8467, longitude: 80.9462);
    }
    if (clean.contains('patna')) {
      return (latitude: 25.5941, longitude: 85.1376);
    }
    if (clean.contains('chandigarh')) {
      return (latitude: 30.7333, longitude: 76.7794);
    }
    if (clean.contains('nagpur')) {
      return (latitude: 21.1458, longitude: 79.0882);
    }
    if (clean.contains('indore')) {
      return (latitude: 22.7196, longitude: 75.8577);
    }
    if (clean.contains('kochi') || clean.contains('cochin')) {
      return (latitude: 9.9312, longitude: 76.2673);
    }
    if (clean.contains('guwahati')) {
      return (latitude: 26.1445, longitude: 91.7362);
    }

    // State Center Fallbacks
    if (cleanState.contains('odisha') || cleanState.contains('orissa')) {
      return (latitude: 20.9517, longitude: 85.0985);
    }
    if (cleanState.contains('maharashtra')) {
      return (latitude: 19.7515, longitude: 75.7139);
    }
    if (cleanState.contains('karnataka')) {
      return (latitude: 15.3173, longitude: 75.7139);
    }
    if (cleanState.contains('tamil nadu')) {
      return (latitude: 11.1271, longitude: 78.6569);
    }
    if (cleanState.contains('gujarat')) {
      return (latitude: 22.2587, longitude: 71.1924);
    }
    if (cleanState.contains('rajasthan')) {
      return (latitude: 27.0238, longitude: 74.2179);
    }
    if (cleanState.contains('uttar pradesh')) {
      return (latitude: 26.8467, longitude: 80.9462);
    }
    if (cleanState.contains('west bengal')) {
      return (latitude: 22.9868, longitude: 87.8550);
    }
    if (cleanState.contains('bihar')) {
      return (latitude: 25.0961, longitude: 85.3131);
    }
    if (cleanState.contains('punjab')) {
      return (latitude: 31.1471, longitude: 75.3412);
    }
    if (cleanState.contains('haryana')) {
      return (latitude: 29.0588, longitude: 76.0856);
    }
    if (cleanState.contains('kerala')) {
      return (latitude: 10.8505, longitude: 76.2711);
    }

    // National center default
    return (latitude: 20.5937, longitude: 78.9629);
  }
}
