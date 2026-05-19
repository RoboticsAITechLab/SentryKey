import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/secret_entry.dart';
import '../../data/services/pwned_service.dart';

class VaultHealthScreen extends StatefulWidget {
  final List<SecretEntry> entries;

  const VaultHealthScreen({Key? key, required this.entries}) : super(key: key);

  @override
  State<VaultHealthScreen> createState() => _VaultHealthScreenState();
}

class _VaultHealthScreenState extends State<VaultHealthScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = true;
  int _score = 100;
  int _weakCount = 0;
  int _reusedCount = 0;
  int _pwnedCount = 0;

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _scanVault();
  }

  Future<void> _scanVault() async {
    final passwords = widget.entries.where((e) => e.category == 'Password' || e.category == 'Bank').toList();
    
    Map<String, int> passwordCounts = {};
    int weak = 0;
    int reused = 0;
    int pwned = 0;

    for (var entry in passwords) {
      String? pwd = entry.data['password'];
      if (pwd == null || pwd.isEmpty) continue;

      passwordCounts[pwd] = (passwordCounts[pwd] ?? 0) + 1;

      if (PwnedService.isPasswordWeak(pwd)) {
        weak++;
      }

      bool isPwned = await PwnedService.isPasswordCompromised(pwd);
      if (isPwned) {
        pwned++;
      }
    }

    reused = passwordCounts.values.where((count) => count > 1).length;

    int newScore = 100 - (weak * 10) - (reused * 15) - (pwned * 30);
    if (newScore < 0) newScore = 0;

    if (mounted) {
      setState(() {
        _weakCount = weak;
        _reusedCount = reused;
        _pwnedCount = pwned;
        _score = newScore;
        _isScanning = false;
      });

      _progressAnimation = Tween<double>(begin: 0, end: _score / 100.0).animate(
        CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
      );
      _progressController.forward();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Color get _scoreColor {
    if (_score >= 80) return const Color(0xFF00E676);
    if (_score >= 50) return const Color(0xFFFFAB00);
    return const Color(0xFFFF4D4D);
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(count > 0 ? 0.3 : 0.05), width: 1.5),
        boxShadow: count > 0 ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, spreadRadius: 0)] : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          Text(
            count.toString(),
            style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.bold, color: count > 0 ? color : Colors.white.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Vault Health', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _isScanning
          ? _buildScanningView()
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  _buildScoreDial(),
                  const SizedBox(height: 40),
                  Text(
                    'SECURITY BREAKDOWN',
                    style: GoogleFonts.spaceGrotesk(fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    'Compromised',
                    _pwnedCount,
                    Icons.warning_rounded,
                    const Color(0xFFFF4D4D),
                    'Found in known data breaches.',
                  ),
                  _buildStatCard(
                    'Reused',
                    _reusedCount,
                    Icons.difference_rounded,
                    const Color(0xFFFFAB00),
                    'Using the same password multiple times.',
                  ),
                  _buildStatCard(
                    'Weak',
                    _weakCount,
                    Icons.shield_outlined,
                    const Color(0xFF00E5FF),
                    'Easily guessable or short passwords.',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildScanningView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 24),
          Text(
            'Analyzing Vault Security...',
            style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Querying HaveIBeenPwned via k-Anonymity',
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreDial() {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: CustomPaint(
                painter: _ScorePainter(
                  progress: _progressAnimation.value,
                  color: _scoreColor,
                ),
              ),
            ),
            Column(
              children: [
                Text(
                  (_progressAnimation.value * 100).toInt().toString(),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                Text(
                  'SCORE',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _scoreColor,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ScorePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ScorePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi * 0.75,
      pi * 1.5,
      false,
      bgPaint,
    );

    // Progress circle with glow
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 24
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = pi * 1.5 * progress;

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        pi * 0.75,
        sweepAngle,
        false,
        glowPaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        pi * 0.75,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScorePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
