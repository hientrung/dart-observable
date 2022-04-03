import 'dart:async';

import 'package:obsobject/obsobject.dart';
import 'package:test/test.dart';

void main() {
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

    test('changed observer', () async {
      var a = Observable(0);
      var b = Computed(() => a.value);
      var c = 0;
      b.changed(() {
        c++;
      });
      expect(b.rebuildCount, 1);
      for (var i = 0; i < 10; i++) {
        a.value = i;
      }
      await Future.delayed(Duration(seconds: 1));
      expect(b.rebuildCount, 2);
      expect(c, 1);
    });

    test('check value required', () {
      var a = Observable('test', validator: ValidatorRequired());
      expect(a.valid, true);
      a.value = '';
      expect(a.valid, false);
    });

    test('listen on observable, read valid', () {
      var a = Observable('test', validator: ValidatorRequired());
      var c = false;
      a.listen(() {
        c = a.valid;
      });
      expect(c, true);
      a.value = '';
      expect(c, false);
    });

    test('Listen with 1 parameter', () {
      var a = Observable(1);
      a.listen((v) {
        expect(v.runtimeType, int);
        expect(v, a.value);
      });
      a.value = 2;
      a.value = 3;
    });

    test('Listen with 2 parameter', () {
      var a = Observable(1);
      a.listen((v, o) {
        expect(o.runtimeType, int);
        expect(v, a.value);
        expect(o, a.oldValue);
      });
      a.value = 2;
      a.value = 3;
    });

    test('Check 2 object valid', () {
      var a = Observable('', validator: ValidatorRequired());
      var b = Observable('', validator: ValidatorRequired());
      var c = Computed(() => a.valid && b.valid);
      expect(c.value, false);
      expect(c.dependCount, greaterThan(0));
      a.value = 'test';
      expect(c.value, false);
      b.value = 'a';
      expect(c.value, true);
    });

    test('Set error manual', () {
      var a = Observable('test', validator: ValidatorRequired());
      expect(a.valid, true);
      a.value = '';
      expect(a.valid, false);
      a.setError('a');
      expect(a.valid, false);
      expect(a.error, 'a');
    });

    test('Prevent double notify observable has validator', () async {
      var a = Observable('', validator: ValidatorRequired());
      int c = 0;
      a.changed(() {
        expect(a.valid, true);
        c++;
      });
      await Future.delayed(Duration(milliseconds: 100));
      expect(c, 0);
      a.value = 'a';
      await Future.delayed(Duration(milliseconds: 100));
      expect(c, 1);
    });

    test('Validate base on other observable', () async {
      var a = Observable(false);
      var t = 0;
      var b = Observable(
        '',
        validator: ValidatorRequired()
          ..condition = () {
            t++;
            return a.value;
          },
      );
      var c = 0;
      b.changed(() => c++);
      await Future.delayed(Duration(milliseconds: 100));
      expect(c, 0);
      expect(t, 1);
      expect(b.valid, true);
      a.value = true;
      await Future.delayed(Duration(milliseconds: 100));
      expect(c, 1);
      expect(t, 2);
      expect(b.valid, false);
      await Future.delayed(Duration(milliseconds: 100));
      expect(c, 1);
      expect(t, 2);
    });

    test('Ratelimit', () async {
      var a = Observable('', rateLimit: 500);
      var c = 0;
      a.changed(() => c++);
      a.value = 'test';
      await Future.delayed(Duration(milliseconds: 200));
      a.value = 'test test';
      expect(c, 0);
      await Future.delayed(Duration(milliseconds: 600));
      expect(c, 1);
    });

    test('Validate status in sync process', () {
      var a = Observable(0, validator: ValidatorRequired());
      var b = Computed(() => a.valid);
      expect(b.value, false);
      a.value = 1;
      expect(b.value, true);
    });

    test('Listen ValidateAsync', () async {
      var a =
          Observable(0, validator: ValidatorAsync((v) => Future.value(v > 10)));
      var c = 0;
      var arr = [
        ValidateStatus.pending,
        ValidateStatus.invalid,
        ValidateStatus.pending,
        ValidateStatus.valid
      ];
      a.listen((int v) {
        //expect(a.validStatus, arr[c]);
        print(c);
        print(a.validStatus);
        c++;
      });
      await Future.delayed(Duration(milliseconds: 200));
      //expect(c, 2);
      a.value = 20;
      await Future.delayed(Duration(milliseconds: 200));
      //expect(c, 4);
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

    test('access  nested computed value', () {
      var a = Observable(1);
      var b = Computed(() => a.value + 1);
      var c = Computed(() => b.value + 1);
      expect(c.value, 3);
      a.value = 2;
      expect(c.value, 4);
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
      for (var i = 0; i < 10; i++) {
        a.value = i;
      }
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
      Computed(() {
        c = a.value;
        return c;
      })
        ..rateLimit = 800
        ..listen(() {});
      a.value = 2;
      expect(c, 1);
      await Future.delayed(Duration(milliseconds: 500));
      expect(c, 1);
      await Future.delayed(Duration(milliseconds: 500));
      expect(c, 2);
    });

    test('pause and resume', () async {
      var a = Observable(1);
      var b = Computed(() {
        return a.value;
      });
      b.pause();
      a.value++;
      a.value++;
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

    test('listen nested computed', () async {
      var a = Observable(1);
      var b = Computed(() => a.value + 1);
      var c = Computed(() => b.value + 1);
      var r = [3, 4, 5];
      var i = 0;
      c.listen((v) {
        expect(v, r[i]);
        i++;
      });
      expect(i, 1);
      a.value = 2;
      await Future.delayed(Duration(seconds: 1));
      expect(i, 2);
      a.value = 3;
      await Future.delayed(Duration(seconds: 1));
      expect(i, 3);
    });

    test('writeable', () {
      var a = Observable(1);
      var b = Commission<int>(
          reader: () => a.value * 2, writer: (v) => a.value = v ~/ 2);
      expect(b.value, 2);
      b.value = 8;
      expect(a.value, 4);
    });

    test('validation', () {
      var a = Observable('');
      var b = Computed(() => a.value, validator: ValidatorRequired());
      expect(b.valid, false);
      a.value = 'test';
      expect(b.valid, true);
      expect(b.rebuildCount, 2);
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

    test('Do not recompute Computed has isValid but there are no listener',
        () async {
      var a = Observable(0);
      var b = Computed(() => a.value);
      a.value = 1;
      await Future.delayed(Duration(seconds: 1));
      expect(b.rebuildCount, 0);
      expect(b.valid, true);
      expect(b.value, 1);
      expect(b.rebuildCount, 1);
    });

    test('Run compute 1 time depend on nested computed, observable', () async {
      var a = Observable(1);
      var b = Computed(() => a.value * 2);
      var c = Computed(() => b.value * 3 + a.value);
      expect(c.value, 7);
      expect(c.rebuildCount, 1);
      var t = 0;
      c.changed((v) {
        t = v;
      });
      expect(c.rebuildCount, 1);
      expect(t, 0);
      a.value = 2;
      await Future.delayed(Duration(seconds: 1));
      expect(t, 14);
      expect(c.rebuildCount, 2);
    });

    test('Listen computed for async computation', () async {
      var a = Observable(1);
      var b = Computed<int>(() async {
        return await Future.delayed(
            Duration(milliseconds: 200), () => a.value * 2);
      });
      var arr = [2, 6];
      var i = 0;
      b.listen((int v) => expect(v, arr[i]));
      a.value = 3;
      i = 1;
      await Future.delayed(Duration(seconds: 1));
    });

    test('Computed return Future', () async {
      var n = Future.value(1);
      expect(n, isNot(1));
      var a = Observable(1);
      var b = Computed(() => Future.value(a.value * 2));
      var c = 0;
      var arr = [2, 4];
      b.listen((int v) {
        expect(v, arr[c]);
        c++;
      });
      await Future.delayed(Duration(milliseconds: 100));
      expect(c, 1);
      a.value = 2;
      await Future.delayed(Duration(milliseconds: 100));
      expect(c, 2);
    });
  });

  test('runtime computed, don\'t depend on so much', () {
    var cm = Completer();
    var a = <Observable<int>>[];
    var b = <Computed<int>>[];
    var max = 1000;
    var c = 10;
    var w = Stopwatch();
    for (var i = 0; i < c; i++) {
      a.add(Observable(i));
    }
    for (var i = 0; i < max; i++) {
      b.add(Computed(() {
        var t = 0;
        for (var j = 0; j < c; j++) {
          t += a[j].value;
        }
        return t;
      }));
    }
    for (var i = 0; i < max; i++) {
      b[i].listen(() {});
    }
    b[max - 1].changed(() {
      w.stop();
      print('has $max computed, each computed depend on '
          '$c observables then all update value, runtime all computed '
          '${w.elapsedMilliseconds}ms');
      print('rebuild ${b[0].rebuildCount}');
      expect(w.elapsedMilliseconds, lessThan(200));
      cm.complete();
    });
    w.start();
    for (var i = 0; i < c; i++) {
      a[i].value++;
    }
    expect(cm.future, completes);
  });

  test('example', () async {
    var a = Observable(0);
    var b = Computed(() => a.value);
    b.listen(() => print(b.value));
    for (var i = 0; i < 10; i++) {
      a.value = i;
    }
    await Future.delayed(Duration(seconds: 1));
    print(b.rebuildCount);
  });

  test('listen on computed', () async {
    final a = Observable(0);
    final b = Computed<bool>(() => a.value < 10 ? true : false);
    var c = 0;
    b.listen(() => c++);
    a.value = 1;
    await Future.delayed(Duration(seconds: 1));
    a.value = 2;
    await Future.delayed(Duration(seconds: 1));
    expect(c, 1);
    a.value = 10;
    await Future.delayed(Duration(seconds: 1));
    expect(c, 2);
  });

  test('callable class', () {
    final a = Observable(0);
    final b = Computed(() => a() * 2);
    a.value = 2;
    expect(b.value, 4);
  });
}
