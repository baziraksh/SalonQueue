import 'package:flutter/material.dart';
import '../../../shared/models/salon.dart';
import '../../../shared/models/salon_service.dart';
import '../data/salon_repository.dart';

/// Screen allowing Salon Owners to add, edit prices, durations, and manage their salon's service menu.
/// Redesigned to match the reference salon-management dashboard design system.
class ManageServicesScreen extends StatefulWidget {
  const ManageServicesScreen({super.key, required this.salon});

  final Salon salon;

  @override
  State<ManageServicesScreen> createState() => _ManageServicesScreenState();
}

class _ManageServicesScreenState extends State<ManageServicesScreen> {
  final SalonRepository _salonRepo = SalonRepository();
  late List<SalonService> _services;
  bool _isLoading = false;
  String _selectedCategory = 'All';

  final List<String> _categoryTabs = [
    'All',
    'Hair',
    'Beauty',
    'Spa',
    'Other',
  ];

  final List<String> _availableCategories = [
    'Hair',
    'Beard',
    'Facial',
    'Spa',
    'Beauty',
    'Color',
    'Combo',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _services = List.from(widget.salon.services);
    _refreshServices();
  }

  Future<void> _refreshServices() async {
    setState(() => _isLoading = true);
    try {
      final freshServices = await _salonRepo.fetchServices(widget.salon.id);
      if (!mounted) return;
      setState(() {
        _services = freshServices;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load services: $e')));
    }
  }

  List<SalonService> get _filteredServices {
    if (_selectedCategory == 'All') return _services;
    if (_selectedCategory == 'Hair') {
      return _services.where((s) {
        final cat = s.category.toLowerCase();
        return cat.contains('hair') || cat.contains('beard') || cat.contains('cut');
      }).toList();
    }
    if (_selectedCategory == 'Beauty') {
      return _services.where((s) {
        final cat = s.category.toLowerCase();
        return cat.contains('beauty') || cat.contains('facial') || cat.contains('makeup');
      }).toList();
    }
    if (_selectedCategory == 'Spa') {
      return _services.where((s) {
        final cat = s.category.toLowerCase();
        return cat.contains('spa') || cat.contains('massage') || cat.contains('therapy');
      }).toList();
    }
    return _services.where((s) {
      final cat = s.category.toLowerCase();
      return !cat.contains('hair') && !cat.contains('beard') && !cat.contains('facial') && !cat.contains('spa');
    }).toList();
  }

  void _showAddEditServiceDialog({SalonService? serviceToEdit}) {
    final isEditing = serviceToEdit != null;
    final nameCtrl = TextEditingController(text: serviceToEdit?.name ?? '');
    final priceCtrl = TextEditingController(
      text: serviceToEdit != null ? serviceToEdit.price.toStringAsFixed(0) : '',
    );
    final durationCtrl = TextEditingController(
      text: serviceToEdit != null
          ? serviceToEdit.durationMinutes.toString()
          : '20',
    );
    String selectedCategory = serviceToEdit?.category ?? 'Hair';
    bool isActive = serviceToEdit?.isActive ?? true;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Service' : 'Add New Service',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Name
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Service Name *',
                    labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                    hintText: 'e.g. Classic Haircut, Gold Facial',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Category & Price in 1 Row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
                          ),
                        ),
                        items: _availableCategories
                            .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedCategory = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Price (₹) *',
                          labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                          prefixText: '₹ ',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Duration
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Duration (Minutes) *',
                    labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                    hintText: '25',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Active Switch
                SwitchListTile.adaptive(
                  title: const Text(
                    'Available for booking',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111827)),
                  ),
                  value: isActive,
                  activeThumbColor: const Color(0xFF6D28D9),
                  onChanged: (val) => setModalState(() => isActive = val),
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 16),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                            final duration = int.tryParse(durationCtrl.text.trim()) ?? 20;

                            if (name.isEmpty || price <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter valid name and price.'),
                                ),
                              );
                              return;
                            }

                            setModalState(() => isSaving = true);

                            try {
                              if (isEditing) {
                                await _salonRepo.updateService(
                                  serviceId: serviceToEdit.id,
                                  name: name,
                                  category: selectedCategory,
                                  price: price,
                                  durationMinutes: duration,
                                  isActive: isActive,
                                  salonId: widget.salon.id,
                                );
                                if (!context.mounted) return;
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Service updated successfully!'),
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                );
                              } else {
                                await _salonRepo.addService(
                                  salonId: widget.salon.id,
                                  name: name,
                                  category: selectedCategory,
                                  price: price,
                                  durationMinutes: duration,
                                  isActive: isActive,
                                );
                                if (!context.mounted) return;
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Service added to menu!'),
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                );
                              }

                              await _refreshServices();
                            } catch (e) {
                              setModalState(() => isSaving = false);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to save service: $e'),
                                  backgroundColor: const Color(0xFFEF4444),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D28D9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            isEditing ? 'Save Changes' : 'Add to Menu',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleToggleServiceStatus(SalonService service, bool newActive) async {
    // Optimistic UI update
    setState(() {
      final idx = _services.indexWhere((s) => s.id == service.id);
      if (idx != -1) {
        _services[idx] = service.copyWith(isActive: newActive);
      }
    });

    try {
      await _salonRepo.updateService(
        serviceId: service.id,
        name: service.name,
        category: service.category,
        price: service.price,
        durationMinutes: service.durationMinutes,
        isActive: newActive,
        salonId: widget.salon.id,
      );
    } catch (e) {
      await _refreshServices();
    }
  }

  Future<void> _handleDeleteService(SalonService service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Delete Service?',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827)),
        ),
        content: Text(
          'Are you sure you want to remove "${service.name}" from your service rate card?',
          style: const TextStyle(color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _salonRepo.deleteService(service.id, salonId: widget.salon.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${service.name}" deleted.'),
            backgroundColor: Colors.black87,
          ),
        );
        await _refreshServices();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete service: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredServices;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 18),
            onPressed: () => Navigator.of(context).pop(true),
          ),
          title: const Text(
            'Services',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded, color: Color(0xFF6D28D9), size: 28),
              tooltip: 'Add Service',
              onPressed: () => _showAddEditServiceDialog(),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // ── 1. Category Filter Tabs (Matching Reference) ─────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categoryTabs.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : const Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // ── 2. Service List ──────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6D28D9)))
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.content_cut_rounded, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 14),
                              const Text(
                                'No services found',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap + to add services to this category.',
                                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, idx) {
                            final svc = filtered[idx];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                              child: Row(
                                children: [
                                  // Rounded Icon / Avatar
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3E8FF),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.content_cut_rounded,
                                      color: Color(0xFF6D28D9),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Name & Duration
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _showAddEditServiceDialog(serviceToEdit: svc),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            svc.name,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF111827),
                                              letterSpacing: -0.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${svc.durationMinutes} min',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Price
                                  Text(
                                    '₹${svc.price.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Active Toggle Switch (Matching Reference)
                                  Switch.adaptive(
                                    value: svc.isActive,
                                    activeThumbColor: const Color(0xFF6D28D9),
                                    activeTrackColor: const Color(0xFFDDD6FE),
                                    onChanged: (val) => _handleToggleServiceStatus(svc, val),
                                  ),

                                  // Delete / Edit Popup Menu
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade500, size: 18),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    onSelected: (val) {
                                      if (val == 'edit') {
                                        _showAddEditServiceDialog(serviceToEdit: svc);
                                      } else if (val == 'delete') {
                                        _handleDeleteService(svc);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6D28D9)),
                                            SizedBox(width: 10),
                                            Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                            SizedBox(width: 10),
                                            Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

