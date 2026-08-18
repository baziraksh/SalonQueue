import 'package:flutter/material.dart';
import '../../../core/theme/color_schemes.dart';
import '../../auth/services/auth_scope.dart';
import '../data/faq_data.dart';
import '../data/support_repository.dart';
import '../models/support_ticket.dart';

/// Screen providing complete Help & Support Center, Interactive FAQs, Ticket Submission, and Ticket Tracking.
class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({
    super.key,
    this.isOwner = false,
    this.initialTabIndex = 0,
  });

  final bool isOwner;
  final int initialTabIndex;

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen>
    with SingleTickerProviderStateMixin {
  final SupportRepository _supportRepo = SupportRepository();
  late TabController _tabController;

  // Search & FAQ state
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';

  // New Ticket Form state
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _screenshotController = TextEditingController();
  late String _ticketCategory;
  bool _isSubmitting = false;

  // My Tickets state
  List<SupportTicket> _myTickets = [];
  bool _isLoadingTickets = true;

  final List<String> _customerCategories = [
    'Joining a Queue',
    'QR Code',
    'Bookings & Queue',
    'Account',
    'Notifications',
    'Payments',
    'Other',
  ];

  final List<String> _ownerCategories = [
    'Queue Management',
    'Salon Profile',
    'Salon QR Code',
    'Business Analytics',
    'Customer Management',
    'Account & Security',
    'Technical Issue',
    'Other',
  ];

  List<String> get _categories =>
      widget.isOwner ? _ownerCategories : _customerCategories;

  List<FaqItem> get _allFaqs =>
      widget.isOwner ? FaqData.ownerFaqs : FaqData.customerFaqs;

  List<FaqItem> get _filteredFaqs {
    return _allFaqs.where((faq) {
      final matchesCategory =
          _selectedCategory == 'All' || faq.category == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          faq.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq.answer.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _ticketCategory = _categories.first;
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadMyTickets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    _screenshotController.dispose();
    super.dispose();
  }

  Future<void> _loadMyTickets() async {
    setState(() => _isLoadingTickets = true);
    final auth = AuthScope.of(context, listen: false);
    final userId = auth.currentUser?.id ?? 'guest-user';

    final tickets = await _supportRepo.fetchUserTickets(userId);
    if (!mounted) return;
    setState(() {
      _myTickets = tickets;
      _isLoadingTickets = false;
    });
  }

  Future<void> _handleSubmitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final auth = AuthScope.of(context, listen: false);
    final userId = auth.currentUser?.id ?? 'user-${DateTime.now().millisecondsSinceEpoch}';
    final userRole = widget.isOwner ? 'salon_owner' : 'customer';

    try {
      final newTicket = await _supportRepo.createTicket(
        userId: userId,
        userRole: userRole,
        category: _ticketCategory,
        subject: _subjectController.text.trim(),
        description: _descriptionController.text.trim(),
        screenshotUrl: _screenshotController.text.trim().isNotEmpty
            ? _screenshotController.text.trim()
            : null,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _myTickets.insert(0, newTicket);
        _subjectController.clear();
        _descriptionController.clear();
        _screenshotController.clear();
      });

      // Show success dialog
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit ticket: $e')),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColorSchemes.available, size: 28),
            SizedBox(width: 10),
            Text(
              'Request Submitted',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Your request has been submitted. Our support team will review it.',
          style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _tabController.animateTo(2); // Switch to "My Requests" tab
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColorSchemes.navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('View My Requests', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColorSchemes.ivory,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          widget.isOwner ? 'Owner Help & Support' : 'Help & Support',
          style: const TextStyle(
            color: AppColorSchemes.charcoal,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColorSchemes.navy),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColorSchemes.navy,
          unselectedLabelColor: Colors.grey.shade500,
          indicatorColor: AppColorSchemes.gold,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: const [
            Tab(text: 'Help Center'),
            Tab(text: 'Report Issue'),
            Tab(text: 'My Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: FAQs & Knowledge Base
          _buildFaqTab(),

          // Tab 1: Report a Problem
          _buildReportIssueTab(),

          // Tab 2: My Support Requests
          _buildMyRequestsTab(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── TAB 0: HELP CENTER & FAQS ─────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFaqTab() {
    final faqs = _filteredFaqs;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search Field ──────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search for help (e.g. queue, QR code, turn)...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColorSchemes.navy),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Category Filter Pills ─────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryPill('All'),
                ..._categories.map((c) => _buildCategoryPill(c)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── FAQ Results Header ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedCategory == 'All'
                    ? 'Frequently Asked Questions'
                    : '$_selectedCategory Questions',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColorSchemes.charcoal,
                ),
              ),
              Text(
                '${faqs.length} articles',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Expandable FAQ List ───────────────────────────────────────────
          if (faqs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'No help articles found',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try another keyword or submit a support request below.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...faqs.map((faq) => _buildFaqCard(faq)),

          const SizedBox(height: 24),

          // ── Prominent "Still Need Help?" Support Card ─────────────────────
          _buildStillNeedHelpCard(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(String category) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColorSchemes.navy : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColorSchemes.navy : Colors.grey.shade200,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColorSchemes.navy.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          category,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColorSchemes.charcoal,
          ),
        ),
      ),
    );
  }

  Widget _buildFaqCard(FaqItem faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColorSchemes.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(faq.icon, color: AppColorSchemes.navy, size: 18),
          ),
          title: Text(
            faq.question,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppColorSchemes.charcoal,
            ),
          ),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 10),
            Text(
              faq.answer,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStillNeedHelpCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColorSchemes.navy, AppColorSchemes.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColorSchemes.navy.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent_rounded, color: AppColorSchemes.gold, size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Still need help?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Our support team is here to help.',
                    style: TextStyle(
                      color: AppColorSchemes.goldLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(1),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Submit Ticket', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColorSchemes.gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Support Email: support@salonqueue.app'),
                        backgroundColor: AppColorSchemes.navy,
                      ),
                    );
                  },
                  icon: const Icon(Icons.email_outlined, size: 18, color: Colors.white),
                  label: const Text('Email Us', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── TAB 1: REPORT A PROBLEM (SUBMIT TICKET) ───────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildReportIssueTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Report a Problem / Support Request',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColorSchemes.charcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Provide details about the issue you are experiencing and our technical team will resolve it promptly.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _ticketCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      prefixIcon: Icon(Icons.category_outlined, color: AppColorSchemes.navy),
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _ticketCategory = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Subject
                  TextFormField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject / Issue Title *',
                      hintText: 'e.g. QR scanner not recognizing code',
                      prefixIcon: Icon(Icons.title_rounded, color: AppColorSchemes.navy),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Please enter a subject' : null,
                  ),
                  const SizedBox(height: 14),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description *',
                      hintText: 'Describe the steps or error you encountered...',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 50),
                        child: Icon(Icons.notes_rounded, color: AppColorSchemes.navy),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().length < 5)
                        ? 'Please describe the issue in detail'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  // Optional Screenshot / Link
                  TextFormField(
                    controller: _screenshotController,
                    decoration: const InputDecoration(
                      labelText: 'Screenshot / Image Link (Optional)',
                      hintText: 'https://...',
                      prefixIcon: Icon(Icons.attach_file_rounded, color: AppColorSchemes.navy),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _handleSubmitTicket,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: const Text(
                        'Submit Support Request',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColorSchemes.navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── TAB 2: MY SUPPORT REQUESTS ────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMyRequestsTab() {
    if (_isLoadingTickets) {
      return const Center(child: CircularProgressIndicator(color: AppColorSchemes.gold));
    }

    return RefreshIndicator(
      color: AppColorSchemes.navy,
      onRefresh: _loadMyTickets,
      child: _myTickets.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 14),
                    const Text(
                      'No Support Requests Yet',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Any issue you report will appear here with live resolution status.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _tabController.animateTo(1),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Submit a Request'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColorSchemes.navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _myTickets.length,
              itemBuilder: (context, idx) {
                final ticket = _myTickets[idx];
                return _buildTicketCard(ticket);
              },
            ),
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColorSchemes.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ticket.formattedTicketId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: AppColorSchemes.navy,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ticket.status.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ticket.status.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(ticket.status.icon, color: ticket.status.color, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      ticket.status.label,
                      style: TextStyle(
                        color: ticket.status.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ticket.subject,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColorSchemes.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ticket.description,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.grey.shade700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Category: ${ticket.category}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
              Text(
                _formatDate(ticket.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          if (ticket.adminResponse != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.support_agent_rounded, color: AppColorSchemes.available, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Support Response: ${ticket.adminResponse}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]}, $hour:$min $period';
  }
}
