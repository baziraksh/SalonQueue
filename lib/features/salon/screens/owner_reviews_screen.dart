import 'package:flutter/material.dart';
import '../../../shared/models/salon.dart';

/// Review item model for salon customer feedback.
class SalonCustomerReview {
  final String id;
  final String customerName;
  final String? customerAvatar;
  final double rating;
  final String comment;
  final DateTime date;

  const SalonCustomerReview({
    required this.id,
    required this.customerName,
    this.customerAvatar,
    required this.rating,
    required this.comment,
    required this.date,
  });
}

/// Screen allowing salon owners to view customer ratings and written reviews.
/// Designed to closely match the reference salon-management dashboard design system.
class OwnerReviewsScreen extends StatefulWidget {
  const OwnerReviewsScreen({super.key, required this.salon});

  final Salon salon;

  @override
  State<OwnerReviewsScreen> createState() => _OwnerReviewsScreenState();
}

class _OwnerReviewsScreenState extends State<OwnerReviewsScreen> {
  String _selectedFilter = 'All';

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')} ${_months[dt.month - 1]} ${dt.year}';
  }

  final List<SalonCustomerReview> _allReviews = [
    SalonCustomerReview(
      id: 'rev-1',
      customerName: 'Ravi Kumar',
      customerAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      rating: 5.0,
      comment: 'Great service and friendly staff! Really loved the precision haircut.',
      date: DateTime.now().subtract(const Duration(days: 2)),
    ),
    SalonCustomerReview(
      id: 'rev-2',
      customerName: 'Anita Singh',
      customerAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
      rating: 5.0,
      comment: 'Loved the hair spa. Very relaxing! The stylists are highly professional.',
      date: DateTime.now().subtract(const Duration(days: 4)),
    ),
    SalonCustomerReview(
      id: 'rev-3',
      customerName: 'Vikash Patel',
      customerAvatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
      rating: 4.0,
      comment: 'Good experience. The live queue system saved me so much waiting time.',
      date: DateTime.now().subtract(const Duration(days: 6)),
    ),
    SalonCustomerReview(
      id: 'rev-4',
      customerName: 'Neha Verma',
      customerAvatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150',
      rating: 5.0,
      comment: 'Top quality hair color and treatment. Will definitely come back regularly.',
      date: DateTime.now().subtract(const Duration(days: 9)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final salonRating = widget.salon.rating > 0 ? widget.salon.rating : 4.8;
    final totalReviewCount = widget.salon.reviewCount > 0 ? widget.salon.reviewCount : 128;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Reviews',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFilter,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280), size: 20),
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111827), fontSize: 13),
              items: ['All', '5 Stars', '4 Stars', '3 Stars'].map((f) {
                return DropdownMenuItem(value: f, child: Text(f));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedFilter = val);
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Rating Summary Card (Matches Reference) ───────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Big Rating Score
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        salonRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: List.generate(5, (index) {
                          return const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFB800),
                            size: 16,
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '($totalReviewCount Reviews)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 24),
                  Container(width: 1, height: 80, color: const Color(0xFFF1F3F5)),
                  const SizedBox(width: 20),

                  // 5-Star Distribution Bars
                  Expanded(
                    child: Column(
                      children: [
                        _buildRatingBar(star: 5, ratio: 0.76, count: 98),
                        const SizedBox(height: 4),
                        _buildRatingBar(star: 4, ratio: 0.16, count: 20),
                        const SizedBox(height: 4),
                        _buildRatingBar(star: 3, ratio: 0.05, count: 6),
                        const SizedBox(height: 4),
                        _buildRatingBar(star: 2, ratio: 0.02, count: 2),
                        const SizedBox(height: 4),
                        _buildRatingBar(star: 1, ratio: 0.01, count: 2),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── 2. Customer Reviews List ─────────────────────────────────
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _allReviews.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final review = _allReviews[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Reviewer Avatar
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFFF3E8FF),
                            backgroundImage: review.customerAvatar != null
                                ? NetworkImage(review.customerAvatar!)
                                : null,
                            child: review.customerAvatar == null
                                ? Text(
                                    review.customerName[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF6D28D9),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  review.customerName,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: List.generate(5, (sIdx) {
                                    return Icon(
                                      sIdx < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                      color: const Color(0xFFFFB800),
                                      size: 14,
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatDate(review.date),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        review.comment,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ── 3. View All Reviews Button ──────────────────────────────
            Center(
              child: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All customer reviews loaded.')),
                  );
                },
                child: const Text(
                  'View All Reviews',
                  style: TextStyle(
                    color: Color(0xFF6D28D9),
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBar({required int star, required double ratio, required int count}) {
    return Row(
      children: [
        Text(
          '$star',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFB800)),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: const Color(0xFFF1F3F5),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFB800)),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 18,
          child: Text(
            '$count',
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }
}
