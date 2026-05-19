import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/secret_entry.dart';
import '../bloc/vault_bloc.dart';
import '../../data/services/pwned_service.dart';
import 'copy_to_clipboard_button.dart';

class SecretCard extends StatefulWidget {
  final SecretEntry entry;

  const SecretCard({super.key, required this.entry});

  @override
  State<SecretCard> createState() => _SecretCardState();
}

class _SecretCardState extends State<SecretCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _hoverController;
  late Animation<double> _elevationAnimation;

  bool _isCompromised = false;
  bool _isWeak = false;
  bool _isSecurityLoaded = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _elevationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );
    _checkSecurity();
  }

  Future<void> _checkSecurity() async {
    if (widget.entry.category == 'Password' || widget.entry.category == 'Bank') {
      final pwd = widget.entry.data['password'];
      if (pwd != null && pwd.isNotEmpty) {
        final isWeak = PwnedService.isPasswordWeak(pwd);
        if (mounted) {
          setState(() {
            _isWeak = isWeak;
          });
        }
        
        final isCompromised = await PwnedService.isPasswordCompromised(pwd);
        if (mounted) {
          setState(() {
            _isCompromised = isCompromised;
            _isSecurityLoaded = true;
          });
        }
      }
    }
  }

  int _calculateStrength(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$&*~%]').hasMatch(password)) score++;
    return score;
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Entry?',
          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This action cannot be undone.\nThis secret will be permanently removed.',
          style: TextStyle(color: Colors.white.withOpacity(0.55), height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5)))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<VaultBloc>().add(DeleteEntry(id: widget.entry.id));
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF4D4D), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  IconData _getIconForCategory() {
    switch (widget.entry.category) {
      case 'Bank':
        return Icons.account_balance_rounded;
      case 'ID Card':
        return Icons.badge_rounded;
      case 'Secure Note':
        return Icons.notes_rounded;
      case 'Password':
      default:
        return Icons.language_rounded;
    }
  }

  String _getTitle() {
    switch (widget.entry.category) {
      case 'Bank':
        return widget.entry.data['bankName'] ?? 'Bank Details';
      case 'ID Card':
        return widget.entry.data['idType'] ?? 'ID Card';
      case 'Secure Note':
        return widget.entry.data['title'] ?? 'Secure Note';
      case 'Password':
      default:
        return widget.entry.data['title'] ?? 'Password';
    }
  }

  String _getSubtitle() {
    switch (widget.entry.category) {
      case 'Bank':
        return widget.entry.data['accountHolder'] ?? '';
      case 'ID Card':
        return widget.entry.data['idNumber'] ?? '';
      case 'Secure Note':
        return 'Tap to view note';
      case 'Password':
      default:
        return widget.entry.data['username'] ?? '';
    }
  }

  Widget _buildFieldRow(String label, String value, {bool isSecret = false}) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
            ),
          ),
          Expanded(
            child: Text(
              isSecret && !_isExpanded ? '••••••••' : value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
                fontFamily: isSecret && !_isExpanded ? 'monospace' : null,
              ),
            ),
          ),
          if (isSecret || label.toLowerCase().contains('account') || label.toLowerCase().contains('ifsc'))
            CopyToClipboardButton(textToCopy: value),
        ],
      ),
    );
  }

  List<Widget> _buildDetails() {
    final data = widget.entry.data;
    final List<Widget> rows = [];

    if (widget.entry.category == 'Password') {
      rows.add(_buildFieldRow('Username', data['username'] ?? ''));
      rows.add(_buildFieldRow('Password', data['password'] ?? '', isSecret: true));

      final pwd = data['password'] ?? '';
      if (pwd.isNotEmpty) {
        final score = _calculateStrength(pwd);
        Color strengthColor = const Color(0xFFFF4D4D);
        String strengthText = 'Weak';
        if (score >= 5) {
          strengthColor = const Color(0xFF00E676);
          strengthText = 'Strong';
        } else if (score >= 3) {
          strengthColor = const Color(0xFFFFAB00);
          strengthText = 'Moderate';
        }

        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    'Strength',
                    style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: score / 6.0,
                                backgroundColor: Colors.white.withOpacity(0.05),
                                valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            strengthText,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: strengthColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        if (_isCompromised) {
          rows.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D4D).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF4D4D).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4D4D), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Breached! This password was leaked in a public data breach. Change it immediately!',
                      style: GoogleFonts.spaceGrotesk(fontSize: 12, color: const Color(0xFFFF4D4D), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (_isWeak) {
          rows.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFAB00).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFAB00).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFFFFAB00), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Weak Password! Ensure it has at least 8 characters, uppercase, lowercase, numbers, and symbols.',
                      style: GoogleFonts.spaceGrotesk(fontSize: 12, color: const Color(0xFFFFAB00), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }

      rows.add(_buildFieldRow('URL', data['url'] ?? ''));
    } else if (widget.entry.category == 'Bank') {
      rows.add(_buildFieldRow('Account No', data['accountNumber'] ?? '', isSecret: true));
      rows.add(_buildFieldRow('IFSC/Swift', data['ifsc'] ?? ''));
      rows.add(_buildFieldRow('Holder', data['accountHolder'] ?? ''));
    } else if (widget.entry.category == 'ID Card') {
      rows.add(_buildFieldRow('ID Number', data['idNumber'] ?? '', isSecret: true));
      rows.add(_buildFieldRow('Expiry Date', data['expiryDate'] ?? ''));
    } else if (widget.entry.category == 'Secure Note') {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            data['note'] ?? '',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.5),
          ),
        ),
      );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _hoverController.forward(),
      onExit: (_) => _hoverController.reverse(),
      child: AnimatedBuilder(
        animation: _elevationAnimation,
        builder: (context, child) => GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.surface,
              border: Border.all(color: Colors.white.withOpacity(0.06 + _elevationAnimation.value * 0.06)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(_elevationAnimation.value * 0.12),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: child,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_getIconForCategory(), size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _getTitle(),
                                style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_isCompromised)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF4D4D).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFF4D4D).withOpacity(0.4), width: 1),
                                ),
                                child: Text(
                                  'BREACHED',
                                  style: GoogleFonts.spaceGrotesk(fontSize: 8, fontWeight: FontWeight.w800, color: const Color(0xFFFF4D4D)),
                                ),
                              )
                            else if (_isWeak)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFAB00).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFFAB00).withOpacity(0.4), width: 1),
                                ),
                                child: Text(
                                  'WEAK',
                                  style: GoogleFonts.spaceGrotesk(fontSize: 8, fontWeight: FontWeight.w800, color: const Color(0xFFFFAB00)),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          _getSubtitle(),
                          style: TextStyle(fontSize: 11, color: AppColors.primary.withOpacity(0.7)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _confirmDelete(context),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: Colors.white24,
                    splashRadius: 20,
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 14),
                Divider(color: Colors.white.withOpacity(0.06), height: 1),
                const SizedBox(height: 14),
                ..._buildDetails(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
