import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:otp/otp.dart';

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
  late Animation<double> _hoverAnimation;

  bool _isCompromised = false;
  bool _isWeak = false;
  bool _isSecurityLoaded = false;

  Timer? _totpTimer;
  String _currentTotp = '';
  double _totpProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _hoverAnimation = CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutCubic,
    );
    _checkSecurity();
    _startTotpTimer();
  }

  void _startTotpTimer() {
    final totpSecret = widget.entry.data['totpSecret']?.toString() ?? '';
    if (totpSecret.isEmpty) return;
    
    _updateTotp(totpSecret);
    _totpTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updateTotp(totpSecret);
    });
  }

  void _updateTotp(String secret) {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final code = OTP.generateTOTPCodeString(
        secret.replaceAll(' ', ''),
        now,
        isGoogle: true,
        algorithm: Algorithm.SHA1,
      );
      
      final secondsRemaining = 30 - ((now / 1000).floor() % 30);
      final progress = secondsRemaining / 30.0;
      
      if (mounted && (_currentTotp != code || (_totpProgress - progress).abs() > 0.02)) {
        setState(() {
          _currentTotp = code;
          _totpProgress = progress;
        });
      }
    } catch (e) {
      // invalid secret
    }
  }

  @override
  void dispose() {
    _totpTimer?.cancel();
    _hoverController.dispose();
    super.dispose();
  }

  Future<void> _checkSecurity() async {
    final category = widget.entry.category;
    if (category == 'Password' || category == 'Bank' || category == 'Card') {
      final pwd = widget.entry.data['password'] ?? widget.entry.data['pin'] ?? '';
      if (pwd.isNotEmpty) {
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Color(0xFFFF4D4D)),
            const SizedBox(width: 8),
            Text(
              'Delete Entry?',
              style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'This action cannot be undone.\nThis secret will be permanently removed from your vault.',
          style: TextStyle(color: Colors.white.withOpacity(0.6), height: 1.5, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<VaultBloc>().add(DeleteEntry(id: widget.entry.id));
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF4D4D), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // A wide palette of premium visual gradients generated dynamically from ID hash (Provides 15 unique card styles)
  List<Color> _getGradientsByHash(int hash) {
    final List<List<Color>> palettes = [
      [const Color(0xFF0F172A), const Color(0xFF1E293B)], // Slate Black
      [const Color(0xFF1E1B4B), const Color(0xFF311042)], // Indigo Nebula
      [const Color(0xFF064E3B), const Color(0xFF0F172A)], // Cyber Emerald
      [const Color(0xFF450A0A), const Color(0xFF180202)], // Crimson Ruby
      [const Color(0xFF7C2D12), const Color(0xFF1E293B)], // Bronze Amber
      [const Color(0xFF1E293B), const Color(0xFF0F172A)], // Carbon Metal
      [const Color(0xFF3B0764), const Color(0xFF1E1B4B)], // Royal Violet
      [const Color(0xFF032B30), const Color(0xFF021E22)], // Oceanic Deep
      [const Color(0xFF1B2A1C), const Color(0xFF0C140D)], // Olive Sage
      [const Color(0xFF5F0F40), const Color(0xFF310E3F)], // Wine Velvet
      [const Color(0xFF0A0F1D), const Color(0xFF070B14)], // Pitch Black
      [const Color(0xFF280B3B), const Color(0xFF0F172A)], // Electric Purple
      [const Color(0xFF0F2C59), const Color(0xFF1E293B)], // Navy Steel
      [const Color(0xFF1C0A00), const Color(0xFF2D1500)], // Copper Glow
      [const Color(0xFF0F172A), const Color(0xFF0A0A0A)], // Obsidian
    ];
    final index = hash.abs() % palettes.length;
    return palettes[index];
  }

  Color _getAccentColor(int hash) {
    final List<Color> acc = [
      AppColors.primary,
      const Color(0xFF00E676),
      const Color(0xFFC084FC),
      const Color(0xFFF472B6),
      const Color(0xFFF59E0B),
      const Color(0xFF38BDF8),
      const Color(0xFFF43F5E),
    ];
    return acc[hash.abs() % acc.length];
  }

  String _maskCardNumber(String number, bool expanded) {
    if (number.isEmpty) return '•••• •••• •••• ••••';
    String cleaned = number.replaceAll(RegExp(r'\s+'), '');
    if (!expanded) {
      if (cleaned.length > 4) {
        return '•••• •••• •••• ${cleaned.substring(cleaned.length - 4)}';
      }
      return '•••• •••• •••• ••••';
    }
    final List<String> blocks = [];
    for (int i = 0; i < cleaned.length; i += 4) {
      blocks.add(cleaned.substring(i, i + 4 > cleaned.length ? cleaned.length : i + 4));
    }
    return blocks.join('   ');
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
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.4)),
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
          if (isSecret || label.toLowerCase().contains('account') || label.toLowerCase().contains('ifsc') || label.toLowerCase().contains('no'))
            CopyToClipboardButton(textToCopy: value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final hash = entry.id.hashCode;
    final gradient = _getGradientsByHash(hash);
    final accent = _getAccentColor(hash);

    Widget cardBody;
    switch (entry.category) {
      case 'Bank':
      case 'Card':
        cardBody = _buildPhysicalBankCard(gradient, accent);
        break;
      case 'ID Card':
        cardBody = _buildFuturisticIDCard(gradient, accent);
        break;
      case 'Secure Note':
        cardBody = _buildDigitalNotebookCard(gradient, accent);
        break;
      case 'Password':
      default:
        cardBody = _buildCyberConsoleCard(gradient, accent);
        break;
    }

    return MouseRegion(
      onEnter: (_) => _hoverController.forward(),
      onExit: (_) => _hoverController.reverse(),
      child: AnimatedBuilder(
        animation: _hoverAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + _hoverAnimation.value * 0.015,
            child: GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: accent.withOpacity(0.15 + _hoverAnimation.value * 0.15),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.04 + _hoverAnimation.value * 0.08),
                      blurRadius: 18,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: cardBody,
        ),
      ),
    );
  }

  // --- 1. CREDIT CARD STYLE (Bank / Card) ---
  Widget _buildPhysicalBankCard(List<Color> gradient, Color accent) {
    final data = widget.entry.data;
    final cardNo = data['cardNumber'] ?? data['accountNumber'] ?? '';
    final holder = data['accountHolder'] ?? 'Sentry User';
    final expiry = data['expiryDate'] ?? '12/30';
    final bankName = data['bankName'] ?? data['title'] ?? 'SENTRY CARD';

    return Container(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.nfc_rounded, color: Colors.white30, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    bankName.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white30),
                    onPressed: () => _confirmDelete(context),
                    splashRadius: 20,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Shiny Golden Card Chip
          Row(
            children: [
              Container(
                width: 40,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFDAA520), Color(0xFFF0E68C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Card Number Monospace Text
          Text(
            _maskCardNumber(cardNo, _isExpanded),
            style: GoogleFonts.shareTechMono(
              color: Colors.white,
              fontSize: 18,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CARD HOLDER',
                    style: TextStyle(color: Colors.white30, fontSize: 8, letterSpacing: 1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    holder.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXPIRES',
                    style: TextStyle(color: Colors.white30, fontSize: 8, letterSpacing: 1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    expiry,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // VISA / Mastercard Sleek Minimal Representation
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withOpacity(0.06),
                ),
                child: Text(
                  'PAYMENT',
                  style: GoogleFonts.spaceGrotesk(
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.08), height: 1),
            const SizedBox(height: 16),
            _buildFieldRow('Account Holder', holder),
            _buildFieldRow('Card/Acc Number', cardNo, isSecret: true),
            _buildFieldRow('Expiry Date', expiry),
            _buildFieldRow('CVV/PIN', data['cvv'] ?? data['pin'] ?? '', isSecret: true),
            _buildFieldRow('IFSC / Swift', data['ifsc'] ?? ''),
          ],
        ],
      ),
    );
  }

  // --- 2. FUTURISTIC ID BADGE STYLE (ID Card) ---
  Widget _buildFuturisticIDCard(List<Color> gradient, Color accent) {
    final data = widget.entry.data;
    final idNo = data['idNumber'] ?? '';
    final idType = data['idType'] ?? 'IDENTITY CARD';
    final expiry = data['expiryDate'] ?? 'PERMANENT';

    return Container(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.badge_rounded, color: accent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    idType.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white24),
                onPressed: () => _confirmDelete(context),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Neon Fingerprint/Avatar Box
              Container(
                width: 60,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withOpacity(0.2)),
                ),
                child: Center(
                  child: Icon(
                    Icons.fingerprint_rounded,
                    color: accent.withOpacity(0.6),
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IDENTIFICATION NUMBER',
                      style: TextStyle(color: Colors.white30, fontSize: 8, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isExpanded ? idNo : _maskCardNumber(idNo, false),
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VALID THRU',
                              style: TextStyle(color: Colors.white30, fontSize: 7, letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              expiry,
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        // Barcode placeholder
                        Container(
                          width: 60,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              8,
                              (index) => Container(
                                width: index % 2 == 0 ? 2 : 4,
                                height: 16,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.08), height: 1),
            const SizedBox(height: 16),
            _buildFieldRow('ID Type', idType),
            _buildFieldRow('ID Number', idNo, isSecret: true),
            _buildFieldRow('Expiry Date', expiry),
            _buildFieldRow('Notes / Fields', data['notes'] ?? ''),
          ],
        ],
      ),
    );
  }

  // --- 3. RETRO DIGITAL NOTEBOOK STYLE (Secure Note) ---
  Widget _buildDigitalNotebookCard(List<Color> gradient, Color accent) {
    final data = widget.entry.data;
    final title = data['title'] ?? 'SECURE NOTE';
    final note = data['note'] ?? '';

    return Container(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.sticky_note_2_rounded, color: accent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    title.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white24),
                onPressed: () => _confirmDelete(context),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Spiral notebooks lines effect
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.03)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.isNotEmpty ? note : 'Empty note contents...',
                  maxLines: _isExpanded ? 100 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.courierPrime(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                if (!_isExpanded) ...[
                  const SizedBox(height: 8),
                  Text(
                    'TAP TO UNFOLD...',
                    style: TextStyle(
                      color: accent.withOpacity(0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CopyToClipboardButton(textToCopy: note),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- 4. CYBER SOFTWARE SECURITY CONSOLE (Password / General) ---
  Widget _buildCyberConsoleCard(List<Color> gradient, Color accent) {
    final data = widget.entry.data;
    final username = data['username'] ?? '';
    final pwd = data['password'] ?? '';
    final url = data['url'] ?? '';
    final title = data['title'] ?? 'ENCRYPTED KEY';

    return Container(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shield_rounded, color: accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white24),
                onPressed: () => _confirmDelete(context),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // User / credential preview line
          Row(
            children: [
              Icon(Icons.alternate_email_rounded, size: 14, color: Colors.white30),
              const SizedBox(width: 6),
              Text(
                username.isNotEmpty ? username : 'No Username',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (url.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded, size: 10, color: accent),
                      const SizedBox(width: 4),
                      Text(
                        url.length > 20 ? '${url.substring(0, 18)}...' : url,
                        style: TextStyle(color: Colors.white30, fontSize: 10),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Strength slider inside card
          if (pwd.isNotEmpty) ...[
            _buildStrengthBar(pwd),
          ],
          
          if ((data['totpSecret'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildTotpSection(accent, data['totpSecret'].toString()),
          ],

          if (_isExpanded) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.08), height: 1),
            const SizedBox(height: 16),
            _buildFieldRow('Username', username),
            _buildFieldRow('Password', pwd, isSecret: true),
            _buildFieldRow('Site URL', url),
            if ((data['totpSecret'] ?? '').toString().isNotEmpty)
              _buildFieldRow('2FA Setup Key', data['totpSecret'].toString(), isSecret: true),
            if (_isCompromised) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D4D).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF4D4D).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4D4D), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This password was exposed in a breach. Change it!',
                        style: GoogleFonts.spaceGrotesk(fontSize: 11, color: const Color(0xFFFF4D4D), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStrengthBar(String password) {
    final score = _calculateStrength(password);
    Color strengthColor = const Color(0xFFFF4D4D);
    String strengthText = 'Weak';
    if (score >= 5) {
      strengthColor = const Color(0xFF00E676);
      strengthText = 'Strong';
    } else if (score >= 3) {
      strengthColor = const Color(0xFFFFAB00);
      strengthText = 'Moderate';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SECRET STRENGTH',
              style: TextStyle(color: Colors.white30, fontSize: 8, letterSpacing: 0.8),
            ),
            Text(
              strengthText.toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: strengthColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 6.0,
            backgroundColor: Colors.white.withOpacity(0.04),
            valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildTotpSection(Color accent, String secret) {
    String displayCode = _currentTotp;
    if (displayCode.length == 6) {
      displayCode = '${displayCode.substring(0,3)} ${displayCode.substring(3)}';
    } else if (displayCode.isEmpty) {
      displayCode = '--- ---';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: accent.withOpacity(0.8)),
                  const SizedBox(width: 6),
                  Text(
                    'AUTHENTICATOR CODE',
                    style: TextStyle(color: Colors.white30, fontSize: 8, letterSpacing: 1.2),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    displayCode,
                    style: GoogleFonts.shareTechMono(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (displayCode != '--- ---')
                    CopyToClipboardButton(textToCopy: _currentTotp),
                ],
              ),
            ],
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: _totpProgress, end: _totpProgress),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: 3,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      color: value < 0.15 ? const Color(0xFFFF4D4D) : accent,
                    );
                  },
                ),
              ),
              if (_totpProgress < 0.15)
                const Icon(Icons.warning_rounded, color: Color(0xFFFF4D4D), size: 12)
              else
                Icon(Icons.lock_clock_rounded, color: accent, size: 12),
            ],
          ),
        ],
      ),
    );
  }
}
