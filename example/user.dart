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
  Computed<String> fullName;
  User() {
    fullName = Computed(() => '${firstName.value}  ${lastName.value}');
  }
  bool get isValid {
    return firstName.isValid.value &&
        lastName.isValid.value &&
        email.isValid.value;
  }
}
