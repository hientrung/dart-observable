import 'package:obsobject/obsobject.dart';

class User {
  final Observable<String> firstName = Observable('')
    ..isValid.validator = ValidatorRequired();
  final Observable<String> lastName = Observable('')
    ..isValid.validator = ValidatorRequired();
  final Observable<String> email = Observable('')
    ..isValid.validator = Validator.convert({
      'least': {'required': 'Email is required', 'email': true}
    });
  late Computed<String> fullName =
      Computed<String>(() => '${firstName.value}  ${lastName.value}');
  late Computed<bool> valid = Computed<bool>(() =>
      firstName.isValid.value && lastName.isValid.value && email.isValid.value);
}
