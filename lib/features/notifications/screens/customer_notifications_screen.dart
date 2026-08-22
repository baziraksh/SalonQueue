import 'package:flutter/material.dart';
import '../../../core/theme/color_schemes.dart';
import '../../auth/services/auth_scope.dart';
import '../../support/screens/support_center_screen.dart';
import '../data/notification_repository.dart';
import '../models/app_notification.dart';

/// Screen displaying notifications for the customer account:
/// - Queue status updates (joined, called to chair, wait time changes)
/// - Support ticket resolution alerts (with tap-to-view details)
/// - Account and booking updates
class CustomerNotificationsScreen extends StatefulWidget {
  const CustomerNotificationsScreen({super.key, this.customerId});

  final String? customerId;

  @override
  State<CustomerNotificationsScreen> createState() =>
      _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState
    extends State<CustomerNotificationsScreen> {
  final NotificationRepository _notifRepo = NotificationRepository();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'All'; // 'All', 'Queue', 'Support', 'System'

  final List<String> _filters = ['All', 'Queue', 'Support', 'System'];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  String _getEffectiveCustomerId() {
    if (widget.customerId != null && widget.customerId!.isNotEmpty) {
      return widget.customerId!;
    }
    final auth = AuthScope.of(context, listen: false);
    return auth.currentUser?.id ?? 'customer-demo';
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final customerId = _getEffectiveCustomerId();
    final list = await _notifRepo.fetchNotifications(customerId);
    if (!mounted) return;
    setState(() {
      _notifications = list;
      _isLoading = false;
    });
  }

  List<AppNotification> get _filteredNotifications {
    if (_selectedFilter == 'All') return _notifications;
    return _notifications.where((n) {
      switch (_selectedFilter) {
        case 'Queue':
          return n.type == NotificationType.customerJoined ||
              n.type == NotificationType.customerCalled ||
              n.type == NotificationType.customerCancelled ||
              n.type == NotificationType.queueUpdate ||
              n.type == NotificationType.bookingUpdate;
        case 'Support':
          return n.type == NotificationType.supportResolved ||
              n.type == NotificationType.supportUpdate;
        case 'System':
        default:
          return n.type == NotificationType.systemUpdate;
      }
    }).toList();
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> _handleMarkAsRead(AppNotification notif) async {
    if (!notif.isRead) {
      await _notifRepo.markAsRead(notif.id);
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == notif.id);
        if (idx != -1) {
          _notifications[idx] = _notifications[idx].copyWith(isRead: true);
        }
      });
    }
  }

  Future<void> _handleMarkAllAsRead() async {
    final customerId = _getEffectiveCustomerId();
    await _notifRepo.markAllAsRead(customerId);
    setState(() {
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read.'),
          backgroundColor: AppColorSchemes.navy,
        ),
      );
    }
  }

  Future<void> _handleDeleteNotification(String notifId) async {
    await _notifRepo.deleteNotification(notifId);
    setState(() {
      _notifications.removeWhere((n) => n.id == notifId);
    });
  }

  void _showNotificationDetailModal(AppNotification notif) {
    _handleMarkAsRead(notif);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: notif.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(notif.icon, color: notif.accentColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColorSchemes.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notif.timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              notif.message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColorSchemes.charcoal,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // If related to support ticket, offer direct navigation to Help & Support
            if (notif.type == NotificationType.supportResolved ||
                notif.type == NotificationType.supportUpdate) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SupportCenterScreen(
                          isOwner: false,
                          initialTabIndex: 2, // My Queries Tab
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.help_outline_rounded, size: 18),
                  label: const Text('VIEW SUPPORT QUERY DETAILS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColorSchemes.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _handleDeleteNotification(notif.id);
                  Navigator.of(ctx).pop();
                },
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red,
                ),
                label: const Text(
                  'DELETE NOTIFICATION',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotifications;

    return Scaffold(
      backgroundColor: AppColorSchemes.ivory,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColorSchemes.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _handleMarkAllAsRead,
              child: const Text(
                'Mark All Read',
                style: TextStyle(
                  color: AppColorSchemes.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Chips ──────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      selectedColor: AppColorSchemes.navy,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColorSchemes.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedFilter = filter);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Notifications List ─────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColorSchemes.gold,
                    ),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColorSchemes.navy.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_off_outlined,
                            size: 48,
                            color: AppColorSchemes.navy,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColorSchemes.charcoal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You will be notified when your queue status changes.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: AppColorSchemes.navy,
                    onRefresh: _loadNotifications,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notif = filtered[index];
                        return _buildNotificationCard(notif);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notif) {
    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _handleDeleteNotification(notif.id),
      child: Container(
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white : const Color(0xFFFDFBF7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: notif.isRead
                ? Colors.grey.shade200
                : AppColorSchemes.gold.withValues(alpha: 0.5),
            width: notif.isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _showNotificationDetailModal(notif),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: notif.accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(notif.icon, color: notif.accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                notif.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: notif.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                  color: AppColorSchemes.charcoal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!notif.isRead) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColorSchemes.gold,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notif.message,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notif.timeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
