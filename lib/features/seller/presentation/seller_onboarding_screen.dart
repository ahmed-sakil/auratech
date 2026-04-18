import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_routes.dart';

class SellerOnboardingScreen extends StatefulWidget {
  const SellerOnboardingScreen({super.key});

  @override
  State<SellerOnboardingScreen> createState() => _SellerOnboardingScreenState();
}

class _SellerOnboardingScreenState extends State<SellerOnboardingScreen> {
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _nidController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _homeAddressController = TextEditingController();
  final _businessDescriptionController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoading = true;
  bool _alreadySubmitted = false;
  bool _hasPhysicalShop = true;
  bool _agreedToTerms = false;

  DateTime? _dateOfBirth;

  String _savedShopName = '';
  String _savedOwnerName = '';
  String _savedPhone = '';
  String _savedEmail = '';
  String _savedDateOfBirth = '';
  String _savedNidNumber = '';
  bool _savedHasPhysicalShop = true;
  String _savedShopAddress = '';
  String _savedHomeAddress = '';
  String _savedBusinessDescription = '';
  bool _savedAgreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _loadExistingDetails();
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nidController.dispose();
    _shopAddressController.dispose();
    _homeAddressController.dispose();
    _businessDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingDetails() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      context.go(AppRoutes.login);
      return;
    }

    try {
      final profileData = await Supabase.instance.client
          .from('profiles')
          .select('full_name, email')
          .eq('id', user.id)
          .maybeSingle();

      final sellerData = await Supabase.instance.client
          .from('seller_details')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final profileFullName =
          (profileData?['full_name'] as String?)?.trim() ?? '';
      final profileEmail =
          (profileData?['email'] as String?)?.trim() ??
          (user.email ?? '').trim();

      _ownerNameController.text = profileFullName;
      _emailController.text = profileEmail;

      if (sellerData != null) {
        _savedShopName = (sellerData['shop_name'] as String?) ?? '';
        _savedOwnerName =
            ((sellerData['owner_name'] as String?) ?? '').isNotEmpty
                ? (sellerData['owner_name'] as String?) ?? ''
                : profileFullName;
        _savedPhone = (sellerData['phone'] as String?) ?? '';
        _savedEmail =
            ((sellerData['email'] as String?) ?? '').isNotEmpty
                ? (sellerData['email'] as String?) ?? ''
                : profileEmail;
        _savedDateOfBirth = (sellerData['date_of_birth'] as String?) ?? '';
        _savedNidNumber = (sellerData['nid_number'] as String?) ?? '';
        _savedHasPhysicalShop =
            (sellerData['has_physical_shop'] as bool?) ?? true;
        _savedShopAddress = (sellerData['shop_address'] as String?) ?? '';
        _savedHomeAddress = (sellerData['home_address'] as String?) ?? '';
        _savedBusinessDescription =
            (sellerData['business_description'] as String?) ?? '';
        _savedAgreedToTerms =
            (sellerData['agreed_to_terms'] as bool?) ?? false;

        _alreadySubmitted = true;
      }
    } catch (_) {
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initialDate =
        _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: 'Select date of birth',
    );

    if (picked == null) return;

    setState(() {
      _dateOfBirth = picked;
    });
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _displayDate(String value) {
    if (value.isEmpty) return 'Not provided';

    final parts = value.split('-');
    if (parts.length != 3) return value;

    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  String _maskNid(String nid) {
    if (nid.isEmpty) return 'Not provided';
    if (nid.length <= 4) return nid;

    final visible = nid.substring(nid.length - 4);
    return '${'*' * (nid.length - 4)}$visible';
  }

  Future<void> _submit() async {
    final shopName = _shopNameController.text.trim();
    final ownerName = _ownerNameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final nidNumber = _nidController.text.trim();
    final shopAddress = _shopAddressController.text.trim();
    final homeAddress = _homeAddressController.text.trim();
    final businessDescription = _businessDescriptionController.text.trim();
    final dateOfBirth = _dateOfBirth == null ? '' : _formatDate(_dateOfBirth!);

    if (shopName.isEmpty ||
        ownerName.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        dateOfBirth.isEmpty ||
        nidNumber.isEmpty ||
        homeAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Shop name, phone, date of birth, NID, and home address are required',
          ),
        ),
      );
      return;
    }

    if (_hasPhysicalShop && shopAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shop address is required if you have a physical shop'),
        ),
      );
      return;
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must agree to the terms and conditions'),
        ),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      context.go(AppRoutes.login);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await Supabase.instance.client.from('seller_details').upsert({
        'user_id': user.id,
        'shop_name': shopName,
        'owner_name': ownerName,
        'phone': phone,
        'email': email,
        'date_of_birth': dateOfBirth,
        'nid_number': nidNumber,
        'has_physical_shop': _hasPhysicalShop,
        'shop_address': _hasPhysicalShop ? shopAddress : '',
        'home_address': homeAddress,
        'business_description': businessDescription,
        'agreed_to_terms': _agreedToTerms,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      setState(() {
        _savedShopName = shopName;
        _savedOwnerName = ownerName;
        _savedPhone = phone;
        _savedEmail = email;
        _savedDateOfBirth = dateOfBirth;
        _savedNidNumber = nidNumber;
        _savedHasPhysicalShop = _hasPhysicalShop;
        _savedShopAddress = _hasPhysicalShop ? shopAddress : '';
        _savedHomeAddress = homeAddress;
        _savedBusinessDescription = businessDescription;
        _savedAgreedToTerms = _agreedToTerms;
        _alreadySubmitted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller onboarding details saved')),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save seller details')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Widget _infoTile(String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seller Details Submitted',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your seller details have already been submitted. Your account is still pending approval.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        _infoTile('Shop name', _savedShopName),
        const SizedBox(height: 12),
        _infoTile('Owner name', _savedOwnerName),
        const SizedBox(height: 12),
        _infoTile('Phone', _savedPhone),
        const SizedBox(height: 12),
        _infoTile('Email', _savedEmail),
        const SizedBox(height: 12),
        _infoTile('Date of birth', _displayDate(_savedDateOfBirth)),
        const SizedBox(height: 12),
        _infoTile('NID number', _maskNid(_savedNidNumber)),
        const SizedBox(height: 12),
        _infoTile(
          'Physical shop',
          _savedHasPhysicalShop ? 'Yes' : 'No physical shop',
        ),
        const SizedBox(height: 12),
        _infoTile(
          'Shop address',
          _savedHasPhysicalShop
              ? (_savedShopAddress.isEmpty ? 'Not provided' : _savedShopAddress)
              : 'No physical shop',
        ),
        const SizedBox(height: 12),
        _infoTile('Home address', _savedHomeAddress),
        const SizedBox(height: 12),
        _infoTile(
          'Business description',
          _savedBusinessDescription.isEmpty
              ? 'Not provided'
              : _savedBusinessDescription,
        ),
        const SizedBox(height: 12),
        _infoTile(
          'Terms and conditions',
          _savedAgreedToTerms ? 'Agreed' : 'Not agreed',
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => context.go(AppRoutes.sellerPending),
            child: const Text('Back to Pending Status'),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Complete Seller Profile',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Submit your shop and personal details. Your account will remain pending until approved.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _shopNameController,
          decoration: const InputDecoration(
            labelText: 'Shop name',
            hintText: 'Enter your shop name',
          ),
        ),
        const SizedBox(height: 14),
        _buildReadOnlyField(
          controller: _ownerNameController,
          label: 'Owner name',
          hint: 'Auto loaded from profile',
        ),
        const SizedBox(height: 14),
        _buildReadOnlyField(
          controller: _emailController,
          label: 'Email address',
          hint: 'Auto loaded from profile',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: 'Enter your phone number',
          ),
        ),
        const SizedBox(height: 14),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _pickDateOfBirth,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date of birth',
              hintText: 'Select your date of birth',
            ),
            child: Text(
              _dateOfBirth == null
                  ? 'Select your date of birth'
                  : _displayDate(_formatDate(_dateOfBirth!)),
              style: TextStyle(
                color: _dateOfBirth == null
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _nidController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'NID number',
            hintText: 'Enter your NID number',
          ),
        ),
        const SizedBox(height: 14),
        CheckboxListTile(
          value: !_hasPhysicalShop,
          onChanged: (value) {
            setState(() {
              _hasPhysicalShop = !(value ?? false);
              if (!_hasPhysicalShop) {
                _shopAddressController.clear();
              }
            });
          },
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'I do not have a physical shop',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _shopAddressController,
          enabled: _hasPhysicalShop,
          minLines: 2,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Shop address',
            hintText: _hasPhysicalShop
                ? 'Enter your shop address'
                : 'No physical shop selected',
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _homeAddressController,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Owner home address',
            hintText: 'Enter your home address',
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _businessDescriptionController,
          minLines: 4,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Business description',
            hintText: 'Describe your business and what you sell',
          ),
        ),
        const SizedBox(height: 14),
        CheckboxListTile(
          value: _agreedToTerms,
          onChanged: (value) {
            setState(() {
              _agreedToTerms = value ?? false;
            });
          },
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'I agree with all the terms and conditions',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save Details'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Onboarding'),
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.sellerPending),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _alreadySubmitted
                      ? _buildSubmittedView(context)
                      : _buildFormView(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}