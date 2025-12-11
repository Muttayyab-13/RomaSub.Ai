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
    if (value.length < 6) {
      return AppStrings.passwordShort;
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
