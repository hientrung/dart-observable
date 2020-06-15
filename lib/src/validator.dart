import 'dart:async';

///Interface to register a subclass [Validator] to determine how to create it from a [Map] data
class ValidatorRegister {
  //Function called to create object
  Validator Function() creator;

  //Mapping a key, value to property of object
  void Function(Validator validator, String key, dynamic value) mapping;

  ///Register new subclass [Validator]
  ///
  ///[creator] required, [mapping] can be null
  ValidatorRegister({this.creator, this.mapping}) : assert(creator != null);
}

///Base class use to implement a validation
///
///A [Validator] include a function [validate] to check value, and [message] to description invalid data
///and [condition] used to check context before run [validate]
abstract class Validator {
  ///This used in subclass only
  ///
  ///For use, please take [validate] instead
  String doValidate(dynamic value);

  ///Message used return when [validate] need return invalid state
  String message;

  ///Used to do some check context before run [validate].
  ///
  ///If it return false then [validate] will ignored
  bool Function() condition;

  ///Do check [value], return text (not empty) if [value] is incorrect, else return null
  String validate(value) {
    if (condition != null && !condition()) return null;
    var s = doValidate(value) ?? '';
    return s.isEmpty ? null : s;
  }

  ///Helper function to return the first string is not null, not empty.
  ///Or return null if not found
  static String getMessage(List<String> msg) {
    assert(msg != null);
    for (var s in msg) {
      if (s != null && s.isNotEmpty) {
        return s;
      }
    }
    return null;
  }

  static Map<String, ValidatorRegister> _registered;

  ///cached all registered validators
  static Map<String, ValidatorRegister> get registered {
    if (_registered == null) {
      _registered = Map<String, ValidatorRegister>();
      ValidatorAll.register();
      ValidatorLeast.register();
      ValidatorNot.register();
      ValidatorRequired.register();
      ValidatorRange.register();
      ValidatorPattern.register();
      ValidatorEmail.register();
      ValidatorContains.register();
      ValidatorUnique.register();
      ValidatorTrue.register();
      ValidatorCustom.register();
      ValidatorAsync.register();
    }
    return _registered;
  }

  ///Convert a [Map] to a [Validator], there are only one element in Map. Use 'all' or 'least' to combine multi validators.
  ///
  ///Map [key] is a Validator name has been registerd
  ///
  ///Map [value] can be
  ///- null, empty, false: is skipped
  ///- true: use Validator with default values
  ///- String: use Validator with custom message
  ///- Map: contains key, value corresponding with properties of Validator
  static Validator convert(Map<String, dynamic> map) {
    if (map == null || map.isEmpty) return null;
    if (map.keys.length > 1) {
      throw "Map should has one element. Use 'all' or 'least' to combine multi validators";
    }
    var k = map.keys.first;
    var v = map[k];
    if (v == null || v.toString().isEmpty || (v is bool && !v)) return null;

    var type = registered[k];
    if (type == null) throw "Not found registered Validator for '$k'";

    var vd = type.creator();
    if (v is bool) {
      //nothing, because it's true now
    } else if (v is String) {
      vd.message = v;
    } else if (v is Map) {
      Map<String, dynamic> prop = v;
      prop.forEach((key, value) {
        switch (key) {
          case 'message':
          case 'msg':
            assert(value is String);
            vd.message = value;
            break;
          case 'condition':
          case 'if':
            assert(value is Function);
            vd.condition = value;
            break;
          default:
            if (type.mapping != null) type.mapping(vd, key, value);
        }
      });
    } else {
      throw 'Map value should be bool, String, Map';
    }
    return vd;
  }

  ///Return to list Validators from a Map or List
  static List<Validator> convertMulti(dynamic val) {
    var result = <Validator>[];
    if (val is List) {
      for (var v in val) {
        if (v is Validator) {
          result.add(v);
        } else if (v is Map) {
          var vd = convert(v);
          if (vd != null) result.add(convert(v));
        } else {
          throw 'List should contains Validator or Map';
        }
      }
    } else if (val is Map) {
      for (var k in val.keys) {
        var vd = convert({k: val[k]});
        if (vd != null) result.add(vd);
      }
    } else
      throw 'Invalid data, it should be List<Validator> or a Map data';
    return result;
  }
}

///Check all validators
class ValidatorAll extends Validator {
  static String defaultMessage;
  List<Validator> validators;

  ValidatorAll([this.validators]);

  @override
  String doValidate(value) {
    if (validators == null || validators.isEmpty) return null;
    var msg = <String>[];
    for (var vd in validators) {
      var v = vd.validate(value);
      if (v != null) msg.add(v);
    }
    if (msg.isEmpty)
      return null;
    else
      return Validator.getMessage([message, defaultMessage, msg.join('\n')]);
  }

  static void register() {
    Validator.registered['all'] = ValidatorRegister(
        creator: () => ValidatorAll(),
        mapping: (vd, k, v) {
          ValidatorAll el = vd;
          switch (k) {
            case 'validators':
              el.validators = Validator.convertMulti(v);
              break;
          }
        });
  }
}

