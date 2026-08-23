import 'package:flutter/material.dart';
import '../../../shared/models/salon.dart';
import '../../../shared/models/salon_service.dart';
import '../../queue/data/queue_repository.dart';

/// Dedicated Add Walk-in customer screen for salon owners.
/// Connects to real queue logic and matches the reference design system.
class OwnerAddWalkInScreen extends StatefulWidget {
  const OwnerAddWalkInScreen({
    super.key,
    required this.salon,
    required this.waitingCount,
    this.onAdded,
  });

  final Salon salon;
  final int waitingCount;
  final VoidCallback? onAdded;

  @override
  State<OwnerAddWalkInScreen> createState() => _OwnerAddWalkInScreenState();
}

class _OwnerAddWalkInScreenState extends State<OwnerAddWalkInScreen> {
  final QueueRepository _queueRepo = QueueRepository();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  SalonService? _selectedService;
  String? _selectedEmployee;
  bool _isSubmitting = false;

  final List<String> _staffOptions = [
    'Rohit Sharma (Senior Stylist)',
    'Neha Gupta (Hair Specialist)',
    'Aman Verma (Barber)',
    'Kavita Devi (Beautician)',
    'Pooja Nair (Spa Therapist)',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.salon.services.isNotEmpty) {
      _selectedService = widget.salon.services.first;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleAddToQueue() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter customer name')),
      );
      return;
    }

    if (_selectedService == null && widget.salon.services.isNotEmpty) {
      _selectedService = widget.salon.services.first;
    }

    setState(() => _isSubmitting = true);

    try {
      final servicesToBook = _selectedService != null
          ? [_selectedService!]
          : [
              SalonService(
                id: 'svc-walkin',
                salonId: widget.salon.id,
                name: 'Regular Haircut',
                category: 'Hair',
                price: 299,
                durationMinutes: 25,
              ),
            ];

      String? notes = _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null;
      if (_selectedEmployee != null) {
        notes = notes != null ? 'Staff: $_selectedEmployee | $notes' : 'Staff: $_selectedEmployee';
      }

      await _queueRepo.joinQueue(
        salonId: widget.salon.id,
        customerId: null,
        customerName: name,
        customerPhone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
        selectedServices: servicesToBook,
        notes: notes,
      );

      widget.onAdded?.call();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Walk-in token added for $name!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add token: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final estMinutes = (widget.waitingCount * 15) + 15;
    final waitText = widget.waitingCount > 0 ? '$estMinutes - ${estMinutes + 10} min' : '5 - 10 min';

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
          'Add Walk-in',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Customer Details Header ─────────────────────────────────
            const Text(
              'Customer Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 14),

            // ── 2. Form Card ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name Field
                  _buildFieldLabel('Name'),
                  TextField(
                    controller: _nameCtrl,
                    decoration: _buildInputDecoration('Enter name'),
                  ),
                  const SizedBox(height: 14),

                  // Mobile Number Field
                  _buildFieldLabel('Mobile Number'),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _buildInputDecoration('Enter mobile number'),
                  ),
                  const SizedBox(height: 14),

                  // Service Selector
                  _buildFieldLabel('Service'),
                  DropdownButtonFormField<SalonService>(
                    initialValue: _selectedService,
                    decoration: _buildInputDecoration('Select service'),
                    items: widget.salon.services.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text('${s.name} (₹${s.price.toStringAsFixed(0)})'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedService = val),
                  ),
                  const SizedBox(height: 14),

                  // Employee Selector (Optional)
                  _buildFieldLabel('Employee (Optional)'),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedEmployee,
                    decoration: _buildInputDecoration('Select employee'),
                    items: _staffOptions.map((e) {
                      return DropdownMenuItem(value: e, child: Text(e));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedEmployee = val),
                  ),
                  const SizedBox(height: 14),

                  // Notes Field (Optional)
                  _buildFieldLabel('Notes (Optional)'),
                  TextField(
                    controller: _notesCtrl,
                    decoration: _buildInputDecoration('Add notes'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── 3. Add to Queue Button ─────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleAddToQueue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D28D9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Add to Queue',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // ── 4. Estimated Wait Time Card ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estimated Wait Time',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        waitText,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                          letterSpacing: -0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${widget.waitingCount} people ahead',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6D28D9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── 5. Illustration Graphic ────────────────────────────────────
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_alt_rounded, color: Color(0xFF6D28D9), size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Live Queue updates instantly for waiting customers',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13.5),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
    );
  }
}
