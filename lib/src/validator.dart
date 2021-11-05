///Interface to register a subclass [Validator]
///to determine how to create it from a [Map] data
class ValidatorRegister {
  ///Function called to create object
  Validator Function() creator;

  ///Mapping a key, value to property of object
  void Function(Validator validator, String key, dynamic value)? mapping;

  ///Register new subclass [Validator]
  ///
  ///[creator] required, [mapping] can be null
  ValidatorRegister({required this.creator, this.mapping});
}

///Base class use to implement a validation
///
///A [Validator] include a function [validate] to check value,
///and [message] to description invalid data
///and [condition] used to check context before run [validate]
abstract class Validator {
  ///This used in subclass only
  ///
  ///For internal use
  String? _doValidate(dynamic value);

  ///Message used return when [validate] need return invalid state
  String? message;

  ///Used to do some check context before run [validate].
  ///
  ///If it return false then [validate] will ignored
  bool Function()? condition;

  ///Do check [value], return text if [value] is invalid, otherwise is null
  String? validate(dynamic value) {
    if (condition != null && !condition!()) return null;
    return _doValidate(value);
  }

  static Map<String, ValidatorRegister>? _registered;

  ///cached all registered validators
  static Map<String, ValidatorRegister> get registered {
    if (_registered == null) {
      _registered = <String, ValidatorRegister>{};
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
    }
    return _registered!;
  }

  ///Convert a [Map] to a [Validator], there are only one element in Map.
  ///Use 'all' or 'least' to combine multi validators.
  ///
  ///Map [key] is a Validator name has been registered
  ///
  ///Map [value] can be
  ///- null, empty, false: is skipped
  ///- true: use Validator with default values
  ///- String: use Validator with custom message
  ///- Map: contains key, value corresponding with properties of Validator
  static Validator? convert(Map<String, dynamic> map) {
    if (map.isEmpty) return null;
    if (map.keys.length > 1) {
      throw 'Map should has one element. '
          "Use 'all' or 'least' to combine multi validators";
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
    } else if (v is Map<String, dynamic>) {
      v.forEach((key, value) {
        switch (key) {
          case 'message':
          case 'msg':
            vd.message = value.toString();
            break;
          case 'condition':
          case 'if':
            if (value is! bool Function()) {
              throw "The value of '$key' should be Function";
            }
            vd.condition = value;
            break;
          default:
            if (type.mapping != null) type.mapping!(vd, key, value);
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
        } else if (v is Map<String, dynamic>) {
          var vd = convert(v);
          if (vd != null) result.add(vd);
        } else {
          throw 'List should contains Validator or Map';
        }
      }
    } else if (val is Map<String, dynamic>) {
      for (var k in val.keys) {
        var vd = convert({k: val[k]});
        if (vd != null) result.add(vd);
      }
    } else {
      throw 'Invalid data, it should be List<Validator> or a Map data';
    }
    return result;
  }
}

///Check all validators
class ValidatorAll extends Validator {
  ///Default invalid message
  ///it will be used if [message] doesn't has value
  static String? defaultMessage;

  ///Validators will be check
  List<Validator>? validators;

  ///Create a [Validator] to validate all other validators
  ValidatorAll([this.validators]);

  @override
  String? _doValidate(dynamic value) {
    if (validators == null || validators!.isEmpty) return null;
    var msg = <String>[];
    for (var vd in validators!) {
      var v = vd.validate(value);
      if (v != null) msg.add(v);
    }
    if (msg.isEmpty) {
      return null;
    } else {
      return message ?? defaultMessage ?? msg.join('\n');
    }
  }

