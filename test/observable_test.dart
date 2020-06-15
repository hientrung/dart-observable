import 'package:obsobject/obsobject.dart';
import 'package:test/test.dart';

main() {
  group('Observable', () {
    test('listen change value', () {
      var a = Observable(1);
      var l = 0;
      a.listen(() {
        l++;
      });
      a.value++;
      a.value++;
      expect(l, 3);
      expect(a.value, 3);
    });
  });

  group('Test validate value', () {
    test('check value required', () {
      var a = Observable('test');
      a.validator = ValidatorRequired();
      expect(a.isValid.value, true);
      a.value = '';
      expect(a.isValid.value, false);
    });
  });
}
