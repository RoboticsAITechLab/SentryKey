import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class PwnedService {
  static Future<bool> isPasswordCompromised(String password) async {
    try {
      final bytes = utf8.encode(password);
      final digest = sha1.convert(bytes);
      final hash = digest.toString().toUpperCase();
      final prefix = hash.substring(0, 5);
      final suffix = hash.substring(5);

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('https://api.pwnedpasswords.com/range/$prefix'));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final lines = const LineSplitter().convert(body);
        for (var line in lines) {
          final parts = line.split(':');
          if (parts.isNotEmpty && parts[0].trim() == suffix) {
            return true; // Compromised
          }
        }
      }
    } catch (e) {
      // Ignore network errors, default to false if offline
    }
    return false;
  }
  
  static bool isPasswordWeak(String password) {
    if (password.length < 8) return true;
    bool hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    bool hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    bool hasNumbers = RegExp(r'[0-9]').hasMatch(password);
    bool hasSpecial = RegExp(r'[!@#\$&*~%]').hasMatch(password); // Very basic check
    return !(hasUppercase && hasLowercase && hasNumbers && hasSpecial);
  }
}