  ///Register function to convert from a [Map] data
  static void register() {
    Validator.registered['all'] = ValidatorRegister(
        creator: () => ValidatorAll(),
        mapping: (vd, k, v) {
          var el = vd as ValidatorAll;
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
  ///Default invalid message
  ///it will be used if [message] doesn't has value
  static String? defaultMessage;

  ///Validators will be check
  List<Validator>? validators;

  ///Create a [Validator] to validate other validators
  ///and stop at the first one invalid
  ValidatorLeast([this.validators]);

  @override
  String? _doValidate(dynamic value) {
    if (validators == null || validators!.isEmpty) return null;
    for (var vd in validators!) {
      var v = vd.validate(value);
      if (v != null) {
        return message ?? defaultMessage ?? v;
      }
    }
    return null;
  }

  ///Register function to convert from a [Map] data
  static void register() {
    Validator.registered['least'] = ValidatorRegister(
        creator: () => ValidatorLeast(),
        mapping: (vd, k, v) {
          var el = vd as ValidatorLeast;
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
  ///Default invalid message
  ///it will be used if [message] doesn't has value
  static String defaultMessage = 'Field value is invalid';

  ///Current [Validator] used to negative
  Validator? source;

  ///Create a [Validator] by negative a other [Validator]
  ValidatorNot([this.source]);

  @override
  String? _doValidate(dynamic value) {
    if (source == null) return null;
    var s = source!.validate(value);
    if (s != null) {
      return null;
    } else {
      return message ?? defaultMessage;
    }
  }

  ///Register function to convert from a [Map] data
  static void register() {
    Validator.registered['not'] = ValidatorRegister(
        creator: () => ValidatorNot(),
        mapping: (vd, k, v) {
          var el = vd as ValidatorNot;
          switch (k) {
            case 'source':
              if (v is Map<String, dynamic>) {
                el.source = Validator.convert(v);
              } else if (v is Validator) {
                el.source = v;
              } else {
                throw 'Source should be a Validator or Map';
              }
              break;
          }
        });
  }
}

///Check value required, it's invalid for null, empty string, zero
class ValidatorRequired extends Validator {
  ///Default invalid message
  ///it will be used if [message] doesn't has value
  static String defaultMessage = 'Field value is required.';

  @override
  String? _doValidate(dynamic value) {
    if (value == null ||
        (value is String && value.isEmpty) ||
        ((value is int || value is double) && value == 0)) {
      return message ?? defaultMessage;
    } else {
      return null;
    }
  }

  ///Register function to convert from a [Map] data
  static void register() {
    Validator.registered['required'] =
        ValidatorRegister(creator: () => ValidatorRequired());
  }
}

///Check String.length or List.length or number should in a range min, max
///
///value min, max can be null to skip check it
class ValidatorRange extends Validator {
  ///Default invalid message
  ///it will be used if [message] doesn't has value
  static String defaultMessage = 'Field value is not in range [{0} - {1}].';

  ///Minimum value
  dynamic min;

  ///Maximum value
  dynamic max;

  ///Create [Validator] can validate [String] length, [List] length,
  ///or [int] or [double]
  ValidatorRange({this.min, this.max});

  @override
  String? _doValidate(dynamic value) {
    if (value == null || (value is String && value.isEmpty)) return null;
    dynamic v;
    if (value is String || value is List) {
      v = value.length;
    } else {
      v = value;
    }
    if ((min != null && v < min) || (max != null && v > max)) {
      return (message ?? defaultMessage)
          .replaceAll(r'{0}', min.toString())
          .replaceAll(r'{1}', max.toString());
    } else {
      return null;
    }
  }

  ///Register function to convert from a [Map] data
  static void register() {
    Validator.registered['range'] = ValidatorRegister(
        creator: () => ValidatorRange(),
        mapping: (vd, k, v) {
          var el = vd as ValidatorRange;
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
  ///Default invalid message
  ///it will be used if [message] doesn't has value
  static String defaultMessage = 'Field value is not matched {0}.';

  ///Pattern validate matched, can be [String] or [RegExp]
  dynamic pattern;

  ///Create [Validator] can validate matched a [pattern]
  ValidatorPattern([this.pattern]);

  @override
  String? _doValidate(dynamic value) {
    if (pattern == null ||
        value == null ||
        (value is String && value.isEmpty) ||
        (pattern is String && pattern.isEmpty)) return null;
    RegExp reg;
    if (pattern is String) {
      reg = RegExp(pattern);
    } else if (pattern is RegExp) {
      reg = pattern;
    } else {
      throw 'Pattern should be a String or RegExp';
    }
    if (!reg.hasMatch(value)) {
      return (message ?? defaultMessage).replaceAll(r'{0}', pattern.toString());
    } else {
      return null;
    }
  }

  ///Register function to convert from a [Map] data
  static void register() {
    Validator.registered['pattern'] = ValidatorRegister(
        creator: () => ValidatorPattern(),
        mapping: (vd, k, v) {
          var el = vd as ValidatorPattern;
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
  ///Default invalid message
  ///it will be used if [message] doesn't has value
  static String defaultMessage = 'Invalid email';

  @override
  String? _doValidate(dynamic value) {
    if (value == null || value.isEmpty) return null;
    var reg = RegExp(r'^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,3})+$');
    if (!reg.hasMatch(value)) {
      return message ?? defaultMessage;
    } else {
      return null;
    }
  }

  ///Register function to convert from a [Map] data
  static void register() {
    Validator.registered['email'] =
        ValidatorRegister(creator: () => ValidatorEmail());
  }
}

///Check value exist in a source, checked by use method 'contains'
class ValidatorContains extends Validator {
  ///Default invalid message
  ///it will be used if [message] doesn't has value
  static String defaultMessage = 'Field value is invalid';

  ///An object has method 'contains' use to validate.
  ///Eg: [String], [List]
  dynamic source;

  ///Create [Validator] can check value exist in a [source]
  ValidatorContains([this.source]);

  @override
  String? _doValidate(dynamic value) {
    if (value == null ||
        source == null ||
        (source is String && source.isEmpty)) {
      return null;
    }
    if (source.contains(value)) {
      return null;
    } else {
      return message ?? defaultMessage;
    }
  }

  ///Register function to convert from a [Map] data
  static void register() {
    Validator.registered['contains'] = ValidatorRegister(
        creator: () => ValidatorContains(),
        mapping: (vd, k, v) {
          var el = vd as ValidatorContains;
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
  ///Default invalid message
  ///it will be used if [message] doesn't has value
  static String defaultMessage = 'Field value is already in use.';

  ///An object has method 'contains' use to validate.
  ///Eg: [String], [List]
  dynamic source;

  ///Create [Validator] can check value is not exist in [source]
  ValidatorUnique([this.source]);

  @override
  String? _doValidate(dynamic value) {
    if (value == null ||
        source == null ||
        (source is String && source.isEmpty)) {
      return null;
    }
    if (!source.contains(value)) {
      return null;
    } else {
      return message ?? defaultMessage;
    }
  }

  ///Register function to convert from a [Map] data
  static void register() {
    Validator.registered['unique'] = ValidatorRegister(
        creator: () => ValidatorUnique(),
        mapping: (vd, k, v) {
          var el = vd as ValidatorUnique;
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
  ///Default invalid message
  ///it will be used if [message] doesn't has value
  static String defaultMessage = 'Field value is invalid';

  @override
  String? _doValidate(dynamic value) {
    if (value != true) {
      return message ?? defaultMessage;
    } else {
      return null;
    }
  }

  ///Register function to convert from a [Map] data
  static void register() {
    Validator.registered['true'] =
        ValidatorRegister(creator: () => ValidatorTrue());
  }
}

///Check value by a custom function, skip check null already
class ValidatorCustom extends Validator {
  ///Default invalid message
  ///it will be used if [message] doesn't has value
  static String defaultMessage = 'Field value is invalid';

  ///Function used to check value.
  ///Return 'true' if value is valid, else 'false'
  bool Function(dynamic value)? valid;

  ///Create [Validator] can check value by a custom function [valid]
  ValidatorCustom([this.valid]);

  @override
  String? _doValidate(dynamic value) {
    if (value == null || valid == null) return null;
    if (!valid!(value)) {
      return message ?? defaultMessage;
    } else {
      return null;
    }
  }

  ///Register function to convert from a [Map] data
  static void register() {
    Validator.registered['custom'] = ValidatorRegister(
        creator: () => ValidatorCustom(),
        mapping: (vd, k, v) {
          var el = vd as ValidatorCustom;
          switch (k) {
            case 'valid':
              el.valid = v;
              break;
          }
        });
  }
}
