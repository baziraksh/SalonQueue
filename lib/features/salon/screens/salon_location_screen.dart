import 'package:flutter/material.dart';
import '../../../core/theme/color_schemes.dart';
import '../../../shared/data/india_locations.dart';
import '../../../shared/models/salon.dart';
import '../../auth/services/auth_scope.dart';
import '../../customer/services/location_suggestion_service.dart';
import '../data/salon_repository.dart';

/// Screen allowing Salon Owner to manage Salon Location (State, District, City, Address, PIN Code).
class SalonLocationScreen extends StatefulWidget {
  const SalonLocationScreen({super.key, required this.salon});

  final Salon salon;

  @override
  State<SalonLocationScreen> createState() => _SalonLocationScreenState();
}

class _SalonLocationScreenState extends State<SalonLocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final SalonRepository _salonRepo = SalonRepository();

  late String _selectedState;
  late String _selectedDistrict;
  late TextEditingController _cityController;
  late TextEditingController _addressController;
  late TextEditingController _pincodeController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedState = widget.salon.state.isNotEmpty ? widget.salon.state : 'Maharashtra';
    final districts = IndiaLocations.getDistrictsForState(_selectedState);
    _selectedDistrict = districts.contains(widget.salon.district)
        ? widget.salon.district
        : (districts.isNotEmpty ? districts.first : '');

    _cityController = TextEditingController(text: widget.salon.city);
    _addressController = TextEditingController(text: widget.salon.address);
    _pincodeController = TextEditingController(text: widget.salon.pincode ?? '');
  }

  @override
  void dispose() {
    _cityController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final auth = AuthScope.of(context, listen: false);
      final effectiveOwnerId = (widget.salon.ownerId != null && widget.salon.ownerId!.isNotEmpty)
          ? widget.salon.ownerId
          : auth.currentUser?.id;

      final city = _cityController.text.trim();
      final address = _addressController.text.trim();
      final pincode = _pincodeController.text.trim().isNotEmpty
          ? _pincodeController.text.trim()
          : null;

      // Automatically geocode the address to store precise latitude & longitude
      final coords = await LocationSuggestionService.geocodeAddress(
        address: address,
        city: city,
        district: _selectedDistrict,
        state: _selectedState,
        pincode: pincode,
      );

      await _salonRepo.updateSalonLocation(
        salonId: widget.salon.id,
        ownerId: effectiveOwnerId,
        state: _selectedState,
        district: _selectedDistrict,
        city: city,
        address: address,
        pincode: pincode,
        latitude: coords['latitude'],
        longitude: coords['longitude'],
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Salon location updated successfully!'),
          backgroundColor: AppColorSchemes.available,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update location: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final districtList = IndiaLocations.getDistrictsForState(_selectedState);

    return Scaffold(
      backgroundColor: AppColorSchemes.ivory,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Salon Location',
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
                          child: const Icon(Icons.location_on_rounded, color: AppColorSchemes.navy, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Address & Region',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColorSchemes.charcoal,
                                ),
                              ),
                              Text(
                                'State, district, city/village, area & PIN code',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // State Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedState,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'State *',
                        prefixIcon: Icon(Icons.map_outlined, color: AppColorSchemes.navy),
                      ),
                      items: IndiaLocations.getAllStates().map((state) {
                        return DropdownMenuItem<String>(
                          value: state,
                          child: Text(state, overflow: TextOverflow.ellipsis, maxLines: 1),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != _selectedState) {
                          setState(() {
                            _selectedState = val;
                            final newDistricts = IndiaLocations.getDistrictsForState(val);
                            _selectedDistrict = newDistricts.isNotEmpty ? newDistricts.first : '';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // District & City/Village Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: districtList.contains(_selectedDistrict)
                                ? _selectedDistrict
                                : (districtList.isNotEmpty ? districtList.first : null),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'District *',
                              prefixIcon: Icon(Icons.holiday_village_outlined, color: AppColorSchemes.navy),
                            ),
                            items: districtList.map((district) {
                              return DropdownMenuItem<String>(
                                value: district,
                                child: Text(district, overflow: TextOverflow.ellipsis, maxLines: 1),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedDistrict = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'City / Village / Area *',
                              hintText: 'e.g. Banarpal / Angul / Turanga',
                              prefixIcon: Icon(Icons.apartment_outlined, color: AppColorSchemes.navy),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Enter city or village' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Street Address / Village Area
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Street Address & Locality *',
                        hintText: 'e.g. Near Bus Stand, Main Road, Turanga Village',
                        prefixIcon: Icon(Icons.pin_drop_outlined, color: AppColorSchemes.navy),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Enter street or village address' : null,
                    ),
                    const SizedBox(height: 14),

                    // PIN Code
                    TextFormField(
                      controller: _pincodeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'PIN Code',
                        hintText: '759122',
                        prefixIcon: Icon(Icons.local_post_office_outlined, color: AppColorSchemes.navy),
                      ),
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded, size: 20),
                  label: const Text(
                    'Save Salon Location',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColorSchemes.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
