import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/color_schemes.dart';
import '../../auth/services/auth_scope.dart';
import '../../support/screens/support_center_screen.dart';
import '../data/notification_repository.dart';
import '../models/app_notification.dart';

/// Screen allowing Salon Owners to view, filter, read, and manage notifications.
class OwnerNotificationsScreen extends StatefulWidget {
  const OwnerNotificationsScreen({super.key, this.ownerId});

  final String? ownerId;

  @override
  State<OwnerNotificationsScreen> createState() =>
      _OwnerNotificationsScreenState();
}

class _OwnerNotificationsScreenState extends State<OwnerNotificationsScreen> {
  final NotificationRepository _notifRepo = NotificationRepository();
  List<AppNotification> _notifications = [];
  StreamSubscription<List<AppNotification>>? _streamSub;
  bool _isLoading = true;
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Queue', 'Support', 'System'];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  String get _effectiveOwnerId {
    if (widget.ownerId != null && widget.ownerId!.isNotEmpty) {
      return widget.ownerId!;
    }
    final auth = AuthScope.of(context, listen: false);
    return auth.currentUser?.id ?? '';
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final ownerId = _effectiveOwnerId;

    _streamSub?.cancel();
    _streamSub = _notifRepo
        .streamNotifications(ownerId)
        .listen(
          (liveList) {
            if (mounted) {
              setState(() {
                _notifications = liveList;
                _isLoading = false;
              });
            }
          },
          onError: (err) {
            debugPrint('[OwnerNotificationsScreen] stream error: $err');
          },
        );

    final list = await _notifRepo.fetchNotifications(ownerId);
    if (!mounted) return;
    setState(() {
      _notifications = list;
      _isLoading = false;
    });
  }

  List<AppNotification> get _filteredNotifications {
    if (_selectedFilter == 'All') return _notifications;
    if (_selectedFilter == 'Queue') {
      return _notifications
          .where(
            (n) =>
                n.type == NotificationType.customerJoined ||
                n.type == NotificationType.customerCancelled ||
                n.type == NotificationType.customerCalled ||
                n.type == NotificationType.queueUpdate,
          )
          .toList();
    }
    if (_selectedFilter == 'Support') {
      return _notifications
          .where(
            (n) =>
                n.type == NotificationType.supportResolved ||
                n.type == NotificationType.supportUpdate,
          )
          .toList();
    }
    if (_selectedFilter == 'System') {
      return _notifications
          .where(
            (n) =>
                n.type == NotificationType.systemUpdate ||
                n.type == NotificationType.bookingUpdate,
          )
          .toList();
    }
    return _notifications;
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> _handleMarkAllAsRead() async {
    HapticFeedback.lightImpact();
    await _notifRepo.markAllAsRead(_effectiveOwnerId);
    setState(() {
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: AppColorSchemes.navy,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleNotificationTap(AppNotification notif) async {
    if (!notif.isRead) {
      await _notifRepo.markAsRead(notif.id);
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == notif.id);
        if (idx != -1) {
          _notifications[idx] = _notifications[idx].copyWith(isRead: true);
        }
      });
    }

    if (!mounted) return;

    // Show Detail Modal
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: notif.accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
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
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColorSchemes.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notif.timeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Message Body
              Text(
                notif.message,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: AppColorSchemes.charcoal,
                ),
              ),

              const SizedBox(height: 24),

              // Action button based on type
              if (notif.type == NotificationType.supportResolved ||
                  notif.type == NotificationType.supportUpdate) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SupportCenterScreen(
                            isOwner: true,
                            initialTabIndex: 2, // My Tickets tab
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.support_agent_rounded, size: 20),
                    label: const Text(
                      'View Support Ticket Details',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColorSchemes.navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColorSchemes.gold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Dismiss',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDeleteNotification(String id) async {
    HapticFeedback.selectionClick();
    await _notifRepo.deleteNotification(id);
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotifications;

    return Scaffold(
      backgroundColor: AppColorSchemes.ivory,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppColorSchemes.charcoal,
              ),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColorSchemes.gold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_unreadCount new',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _handleMarkAllAsRead,
              icon: const Icon(
                Icons.done_all_rounded,
                size: 16,
                color: AppColorSchemes.navy,
              ),
              label: const Text(
                'Mark read',
                style: TextStyle(
                  color: AppColorSchemes.navy,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                    selectedColor: AppColorSchemes.navy,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppColorSchemes.charcoal,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      fontSize: 12.5,
                    ),
                    backgroundColor: AppColorSchemes.ivory,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? AppColorSchemes.navy
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Notification List View
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColorSchemes.gold,
                    ),
                  )
                : filtered.isEmpty
                ? _buildEmptyState()
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
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => _handleDeleteNotification(notif.id),
      child: Material(
        color: notif.isRead ? Colors.white : const Color(0xFFFBF8F2),
        borderRadius: BorderRadius.circular(16),
        elevation: notif.isRead ? 0.5 : 1.5,
        shadowColor: AppColorSchemes.navy.withValues(alpha: 0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleNotificationTap(notif),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: notif.isRead
                    ? Colors.grey.shade200
                    : AppColorSchemes.gold.withValues(alpha: 0.4),
                width: notif.isRead ? 1 : 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: notif.accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(notif.icon, color: notif.accentColor, size: 20),
                ),
                const SizedBox(width: 12),

                // Content
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
                                fontWeight: notif.isRead
                                    ? FontWeight.w700
                                    : FontWeight.w900,
                                fontSize: 14,
                                color: AppColorSchemes.charcoal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            notif.timeAgo,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif.message,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: notif.isRead
                              ? Colors.grey.shade700
                              : AppColorSchemes.charcoal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Unread dot
                if (!notif.isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
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
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColorSchemes.navy.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 48,
              color: AppColorSchemes.navy,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColorSchemes.charcoal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You will be notified when customers join the queue,\nsupport issues are updated, and more.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
