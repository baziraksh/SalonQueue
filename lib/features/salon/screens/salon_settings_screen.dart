import 'package:flutter/material.dart';
import '../../../core/theme/color_schemes.dart';
import '../../../shared/data/india_locations.dart';
import '../../../shared/models/salon.dart';
import '../../support/screens/support_center_screen.dart';
import '../data/salon_repository.dart';

/// Screen allowing Salon Owner to manage salon profile, operating hours, and location (State/District/City).
/// Fully responsive with zero RenderFlex overflow and styled in luxury Navy & Gold theme.
class SalonSettingsScreen extends StatefulWidget {
  const SalonSettingsScreen({super.key, required this.salon});

  final Salon salon;

  @override
  State<SalonSettingsScreen> createState() => _SalonSettingsScreenState();
}

class _SalonSettingsScreenState extends State<SalonSettingsScreen> {
  final SalonRepository _salonRepo = SalonRepository();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _districtController;
  late TextEditingController _pincodeController;
  late TextEditingController _phoneController;
  late TextEditingController _chairsController;
  late TextEditingController _openTimeController;
  late TextEditingController _closeTimeController;

  late String _selectedState;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedState = widget.salon.state.isNotEmpty ? widget.salon.state : 'Maharashtra';
    _nameController = TextEditingController(text: widget.salon.name);
    _descController = TextEditingController(text: widget.salon.description);
    _addressController = TextEditingController(text: widget.salon.address);
    _cityController = TextEditingController(text: widget.salon.city);
    _districtController = TextEditingController(
      text: widget.salon.district.isNotEmpty ? widget.salon.district : widget.salon.city,
    );
    _pincodeController = TextEditingController(text: widget.salon.pincode ?? '');
    _phoneController = TextEditingController(text: widget.salon.phone ?? '');
    _chairsController = TextEditingController(text: widget.salon.activeChairs.toString());
    _openTimeController = TextEditingController(text: widget.salon.openingTime);
    _closeTimeController = TextEditingController(text: widget.salon.closingTime);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _chairsController.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final auth = AuthScope.of(context, listen: false);
    final effectiveOwnerId = (widget.salon.ownerId != null && widget.salon.ownerId!.isNotEmpty)
        ? widget.salon.ownerId
        : auth.currentUser?.id;

    await _salonRepo.updateSalonDetails(
      salonId: widget.salon.id,
      ownerId: effectiveOwnerId,
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      district: _districtController.text.trim(),
      state: _selectedState,
      pincode: _pincodeController.text.trim(),
      phone: _phoneController.text.trim(),
      activeChairs: int.tryParse(_chairsController.text.trim()) ?? 3,
      openingTime: _openTimeController.text.trim(),
      closingTime: _closeTimeController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Salon details & location updated successfully!'),
        backgroundColor: AppColorSchemes.available,
      ),
    );

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final allStates = IndiaLocations.getAllStates();

    return Scaffold(
      backgroundColor: AppColorSchemes.ivory,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Salon Profile & Location',
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
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Section 1: Store Information ─────────────────────────
                _buildSectionHeader(
                  icon: Icons.storefront_rounded,
                  title: 'Store Information',
                  subtitle: 'Basic details visible to customers on Salon Queue',
                ),
                const SizedBox(height: 12),
                _buildCardContainer(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Salon Name *',
                        hintText: 'e.g. Royal Cuts Unisex Salon',
                        prefixIcon: Icon(Icons.storefront, color: AppColorSchemes.navy),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Enter salon name' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Short Description',
                        hintText: 'e.g. Modern haircuts, beard spas & facials',
                        prefixIcon: Icon(Icons.description_outlined, color: AppColorSchemes.navy),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact Phone Number',
                        hintText: '+91 98765 43210',
                        prefixIcon: Icon(Icons.phone_outlined, color: AppColorSchemes.navy),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Section 2: Store Location (Pan-India) ─────────────────
                _buildSectionHeader(
                  icon: Icons.location_on_rounded,
                  title: 'Store Location (Pan-India 🇮🇳)',
                  subtitle: 'Helps nearby customers discover your salon in their city',
                ),
                const SizedBox(height: 12),
                _buildCardContainer(
                  children: [
                    // State Dropdown — Fully responsive & safe against narrow screens
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue:
                          allStates.contains(_selectedState) ? _selectedState : allStates.first,
                      decoration: const InputDecoration(
                        labelText: 'State *',
                        prefixIcon: Icon(Icons.map_outlined, color: AppColorSchemes.navy),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      items: allStates.map((st) {
                        return DropdownMenuItem<String>(
                          value: st,
                          child: Text(
                            st,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColorSchemes.charcoal,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedState = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // District & City Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _districtController,
                            decoration: const InputDecoration(
                              labelText: 'District *',
                              hintText: 'e.g. Pune',
                              prefixIcon:
                                  Icon(Icons.location_city_outlined, color: AppColorSchemes.navy),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Enter district' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'City / Town *',
                              hintText: 'e.g. Pune',
                              prefixIcon:
                                  Icon(Icons.apartment_outlined, color: AppColorSchemes.navy),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Enter city' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Street Address & Pincode Row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Street Address *',
                              hintText: 'e.g. FC Road, Lane 4',
                              prefixIcon: Icon(Icons.pin_drop_outlined, color: AppColorSchemes.navy),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Enter street address' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _pincodeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'PIN Code',
                              hintText: '411004',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Section 3: Chairs & Operating Timings ────────────────
                _buildSectionHeader(
                  icon: Icons.schedule_rounded,
                  title: 'Chairs & Timings',
                  subtitle: 'Live queue capacity and opening/closing hours',
                ),
                const SizedBox(height: 12),
                _buildCardContainer(
                  children: [
                    TextFormField(
                      controller: _chairsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Active Chairs / Barbers *',
                        hintText: 'e.g. 3',
                        prefixIcon: Icon(Icons.chair_alt_rounded, color: AppColorSchemes.navy),
                      ),
                      validator: (v) => (v == null || int.tryParse(v.trim()) == null)
                          ? 'Enter valid chair count'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _openTimeController,
                            decoration: const InputDecoration(
                              labelText: 'Opening Time',
                              hintText: '09:00 AM',
                              prefixIcon:
                                  Icon(Icons.access_time_rounded, color: AppColorSchemes.navy),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _closeTimeController,
                            decoration: const InputDecoration(
                              labelText: 'Closing Time',
                              hintText: '10:00 PM',
                              prefixIcon:
                                  Icon(Icons.access_time_filled_rounded, color: AppColorSchemes.navy),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Section 4: Owner Help & Support ───────────────────────
                _buildSectionHeader(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support Center',
                  subtitle: 'Owner guide, FAQs, and submit support requests',
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColorSchemes.navy.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.support_agent_rounded, color: AppColorSchemes.navy),
                    ),
                    title: const Text(
                      'Open Owner Help Center',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Queue management FAQs & report issues',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SupportCenterScreen(isOwner: true),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 28),

                // ── Save Button ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColorSchemes.navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save_rounded, color: AppColorSchemes.gold, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Save Store Changes',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColorSchemes.navy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColorSchemes.navy),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColorSchemes.charcoal,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
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
        children: children,
      ),
    );
  }
}
