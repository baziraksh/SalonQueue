import 'package:flutter/material.dart';
import '../../../core/theme/color_schemes.dart';
import '../../../shared/models/salon.dart';
import '../../../shared/models/salon_service.dart';
import '../data/salon_repository.dart';

/// Screen allowing Salon Owners to add, edit prices, durations, and manage their salon's service menu.
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

  final List<String> _availableCategories = [
    'Hair',
    'Beard',
    'Facial',
    'Spa',
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
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Name
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Service Name *',
                    hintText: 'e.g. Classic Haircut, Gold Facial',
                    prefixIcon: Icon(Icons.content_cut),
                  ),
                ),
                const SizedBox(height: 12),

                // Category & Price in 1 Row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: _availableCategories
                            .map(
                              (cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedCategory = val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price (₹) *',
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Duration
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration (Minutes) *',
                    hintText: '25',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                // Active Switch
                if (isEditing)
                  SwitchListTile(
                    title: const Text('Available for booking'),
                    value: isActive,
                    onChanged: (val) => setModalState(() => isActive = val),
                    contentPadding: EdgeInsets.zero,
                  ),

                const SizedBox(height: 16),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final price =
                                double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                            final duration =
                                int.tryParse(durationCtrl.text.trim()) ?? 20;

                            if (name.isEmpty || price <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter valid name and price.',
                                  ),
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
                                    content: Text(
                                      'Service updated successfully!',
                                    ),
                                    backgroundColor: Color(0xFF2E7D32),
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
                                    backgroundColor: Color(0xFF2E7D32),
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
                                  backgroundColor: const Color(0xFFC62828),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColorSchemes.navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                        : Text(isEditing ? 'Save Changes' : 'Add to Menu'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleDeleteService(SalonService service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Service?'),
        content: Text(
          'Are you sure you want to remove "${service.name}" from your rate card?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            child: const Text('Delete'),
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
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Services & Pricing'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(true),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Service',
              onPressed: () => _showAddEditServiceDialog(),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _services.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.content_cut,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text('No services added yet.'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditServiceDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Your First Service'),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _services.length,
                itemBuilder: (context, idx) {
                  final svc = _services[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColorSchemes.navy.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.content_cut,
                              color: AppColorSchemes.navy,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        svc.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (!svc.isActive) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'Paused',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${svc.category} • ~${svc.durationMinutes} mins',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${svc.price.toStringAsFixed(0)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColorSchemes.navy,
                            ),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
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
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit Price/Name'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: Color(0xFFC62828),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Color(0xFFC62828),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddEditServiceDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add Service'),
          backgroundColor: AppColorSchemes.gold,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
