import 'dart:async';

import 'package:obsobject/obsobject.dart';
import 'package:test/test.dart';

void main() {
  test('FutureOr', () {
    FutureOr<int>? a = 1;
    expect(a, 1);
    expect(a is Future, false);
  });

  test('Default message', () {
    ValidatorRequired.defaultMessage = 'required';
    var v = ValidatorRequired();
    var e = v.validate(null);
    expect(e, 'required');
  });

  test('Condition', () {
    var v = ValidatorRequired()..condition = () => false;
    expect(v.validate(null), null);
  });

  test('Required', () {
    var v = ValidatorRequired()..message = 'required';
    var e = v.validate('');
    expect(e, 'required');
  });

  test('Range', () {
    var v = ValidatorRange(max: 10);
    var s = v.validate(11);
    expect(s, isNotEmpty);
    s = v.validate(8.0);
    expect(s, null);
    v.max = 5;
    v.min = 1;
    s = v.validate('value test');
    print(s);
    expect(s, isNotEmpty);
    s = v.validate('value');
    expect(s, null);
    //[1-5]
    expect(v.validate([]), isNotEmpty);
    expect(v.validate([1, 2]), null);
  });

  test('Pattern', () {
    expect(ValidatorPattern(RegExp(r'^\w*$')).validate('test'), null);
    expect(
        ValidatorPattern(RegExp(
          r'^\w*$',
        )).validate('tes+t'),
        isNotEmpty);
  });

  test('Email', () {
    expect(ValidatorEmail().validate('mr.test@test.com'), null);
    expect(ValidatorEmail().validate('1mr.test'), isNotEmpty);
  });

  test('Custom', () {
    expect(
        ValidatorCustom((v) {
          return true;
        }).validate(''),
        null);
    expect(
        ValidatorCustom((v) {
          return false;
        }).validate(''),
        isNotEmpty);
  });

  test('All', () {
    var v = '';
    var a = ValidatorAll([ValidatorRequired(), ValidatorEmail()]);
    expect(a.validate(v), isNotEmpty);
    v = 'test@test-com';
    expect(a.validate(v), isNotEmpty);
    print(a.validate(v));
    v = 'test@test.com';
    expect(a.validate(v), null);
  });

  test('Least', () {
    var a = ValidatorLeast([
      ValidatorRequired()..message = 'required',
      ValidatorEmail()..message = 'email',
      ValidatorPattern(RegExp('test@test.com'))..message = 'test'
    ]);
    expect(a.validate(''), 'required');
    expect(a.validate('test@'), 'email');
    expect(a.validate('a@test.com'), 'test');
    expect(a.validate('test@test.com'), null);
  });

  test('Not + Contains', () {
    var a = ValidatorNot(ValidatorContains([1, 2, 3]));
    expect(a.validate(0), null);
    expect(a.validate(2), isNotEmpty);
  });

  test('Unique', () {
    var a = ValidatorUnique([1, 2, 3, 4]);
    expect(a.validate(1), isNotEmpty);
    expect(a.validate(10), null);
  });

  test('True', () {
    var a = ValidatorTrue();
    expect(a.validate('test'), isNotEmpty);
    expect(a.validate(true), null);
  });

  test('Convert Map', () {
    var t = false;
    var a = Validator.convert({
      'least': {
        'if': () {
          return t;
        },
        'validators': {
          'required': true,
          'email': 'Mail invalid',
          'not': {
            'source': {
              'pattern': {'pattern': r'test@test.com'},
            },
            'contains': {'source': 'test'}
          }
        }
      }
    })!;
    expect(a.validate(''), null);
    t = true;
    expect(a.validate(''), isNotEmpty);
    expect(a.validate('test@'), isNotEmpty);
    expect(a.validate('test@test.com'), isNotEmpty);
    expect(a.validate('a@test.com'), null);
  });
}
