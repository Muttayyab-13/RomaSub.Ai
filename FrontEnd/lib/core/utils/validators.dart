import '../constants/app_strings.dart';

class Validators {
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.emailRequired;
    }
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!emailRegex.hasMatch(value)) {
      return AppStrings.emailInvalid;
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.passwordRequired;
    }
    if (value.length < 8) {
      return AppStrings.passwordMinLength;
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
      return AppStrings.passwordNeedLetter;
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return AppStrings.passwordNeedDigit;
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\/;~]').hasMatch(value)) {
      return AppStrings.passwordNeedSpecial;
    }
    return null;
  }

  static String? confirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return AppStrings.confirmPasswordRequired;
    }
    if (value != password) {
      return AppStrings.passwordsDoNotMatch;
    }
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.nameRequired;
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
      return AppStrings.nameInvalid;
    }
    return null;
  }
}
