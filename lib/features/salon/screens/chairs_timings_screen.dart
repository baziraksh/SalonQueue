import 'package:flutter/material.dart';
import '../../../core/theme/color_schemes.dart';
import '../../../shared/models/salon.dart';
import '../../auth/services/auth_scope.dart';
import '../data/salon_repository.dart';

/// Screen allowing Salon Owner to manage Active Chairs/Barbers and Opening/Closing Hours.
class ChairsTimingsScreen extends StatefulWidget {
  const ChairsTimingsScreen({super.key, required this.salon});

  final Salon salon;

  @override
  State<ChairsTimingsScreen> createState() => _ChairsTimingsScreenState();
}

class _ChairsTimingsScreenState extends State<ChairsTimingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final SalonRepository _salonRepo = SalonRepository();

  late int _activeChairs;
  late TextEditingController _openTimeController;
  late TextEditingController _closeTimeController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _activeChairs = widget.salon.activeChairs > 0
        ? widget.salon.activeChairs
        : 3;
    _openTimeController = TextEditingController(text: widget.salon.openingTime);
    _closeTimeController = TextEditingController(
      text: widget.salon.closingTime,
    );
  }

  @override
  void dispose() {
    _openTimeController.dispose();
    _closeTimeController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final auth = AuthScope.of(context, listen: false);
      final effectiveOwnerId =
          (widget.salon.ownerId != null && widget.salon.ownerId!.isNotEmpty)
          ? widget.salon.ownerId
          : auth.currentUser?.id;

      await _salonRepo.updateChairsTimings(
        salonId: widget.salon.id,
        ownerId: effectiveOwnerId,
        activeChairs: _activeChairs,
        openingTime: _openTimeController.text.trim(),
        closingTime: _closeTimeController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chairs and timings saved successfully!'),
          backgroundColor: AppColorSchemes.available,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save settings: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColorSchemes.ivory,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Chairs & Timings',
          style: TextStyle(
            color: AppColorSchemes.charcoal,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColorSchemes.navy),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColorSchemes.navy.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            color: AppColorSchemes.navy,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Capacity & Operating Hours',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColorSchemes.charcoal,
                                ),
                              ),
                              Text(
                                'Manage concurrent barbers and store schedule',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Active Chairs Dropdown
                    DropdownButtonFormField<int>(
                      initialValue: _activeChairs,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Active Chairs / Stylists *',
                        prefixIcon: Icon(
                          Icons.event_seat_rounded,
                          color: AppColorSchemes.navy,
                        ),
                      ),
                      items: List.generate(20, (i) => i + 1)
                          .map(
                            (val) => DropdownMenuItem<int>(
                              value: val,
                              child: Text(
                                '$val ${val == 1 ? "Chair / Barber" : "Chairs / Barbers"} (Serving $val at once)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _activeChairs = v);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Opening & Closing Hours Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _openTimeController,
                            decoration: const InputDecoration(
                              labelText: 'Opening Time',
                              hintText: '08:30 AM',
                              prefixIcon: Icon(
                                Icons.access_time_rounded,
                                color: AppColorSchemes.navy,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _closeTimeController,
                            decoration: const InputDecoration(
                              labelText: 'Closing Time',
                              hintText: '09:30 PM',
                              prefixIcon: Icon(
                                Icons.access_time_filled_rounded,
                                color: AppColorSchemes.navy,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleSave,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 20),
                  label: const Text(
                    'Save Chairs & Timings',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColorSchemes.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
