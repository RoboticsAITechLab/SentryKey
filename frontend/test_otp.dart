import 'package:otp/otp.dart';

void main() {
  try {
    print(OTP.generateTOTPCodeString('JBSWY3DPEHPK3PXP', DateTime.now().millisecondsSinceEpoch, algorithm: Algorithm.SHA1, isGoogle: true));
  } catch (e) {
    print('Error: $e');
  }
}
