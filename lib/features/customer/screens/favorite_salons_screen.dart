import 'package:flutter/material.dart';
import '../../../shared/models/salon.dart';
import '../../../shared/widgets/salon_card.dart';
import '../../salon/data/salon_repository.dart';
import '../../salon/screens/salon_details_screen.dart';

/// Screen displaying the customer's saved / favorite salons
class FavoriteSalonsScreen extends StatefulWidget {
  final Set<String>? initialFavoriteIds;

  const FavoriteSalonsScreen({super.key, this.initialFavoriteIds});

  @override
  State<FavoriteSalonsScreen> createState() => _FavoriteSalonsScreenState();
}

class _FavoriteSalonsScreenState extends State<FavoriteSalonsScreen> {
  final SalonRepository _salonRepo = SalonRepository();
  List<Salon> _favoriteSalons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavoriteSalons();
  }

  Future<void> _loadFavoriteSalons() async {
    setState(() => _isLoading = true);
    try {
      final allSalons = await _salonRepo.fetchSalons();
      final favIds = widget.initialFavoriteIds ?? {};

      List<Salon> filtered;
      if (favIds.isNotEmpty) {
        filtered = allSalons.where((s) => favIds.contains(s.id)).toList();
      } else {
        // If no explicit favorites were passed, show top-rated curated salons or empty
        filtered = [];
      }

      if (!mounted) return;
      setState(() {
        _favoriteSalons = filtered;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF111827),
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Favorite Salons',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF111827),
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6D28D9)),
            )
          : _favoriteSalons.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _favoriteSalons.length,
              itemBuilder: (context, idx) {
                final salon = _favoriteSalons[idx];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: SalonCard(
                    salon: salon,
                    isFavorite: true,
                    onFavoriteTap: () {
                      setState(() {
                        _favoriteSalons.removeAt(idx);
                      });
                    },
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SalonDetailsScreen(salon: salon),
                        ),
                      );
                    },
                    onJoinQueue: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SalonDetailsScreen(salon: salon),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Color(0xFFFDF2F8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                size: 44,
                color: Color(0xFFE11D48),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Favorite Salons Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the heart icon on any salon to save your favorite grooming spots for quick token booking.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D28D9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Discover Salons',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
