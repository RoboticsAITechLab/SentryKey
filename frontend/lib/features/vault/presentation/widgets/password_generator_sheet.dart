import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

class PasswordGeneratorSheet extends StatefulWidget {
  final Function(String) onPasswordSelected;

  const PasswordGeneratorSheet({super.key, required this.onPasswordSelected});

  static Future<void> show(BuildContext context, Function(String) onPasswordSelected) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PasswordGeneratorSheet(onPasswordSelected: onPasswordSelected),
    );
  }

  @override
  State<PasswordGeneratorSheet> createState() => _PasswordGeneratorSheetState();
}

class _PasswordGeneratorSheetState extends State<PasswordGeneratorSheet> {
  double _length = 16;
  bool _useUpper = true;
  bool _useLower = true;
  bool _useNumbers = true;
  bool _useSymbols = true;
  
  String _generatedPassword = '';

  @override
  void initState() {
    super.initState();
    _generatePassword();
  }

  void _generatePassword() {
    String upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    String lower = 'abcdefghijklmnopqrstuvwxyz';
    String numbers = '0123456789';
    String symbols = '!@#\$%^&*()-_=+[]{}|;:,.<>?';

    String chars = '';
    if (_useUpper) chars += upper;
    if (_useLower) chars += lower;
    if (_useNumbers) chars += numbers;
    if (_useSymbols) chars += symbols;

    if (chars.isEmpty) {
      chars = lower; // fallback
      _useLower = true;
    }

    String result = '';
    final random = Random.secure();
    
    // Ensure at least one of each selected type is included
    List<String> guaranteed = [];
    if (_useUpper) guaranteed.add(upper[random.nextInt(upper.length)]);
    if (_useLower) guaranteed.add(lower[random.nextInt(lower.length)]);
    if (_useNumbers) guaranteed.add(numbers[random.nextInt(numbers.length)]);
    if (_useSymbols) guaranteed.add(symbols[random.nextInt(symbols.length)]);

    int remaining = _length.toInt() - guaranteed.length;
    for (int i = 0; i < remaining; i++) {
      result += chars[random.nextInt(chars.length)];
    }

    result += guaranteed.join('');
    
    // Shuffle the result
    List<String> resultList = result.split('')..shuffle(random);
    
    setState(() {
      _generatedPassword = resultList.join('');
    });
  }

  int _calculateStrength() {
    int score = 0;
    if (_length >= 12) score++;
    if (_length >= 16) score++;
    if (_useUpper) score++;
    if (_useLower) score++;
    if (_useNumbers) score++;
    if (_useSymbols) score++;
    return score;
  }

  Color _getStrengthColor(int score) {
    if (score >= 5) return const Color(0xFF00E676); // Uncrackable
    if (score >= 3) return const Color(0xFFFFAB00); // Good
    return const Color(0xFFFF4D4D); // Weak
  }

  String _getStrengthText(int score) {
    if (score >= 5) return 'UNCRACKABLE';
    if (score >= 3) return 'STRONG';
    return 'WEAK';
  }

  Widget _buildToggle(String title, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value ? AppColors.primary.withOpacity(0.3) : Colors.transparent),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
          Switch(
            value: value,
            onChanged: (val) {
              // Prevent turning off all switches
              if (!val && (!_useUpper && !_useLower && !_useNumbers && !_useSymbols)) return;
              onChanged(val);
              _generatePassword();
            },
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.3),
            inactiveThumbColor: Colors.white30,
            inactiveTrackColor: Colors.white10,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int score = _calculateStrength();
    Color strengthColor = _getStrengthColor(score);
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: strengthColor.withOpacity(0.1),
            blurRadius: 40,
            spreadRadius: 5,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Text(
            'Neon Generator',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          // Password Display
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: strengthColor.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: strengthColor.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _generatedPassword,
                    style: GoogleFonts.shareTechMono(
                      fontSize: _length > 24 ? 14 : 18,
                      color: strengthColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                  onPressed: _generatePassword,
                  tooltip: 'Regenerate',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Strength Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STRENGTH',
                style: TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 1.5),
              ),
              Text(
                _getStrengthText(score),
                style: GoogleFonts.spaceGrotesk(
                  color: strengthColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Length Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Length', style: TextStyle(color: Colors.white, fontSize: 14)),
              Text('${_length.toInt()}', style: GoogleFonts.spaceGrotesk(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: _length,
              min: 8,
              max: 64,
              divisions: 56,
              onChanged: (val) {
                setState(() => _length = val);
                _generatePassword();
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Toggles
          Row(
            children: [
              Expanded(child: _buildToggle('A-Z', _useUpper, (v) => setState(() => _useUpper = v))),
              const SizedBox(width: 12),
              Expanded(child: _buildToggle('a-z', _useLower, (v) => setState(() => _useLower = v))),
            ],
          ),
          Row(
            children: [
              Expanded(child: _buildToggle('0-9', _useNumbers, (v) => setState(() => _useNumbers = v))),
              const SizedBox(width: 12),
              Expanded(child: _buildToggle('!@#', _useSymbols, (v) => setState(() => _useSymbols = v))),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Use Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [strengthColor.withOpacity(0.8), strengthColor.withOpacity(0.5)],
                ),
                boxShadow: [
                  BoxShadow(color: strengthColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 1),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _generatedPassword));
                  widget.onPasswordSelected(_generatedPassword);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Use Password',
                  style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
