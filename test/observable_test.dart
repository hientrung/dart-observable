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

    test('check value required', () {
      var a = Observable('test');
      a.isValid.validator = ValidatorRequired();
      expect(a.isValid.value, true);
      a.value = '';
      expect(a.isValid.value, false);
    });

    test('listen on observable, read isValid', () {
      var a = Observable('test')..isValid.validator = ValidatorRequired();
      var c = false;
      a.listen(() {
        c = a.isValid.value;
      });
      expect(c, true);
      a.value = '';
      expect(c, false);
    });

    test('listen on isValid', () {
      var a = Observable('test')..isValid.validator = ValidatorRequired();
      var c = false;
      a.isValid.listen(() {
        c = a.isValid.value;
      });
      expect(c, true);
      a.value = '';
      expect(c, false);
    });

    test('Check valid by async validator by listen on observable', () async {
      var a = Observable('')
        ..isValid.validator = ValidatorAsync((v) => Future.value(v == 'test'));
      var msg = <String>[];
      var r;
      a.listen(() {
        r = a.isValid.value;
        msg.add(a.isValid.message);
      });

      await Future.delayed(Duration(milliseconds: 100));
      expect(r, false);
      expect(msg,
          [ValidatorAsync.defaultMessageAsync, ValidatorAsync.defaultMessage]);
      await Future.delayed(Duration(milliseconds: 100));
      msg.clear();
      a.value = 'test';
      await Future.delayed(Duration(milliseconds: 100));
      expect(r, true);
      expect(msg, [ValidatorAsync.defaultMessageAsync, '']);
    });
  });

  group('Computed', () {
    test('only computed if access value', () {
      var a = Observable(1);
      var b = Computed(() {
        return a.value;
      });
      expect(b.rebuildCount, 0);
      b.value;
      expect(b.rebuildCount, 1);
    });

    test('listen is async process', () async {
      var a = Observable(1);
      var b = Computed(() {
        return a.value;
      });
      var c = 0;
      //rebuild first time
      b.listen(() {
        c = a.value;
      });
      for (var i = 0; i < 10; i++) a.value = i;
      //rebuild second after done for

      await Future.delayed(Duration(seconds: 1));
      expect(c, a.value);
      expect(b.rebuildCount, 2);
    });

    test('Write value in function compute', () {
      var a = Observable(1);
      var b = Computed(() {
        a.value++;
        return a.value;
      });
      a.value = 2;

      expect(b.value, 3);
    });

    test('only compute after rateLimit', () async {
      var a = Observable(1);
      var c = 0;
      var b = Computed(() {
        c = a.value;
      })
        ..rateLimit = 800
        ..listen(() {});
      a.value = 2;
      expect(c, 1);
      await Future.delayed(Duration(milliseconds: 500));
      expect(c, 1);
      await Future.delayed(Duration(milliseconds: 500));
      expect(c, 2);
      b.value; //just ignore warning
    });

    test('pause and resume', () async {
      var a = Observable(1);
      var b = Computed(() {
        return a.value;
      });
      b.pause();
      a.value++;
      a.value++;
      b.value;
      a.value++;
      expect(b.value, null);
      b.resume();
      b.value;
      expect(b.rebuildCount, 1);
    });

    test('multi observable', () {
      var a = Observable(1);
      var b = Observable(1);
      var c = Computed(() {
        return a.value + b.value;
      });
      expect(c.value, 2);
      a.value = 2;
      expect(c.value, 3);
      b.value = 4;
      expect(c.value, 6);
    });

    test('nested computed', () {
      var a = Observable(1);
      var b = Computed(() => a.value);
      var c = Computed(() => a.value * b.value);
      expect(c.value, 1);
      a.value = 2;
      expect(c.value, 4);
    });

    test('writeable', () {
      var a = Observable(1);
      var b = Commission(
          reader: () => a.value * 2, writer: (v) => a.value = v ~/ 2);
      expect(b.value, 2);
      b.value = 8;
      expect(a.value, 4);
    });

    test('validation', () {
      var a = Observable('');
      var b = Computed(() => a.value)..isValid.validator = ValidatorRequired();
      expect(b.isValid.value, false);
      a.value = 'test';
      expect(b.isValid.value, true);
      expect(b.rebuildCount, 2);
    });

    test('listen on validation', () async {
      var a = Observable('');
      var b = Computed(() => a.value)..isValid.validator = ValidatorRequired();
      var c;
      b.isValid.listen(() {
        c = b.isValid.value;
      });
      expect(c, false);
      a.value = 'test';
      await Future.delayed(Duration(milliseconds: 100));
      expect(c, true);
    });

    test('ignore dependencies', () {
      var a = Observable(1);
      var b = Computed(() {
        return Computed.ignoreDependencies(() => a.value);
      });
      expect(b.value, 1);
      a.value = 2;
      expect(b.value, 1);
      expect(b.dependCount, 0);
    });

    test('async in computed', () {
      var a = Observable(3);
      var t = 2;
      //it get depend in Future but it return t before
      var b = Computed(() {
        Future.value(t).then((value) => t = value * a.value);
        return t;
      });
      b.value;
      expect(
          Future.delayed(Duration(seconds: 0), () {
            expect(b.value, 2);
            expect(b.dependCount, 1); //depend on a in future
            expect(t, 6);
          }),
          completes);
    });

    test('ignore depend if get value observable by .peek', () {
      var a = Observable(1);
      var b = Computed(() {
        return a.peek * 10;
      });
      a.value++;
      b.value;
      a.value++;
      //value just build when it access, so a.peek is 20 already in this case
      expect(b.value, 20);
      expect(b.dependCount, 0);
      expect(b.rebuildCount, 1);

      var c = Computed(() {
        return b.value;
      });
      a.value = 3;
      expect(c.value, 20);
    });
  });
}