///Check all validators but stop at the first one invalid
class ValidatorLeast extends Validator {
  static String defaultMessage;
  List<Validator> validators;

  ValidatorLeast([this.validators]);

  @override
  String doValidate(value) {
    if (validators == null || validators.isEmpty) return null;
    for (var vd in validators) {
      var v = vd.validate(value) ?? '';
      if (v.isNotEmpty)
        return Validator.getMessage([message, defaultMessage, v]);
    }
    return null;
  }

  static void register() {
    Validator.registered['least'] = ValidatorRegister(
        creator: () => ValidatorLeast(),
        mapping: (vd, k, v) {
          ValidatorLeast el = vd;
          switch (k) {
            case 'validators':
              el.validators = Validator.convertMulti(v);
              break;
          }
        });
  }
}

///Check by negative a other Validator
class ValidatorNot extends Validator {
  static String defaultMessage = 'Field value is invalid';
  Validator source;

  ValidatorNot([this.source]);

  @override
  String doValidate(value) {
    if (source == null) return null;
    var s = source.validate(value);
    if (s != null && s.isNotEmpty)
      return null;
    else
      return Validator.getMessage([s, message, defaultMessage]);
  }

  static void register() {
    Validator.registered['not'] = ValidatorRegister(
        creator: () => ValidatorNot(),
        mapping: (vd, k, v) {
          ValidatorNot el = vd;
          switch (k) {
            case 'source':
              if (v is Map)
                el.source = Validator.convert(v);
              else if (v is Validator)
                el.source = v;
              else
                throw 'Source should be a Validator or Map';
              break;
          }
        });
  }
}

///Check value required, it's invalid for null, empty string, zero
class ValidatorRequired extends Validator {
  static String defaultMessage = 'Field value is required.';

  @override
  String doValidate(value) {
    if (value == null ||
        (value is String && value == '') ||
        ((value is int || value is double) && value == 0))
      return Validator.getMessage([message, defaultMessage]);
    else
      return null;
  }

  static void register() {
    Validator.registered['required'] =
        ValidatorRegister(creator: () => ValidatorRequired(), mapping: null);
  }
}

///Check String.length or List.length or number should in a range min, max
///
///value min, max can be null to skip check it
class ValidatorRange extends Validator {
  static String defaultMessage = 'Field value is not in range [{0} - {1}].';
  dynamic min;
  dynamic max;

  ValidatorRange({this.min, this.max});

  @override
  String doValidate(value) {
    if (value == null || (value is String && value.isEmpty)) return null;
    dynamic v;
    if (value is String || value is List)
      v = value.length;
    else
      v = value;
    if ((min != null && v < min) || (max != null && v > max))
      return Validator.getMessage([message, defaultMessage])
          ?.replaceAll(r'{0}', min.toString())
          ?.replaceAll(r'{1}', max.toString());
    else
      return null;
  }

  static void register() {
    Validator.registered['range'] = ValidatorRegister(
        creator: () => ValidatorRange(),
        mapping: (vd, k, v) {
          ValidatorRange el = vd;
          switch (k) {
            case 'min':
              el.min = v;
              break;
            case 'max':
              el.max = v;
              break;
          }
        });
  }
}

///Check string match a pattern, pattern can be a String or RegExp
class ValidatorPattern extends Validator {
  static String defaultMessage = 'Field value is not matched {0}.';
  dynamic pattern;

  ValidatorPattern([this.pattern]);

  @override
  String doValidate(value) {
    if (pattern == null ||
        value == null ||
        (value is String && value.isEmpty) ||
        (pattern is String && pattern.isEmpty)) return null;
    RegExp reg;
    if (pattern is String)
      reg = RegExp(pattern);
    else if (pattern is RegExp)
      reg = pattern;
    else
      throw 'Pattern should be a String or RegExp';
    if (!reg.hasMatch(value))
      return Validator.getMessage([message, defaultMessage])
          ?.replaceAll(r'{0}', pattern.toString());
    else
      return null;
  }

  static void register() {
    Validator.registered['pattern'] = ValidatorRegister(
        creator: () => ValidatorPattern(),
        mapping: (vd, k, v) {
          ValidatorPattern el = vd;
          switch (k) {
            case 'pattern':
              el.pattern = v;
              break;
          }
        });
  }
}

///Check string is valid email
class ValidatorEmail extends Validator {
  static String defaultMessage = 'Invalid email';

  @override
  String doValidate(value) {
    if (value == null || value.isEmpty) return null;
    var reg = RegExp(r'^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,3})+$');
    if (!reg.hasMatch(value))
      return Validator.getMessage([message, defaultMessage]);
    else
      return null;
  }

  static void register() {
    Validator.registered['email'] =
        ValidatorRegister(creator: () => ValidatorEmail(), mapping: null);
  }
}

