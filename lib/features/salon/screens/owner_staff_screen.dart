import 'package:flutter/material.dart';
import '../../../shared/models/salon.dart';

/// Staff member data model for salon employee management.
class SalonStaff {
  final String id;
  final String salonId;
  final String name;
  final String role;
  final String? avatarUrl;
  final String? phone;
  final bool isActive;
  final int? assignedChair;

  const SalonStaff({
    required this.id,
    required this.salonId,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.phone,
    this.isActive = true,
    this.assignedChair,
  });

  SalonStaff copyWith({
    String? id,
    String? salonId,
    String? name,
    String? role,
    String? avatarUrl,
    String? phone,
    bool? isActive,
    int? assignedChair,
  }) {
    return SalonStaff(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      name: name ?? this.name,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      assignedChair: assignedChair ?? this.assignedChair,
    );
  }
}

/// Screen allowing salon owners to view, add, edit, and manage their staff members.
/// Designed to closely match the reference salon-management dashboard design system.
class OwnerStaffScreen extends StatefulWidget {
  const OwnerStaffScreen({super.key, required this.salon});

  final Salon salon;

  @override
  State<OwnerStaffScreen> createState() => _OwnerStaffScreenState();
}

class _OwnerStaffScreenState extends State<OwnerStaffScreen> {
  static final Map<String, List<SalonStaff>> _salonStaffStore = {};

  late List<SalonStaff> _staffList;

  final List<String> _staffRoles = [
    'Senior Stylist',
    'Hair Specialist',
    'Barber',
    'Beautician',
    'Spa Therapist',
    'Makeup Artist',
    'Assistant',
  ];

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  void _loadStaff() {
    final existing = _salonStaffStore[widget.salon.id];
    if (existing != null && existing.isNotEmpty) {
      _staffList = List.from(existing);
    } else {
      // Default initial team members matching the design reference
      _staffList = [
        SalonStaff(
          id: 'staff-1',
          salonId: widget.salon.id,
          name: 'Rohit Sharma',
          role: 'Senior Stylist',
          avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
          phone: '+91 98111 22334',
        ),
        SalonStaff(
          id: 'staff-2',
          salonId: widget.salon.id,
          name: 'Neha Gupta',
          role: 'Hair Specialist',
          avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
          phone: '+91 98222 33445',
        ),
        SalonStaff(
          id: 'staff-3',
          salonId: widget.salon.id,
          name: 'Aman Verma',
          role: 'Barber',
          avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
          phone: '+91 98333 44556',
        ),
        SalonStaff(
          id: 'staff-4',
          salonId: widget.salon.id,
          name: 'Pooja Singh',
          role: 'Beautician',
          avatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150',
          phone: '+91 98444 55667',
        ),
        SalonStaff(
          id: 'staff-5',
          salonId: widget.salon.id,
          name: 'Salman Khan',
          role: 'Spa Therapist',
          avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150',
          phone: '+91 98555 66778',
        ),
      ];
      _salonStaffStore[widget.salon.id] = List.from(_staffList);
    }
  }

  void _saveStaff() {
    _salonStaffStore[widget.salon.id] = List.from(_staffList);
  }

  void _showAddEditStaffSheet({SalonStaff? staffToEdit}) {
    final isEditing = staffToEdit != null;
    final nameCtrl = TextEditingController(text: staffToEdit?.name ?? '');
    final phoneCtrl = TextEditingController(text: staffToEdit?.phone ?? '');
    String selectedRole = staffToEdit?.role ?? _staffRoles.first;

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
                      isEditing ? 'Edit Staff Member' : 'Add New Staff',
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
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Full Name *',
                    labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                    hintText: 'e.g. Rahul Sharma',
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
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Role / Designation',
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
                  items: _staffRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                    hintText: '+91 98765 43210',
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
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      setState(() {
                        if (isEditing) {
                          final idx = _staffList.indexWhere((s) => s.id == staffToEdit.id);
                          if (idx != -1) {
                            _staffList[idx] = staffToEdit.copyWith(
                              name: name,
                              role: selectedRole,
                              phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                            );
                          }
                        } else {
                          _staffList.add(
                            SalonStaff(
                              id: 'staff-${DateTime.now().millisecondsSinceEpoch}',
                              salonId: widget.salon.id,
                              name: name,
                              role: selectedRole,
                              phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                            ),
                          );
                        }
                        _saveStaff();
                      });
                      Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D28D9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isEditing ? 'Save Changes' : 'Add Staff Member',
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

  void _deleteStaff(SalonStaff staff) {
    setState(() {
      _staffList.removeWhere((s) => s.id == staff.id);
      _saveStaff();
    });
  }

  @override
  Widget build(BuildContext context) {
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
          'Staff',
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
            onPressed: () => _showAddEditStaffSheet(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _staffList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No Staff Added Yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap + to add stylists and specialists to your salon team.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: _staffList.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final staff = _staffList[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Staff Avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF3E8FF),
                          image: staff.avatarUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(staff.avatarUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: staff.avatarUrl == null
                            ? Center(
                                child: Text(
                                  staff.name.isNotEmpty ? staff.name[0].toUpperCase() : 'S',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: Color(0xFF6D28D9),
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),

                      // Staff Name & Role
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              staff.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              staff.role,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 3-dots Action Menu
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade600, size: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        onSelected: (val) {
                          if (val == 'edit') {
                            _showAddEditStaffSheet(staffToEdit: staff);
                          } else if (val == 'delete') {
                            _deleteStaff(staff);
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
                                Text('Remove', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
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
    );
  }
}
