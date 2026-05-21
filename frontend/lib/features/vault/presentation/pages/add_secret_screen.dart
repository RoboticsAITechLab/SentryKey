import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/encryption_service.dart';
import '../../../../core/services/database_service.dart';
import '../../data/models/secret_entry.dart';
import '../../data/repositories/vault_repository_impl.dart';
import '../../domain/repositories/vault_repository.dart';
import '../../../auth/presentation/widgets/glow_button.dart';
import '../../../auth/presentation/widgets/sentry_text_field.dart';
import '../../presentation/widgets/password_generator_sheet.dart';

class AddSecretScreen extends StatefulWidget {
  final VaultRepository vaultRepository;

  const AddSecretScreen({super.key, required this.vaultRepository});

  @override
  State<AddSecretScreen> createState() => _AddSecretScreenState();
}

class _AddSecretScreenState extends State<AddSecretScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedCategory = 'Password';
  bool _isLoading = false;

  final List<String> _categories = ['Password', 'Bank', 'Card', 'ID Card', 'Secure Note'];

  // Form Controllers
  final Map<String, TextEditingController> _controllers = {};

  // Password strength
  double _passwordStrength = 0.0;
  Color _strengthColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _controllers.clear();
    if (_selectedCategory == 'Password') {
      _controllers['title'] = TextEditingController();
      _controllers['username'] = TextEditingController();
      _controllers['password'] = TextEditingController();
      _controllers['url'] = TextEditingController();
      _controllers['totpSecret'] = TextEditingController();
      _controllers['password']!.addListener(_checkPasswordStrength);
    } else if (_selectedCategory == 'Bank') {
      _controllers['bankName'] = TextEditingController();
      _controllers['accountNumber'] = TextEditingController();
      _controllers['ifsc'] = TextEditingController();
      _controllers['accountHolder'] = TextEditingController();
    } else if (_selectedCategory == 'Card') {
      _controllers['bankName'] = TextEditingController();
      _controllers['cardNumber'] = TextEditingController();
      _controllers['expiryDate'] = TextEditingController();
      _controllers['cvv'] = TextEditingController();
      _controllers['cardHolder'] = TextEditingController();
    } else if (_selectedCategory == 'ID Card') {
      _controllers['idType'] = TextEditingController();
      _controllers['idNumber'] = TextEditingController();
      _controllers['expiryDate'] = TextEditingController();
    } else if (_selectedCategory == 'Secure Note') {
      _controllers['title'] = TextEditingController();
      _controllers['note'] = TextEditingController();
    }
  }

  void _checkPasswordStrength() {
    final pass = _controllers['password']?.text ?? '';
    double strength = 0;
    if (pass.length > 5) strength += 0.2;
    if (pass.length > 10) strength += 0.2;
    if (RegExp(r'[A-Z]').hasMatch(pass)) strength += 0.2;
    if (RegExp(r'[0-9]').hasMatch(pass)) strength += 0.2;
    if (RegExp(r'[!@#\$&*~]').hasMatch(pass)) strength += 0.2;

    setState(() {
      _passwordStrength = strength;
      if (strength < 0.4) _strengthColor = Colors.redAccent;
      else if (strength < 0.8) _strengthColor = Colors.orangeAccent;
      else _strengthColor = Colors.greenAccent;
    });
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveSecret() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final Map<String, dynamic> data = {};
    _controllers.forEach((key, controller) {
      data[key] = controller.text.trim();
    });

    final entry = SecretEntry(
      id: const Uuid().v4(),
      category: _selectedCategory,
      data: data,
      timestamp: DateTime.now(),
    );

    final result = await widget.vaultRepository.addSecret(entry);

    setState(() => _isLoading = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message), backgroundColor: Colors.redAccent),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Secret saved securely.'), backgroundColor: Colors.greenAccent),
        );
        Navigator.pop(context);
      },
    );
  }

  Widget _buildCategorySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(category, style: TextStyle(color: isSelected ? Colors.black : Colors.white)),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = category;
                    _initControllers();
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildFormFields() {
    if (_selectedCategory == 'Password') {
      return [
        SentryTextField(controller: _controllers['title']!, hint: 'Title / Site Name', validator: (v) => v!.isEmpty ? 'Required' : null),
        const SizedBox(height: 16),
        SentryTextField(controller: _controllers['username']!, hint: 'Username / Email', validator: (v) => v!.isEmpty ? 'Required' : null),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SentryTextField(controller: _controllers['password']!, hint: 'Password', obscureText: true, validator: (v) => v!.isEmpty ? 'Required' : null),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: IconButton(
                icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
                onPressed: () {
                  PasswordGeneratorSheet.show(context, (pwd) {
                    setState(() {
                      _controllers['password']!.text = pwd;
                    });
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: _passwordStrength, backgroundColor: Colors.grey.withOpacity(0.3), valueColor: AlwaysStoppedAnimation<Color>(_strengthColor)),
        const SizedBox(height: 16),
        SentryTextField(controller: _controllers['url']!, hint: 'URL (Optional)'),
        const SizedBox(height: 16),
        SentryTextField(controller: _controllers['totpSecret']!, hint: '2FA Setup Key (Optional)'),
      ];
    } else if (_selectedCategory == 'Bank') {
      return [
        SentryTextField(controller: _controllers['bankName']!, hint: 'Bank Name', validator: (v) => v!.isEmpty ? 'Required' : null),
        const SizedBox(height: 16),
        SentryTextField(controller: _controllers['accountNumber']!, hint: 'Account Number', validator: (v) => v!.isEmpty ? 'Required' : null),
        const SizedBox(height: 16),
        SentryTextField(controller: _controllers['ifsc']!, hint: 'IFSC / Swift Code', validator: (v) => v!.isEmpty ? 'Required' : null),
        const SizedBox(height: 16),
        SentryTextField(controller: _controllers['accountHolder']!, hint: 'Account Holder Name'),
      ];
    } else if (_selectedCategory == 'Card') {
      return [
        SentryTextField(controller: _controllers['bankName']!, hint: 'Bank/Card Name (e.g. Chase Sapphire)', validator: (v) => v!.isEmpty ? 'Required' : null),
        const SizedBox(height: 16),
        SentryTextField(controller: _controllers['cardNumber']!, hint: 'Card Number', validator: (v) => v!.isEmpty ? 'Required' : null),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: SentryTextField(controller: _controllers['expiryDate']!, hint: 'MM/YY', validator: (v) => v!.isEmpty ? 'Required' : null)),
            const SizedBox(width: 16),
            Expanded(child: SentryTextField(controller: _controllers['cvv']!, hint: 'CVV', obscureText: true, validator: (v) => v!.isEmpty ? 'Required' : null)),
          ],
        ),
        const SizedBox(height: 16),
        SentryTextField(controller: _controllers['cardHolder']!, hint: 'Card Holder Name'),
      ];
    } else if (_selectedCategory == 'ID Card') {
      return [
        SentryTextField(controller: _controllers['idType']!, hint: 'ID Type (e.g. Passport, PAN)', validator: (v) => v!.isEmpty ? 'Required' : null),
        const SizedBox(height: 16),
        SentryTextField(controller: _controllers['idNumber']!, hint: 'ID Number', validator: (v) => v!.isEmpty ? 'Required' : null),
        const SizedBox(height: 16),
        SentryTextField(controller: _controllers['expiryDate']!, hint: 'Expiry Date (Optional)'),
      ];
    } else {
      return [
        SentryTextField(controller: _controllers['title']!, hint: 'Note Title', validator: (v) => v!.isEmpty ? 'Required' : null),
        const SizedBox(height: 16),
        SentryTextField(controller: _controllers['note']!, hint: 'Secure Note Content', maxLines: 5, validator: (v) => v!.isEmpty ? 'Required' : null),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Secret', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Select Category', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
              const SizedBox(height: 12),
              _buildCategorySelector(),
              const SizedBox(height: 32),
              
              ..._buildFormFields(),

              const SizedBox(height: 48),
              GlowButton(
                label: 'Save Secret',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _saveSecret,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
