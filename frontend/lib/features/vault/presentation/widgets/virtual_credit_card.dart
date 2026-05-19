import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/secret_entry.dart';
import '../bloc/vault_bloc.dart';
import 'copy_to_clipboard_button.dart';

class VirtualCreditCard extends StatefulWidget {
  final SecretEntry entry;

  const VirtualCreditCard({Key? key, required this.entry}) : super(key: key);

  @override
  State<VirtualCreditCard> createState() => _VirtualCreditCardState();
}

class _VirtualCreditCardState extends State<VirtualCreditCard> with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    _isFront = !_isFront;
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Card?', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('This action cannot be undone.\\nThis card will be permanently removed.', style: TextStyle(color: Colors.white.withOpacity(0.55), height: 1.6)),
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

  String _formatCardNumber(String number) {
    String cleaned = number.replaceAll(RegExp(r'\\D'), '');
    if (cleaned.isEmpty) return '**** **** **** ****';
    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      buffer.write(cleaned[i]);
      if ((i + 1) % 4 == 0 && i != cleaned.length - 1) buffer.write(' ');
    }
    return buffer.toString();
  }

  Widget _buildFront() {
    final data = widget.entry.data;
    final bankName = data['bankName'] ?? 'Bank Card';
    final cardNumber = _formatCardNumber(data['cardNumber'] ?? '');
    final cardHolder = data['cardHolder']?.toString().toUpperCase() ?? 'CARD HOLDER';
    final expiryDate = data['expiryDate'] ?? 'MM/YY';

    // Determine card type based on number (Visa starts with 4, Master starts with 5)
    String typeText = 'CARD';
    Color typeColor = Colors.white;
    if (cardNumber.startsWith('4')) { typeText = 'VISA'; typeColor = Colors.blueAccent; }
    else if (cardNumber.startsWith('5')) { typeText = 'MasterCard'; typeColor = Colors.orangeAccent; }
    else if (cardNumber.startsWith('3')) { typeText = 'AMEX'; typeColor = Colors.lightBlueAccent; }

    return Container(
      width: double.infinity,
      height: 220,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1a1c29),
            Color(0xFF0d0e15),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      padding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          // Background ambient shapes
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 150, height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.1)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      bankName.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    typeText,
                    style: GoogleFonts.spaceGrotesk(fontSize: 18, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, color: typeColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // EMV Chip
              Container(
                width: 45,
                height: 35,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(colors: [Color(0xFFe2c179), Color(0xFFc6a152)]),
                ),
                child: CustomPaint(
                  painter: _ChipPainter(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                cardNumber,
                style: GoogleFonts.spaceMono(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 3, shadows: [
                  Shadow(color: Colors.black.withOpacity(0.5), offset: const Offset(0, 2), blurRadius: 4),
                ]),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CARD HOLDER', style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.5), letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(cardHolder, style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 1), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('EXPIRES', style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.5), letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(expiryDate, style: GoogleFonts.spaceMono(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    final cvv = widget.entry.data['cvv'] ?? '***';
    return Container(
      width: double.infinity,
      height: 220,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1a1c29),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Container(width: double.infinity, height: 45, color: Colors.black87),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 35,
                    color: Colors.white,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      cvv,
                      style: GoogleFonts.spaceMono(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CopyToClipboardButton(textToCopy: cvv),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Virtual Secure Card', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                IconButton(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white30, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleFlip,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * pi;
          final isBack = angle >= pi / 2;

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isBack
                ? Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _buildBack(),
                  )
                : _buildFront(),
          );
        },
      ),
    );
  }
}

class _ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(6)), paint);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.3, size.height), paint);
    canvas.drawLine(Offset(size.width * 0.7, 0), Offset(size.width * 0.7, size.height), paint);
    canvas.drawLine(Offset(0, size.height * 0.4), Offset(size.width, size.height * 0.4), paint);
    canvas.drawLine(Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.7), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
