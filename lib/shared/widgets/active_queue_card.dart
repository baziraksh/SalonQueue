import 'package:flutter/material.dart';
import '../../../core/theme/color_schemes.dart';
import '../models/queue_ticket.dart';

/// Premium active queue status banner with gold accent.
class ActiveQueueCard extends StatelessWidget {
  final QueueTicket ticket;
  final VoidCallback onTap;

  const ActiveQueueCard({super.key, required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isInChair = ticket.isInChair;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColorSchemes.navy, AppColorSchemes.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColorSchemes.gold.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColorSchemes.navy.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Token circular badge with gold ring
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColorSchemes.gold, width: 2),
                  ),
                  child: const Icon(
                    Icons.confirmation_number_outlined,
                    color: AppColorSchemes.gold,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),

                // Ticket info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Active Token: ${ticket.formattedToken}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isInChair
                                  ? AppColorSchemes.gold
                                  : AppColorSchemes.available,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ticket.status.label,
                              style: TextStyle(
                                color: isInChair ? Colors.black : Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to track live position & directions',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColorSchemes.gold,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
