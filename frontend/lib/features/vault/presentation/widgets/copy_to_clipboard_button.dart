import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

class CopyToClipboardButton extends StatefulWidget {
  final String textToCopy;
  final String label;

  const CopyToClipboardButton({
    super.key,
    required this.textToCopy,
    this.label = 'Copy',
  });

  @override
  State<CopyToClipboardButton> createState() => _CopyToClipboardButtonState();
}

class _CopyToClipboardButtonState extends State<CopyToClipboardButton> {
  bool _isCopied = false;
  Timer? _clearTimer;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.textToCopy));
    setState(() => _isCopied = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard. Will clear in 30 seconds.'),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    // Cancel existing timer if any
    _clearTimer?.cancel();

    // Auto-clear clipboard after 30 seconds for security
    _clearTimer = Timer(const Duration(seconds: 30), () async {
      final currentData = await Clipboard.getData('text/plain');
      // Only clear if the clipboard still contains our copied text
      if (currentData?.text == widget.textToCopy) {
        Clipboard.setData(const ClipboardData(text: ''));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Clipboard auto-cleared for security.'),
              backgroundColor: Colors.grey,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
      if (mounted) {
        setState(() => _isCopied = false);
      }
    });
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
        color: _isCopied ? Colors.greenAccent : AppColors.primary,
        size: 20,
      ),
      tooltip: widget.label,
      onPressed: _copyToClipboard,
    );
  }
}