///Check value exist in a source, checked by use method 'contains'
class ValidatorContains extends Validator {
  static String defaultMessage = 'Field value is invalid';
  dynamic source;
  ValidatorContains([this.source]);
  @override
  String doValidate(value) {
    if (value == null || source == null || (source is String && source.isEmpty))
      return null;
    if (source.contains(value))
      return null;
    else
      return Validator.getMessage([message, defaultMessage]);
  }

  static void register() {
    Validator.registered['contains'] = ValidatorRegister(
        creator: () => ValidatorContains(),
        mapping: (vd, k, v) {
          ValidatorContains el = vd;
          switch (k) {
            case 'source':
              el.source = v;
              break;
          }
        });
  }
}

///Check value is not exist in source, checked by use method 'contains'
class ValidatorUnique extends Validator {
  static String defaultMessage = 'Field value is already in use.';
  dynamic source;
  ValidatorUnique([this.source]);
  @override
  String doValidate(value) {
    if (value == null || source == null || (source is String && source.isEmpty))
      return null;
    if (!source.contains(value))
      return null;
    else
      return Validator.getMessage([message, defaultMessage]);
  }

  static void register() {
    Validator.registered['unique'] = ValidatorRegister(
        creator: () => ValidatorUnique(),
        mapping: (vd, k, v) {
          ValidatorUnique el = vd;
          switch (k) {
            case 'source':
              el.source = v;
              break;
          }
        });
  }
}

///Check value should be 'true'
class ValidatorTrue extends Validator {
  static String defaultMessage = 'Field value is invalid';
  @override
  String doValidate(value) {
    if (value != true)
      return Validator.getMessage([message, defaultMessage]);
    else
      return null;
  }

  static void register() {
    Validator.registered['true'] =
        ValidatorRegister(creator: () => ValidatorTrue(), mapping: null);
  }
}

///Check value by a custom function, skip check null already
class ValidatorCustom extends Validator {
  static String defaultMessage = 'Field value is invalid';
  bool Function(dynamic value) valid;

  ValidatorCustom([this.valid]);

  @override
  String doValidate(value) {
    if (value == null || valid == null) return null;
    if (!valid(value))
      return Validator.getMessage([message, defaultMessage]);
    else
      return null;
  }

  static void register() {
    Validator.registered['custom'] = ValidatorRegister(
        creator: () => ValidatorCustom(),
        mapping: (vd, k, v) {
          ValidatorCustom el = vd;
          switch (k) {
            case 'valid':
              el.valid = v;
              break;
          }
        });
  }
}

///Check value by an async function, skip check null already.
///if async is running, then it return message messageAsync || defaultMessageAsync.
///Use events onStart, onDone to listen, update UI.
///It also call a callback function (void validatorCallback(String)) in current Zone after done
class ValidatorAsync extends Validator {
  static String defaultMessage = 'Field value is invalid';
  static String defaultMessageAsync = 'Async is running';
  String messageAsync;
  Future<bool> Function(dynamic value) valid;
  bool _running = false;
  dynamic _oldValue;
  bool _result;
  void Function() onStart;
  void Function(bool result) onDone;
  int rateLimit;
  StreamSubscription _subValid;

  ValidatorAsync([this.valid]);

  @override
  String doValidate(value) {
    if (value == null || valid == null) {
      if (_running) {
        _running = false;
        _result = true;
        _oldValue = null;
        _subValid?.cancel();
        _subValid = null;
        if (onDone != null) onDone(_result);
      }
      return null;
    }

    if (_oldValue != value) {
      //check new value
      _running = true;
      _oldValue = value;
      if (onStart != null) onStart();
      _subValid?.cancel();

      _subValid = Future.delayed(Duration(milliseconds: rateLimit ?? 0))
          .asStream()
          .listen((event) {
        valid(value).then((v) {
          _running = false;
          _result = v;
          //notify manual
          if (onDone != null) onDone(_result);
          //callback by Zone
          var callback = Zone.current['validatorCallback'];
          if (callback != null) {
            var s = _result
                ? null
                : Validator.getMessage([message, defaultMessage]);
            callback(s);
          }
        });
      });

      return Validator.getMessage([messageAsync, defaultMessageAsync]);
    } else if (_running) {
      //in checking
      return Validator.getMessage([messageAsync, defaultMessageAsync]);
    } else {
      //check done
      if (_result)
        return null;
      else
        return Validator.getMessage([message, defaultMessage]);
    }
  }

  static void register() {
    Validator.registered['async'] = ValidatorRegister(
        creator: () => ValidatorAsync(),
        mapping: (vd, k, v) {
          ValidatorAsync el = vd;
          switch (k) {
            case 'valid':
              el.valid = v;
              break;
            case 'messageAsync':
              el.messageAsync = v;
              break;
            case 'rateLimit':
              el.rateLimit = v;
              break;
            case 'onDone':
              el.onDone = v;
              break;
            case 'onStart':
              el.onStart = v;
              break;
          }
        });
  }
}
