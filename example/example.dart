import 'package:obsobject/obsobject.dart';

class User {
  final Observable<String> firstName =
      Observable('', validator: ValidatorRequired());
  final Observable<String> lastName =
      Observable('', validator: ValidatorRequired());
  final Observable<String> email = Observable('',
      validator: Validator.convert({
        'least': {'required': 'Email is required', 'email': true}
      }));
  late Computed<String> fullName =
      Computed<String>(() => '${firstName.value}  ${lastName.value}');

  late Computed<bool> valid =
      Computed<bool>(() => firstName.valid && lastName.valid && email.valid);
}
