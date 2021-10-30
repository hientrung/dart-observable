import 'observablebase.dart';
import 'validator.dart';

///A generic observable for a value
class Observable<T> extends ObservableBase<T> with ObservableWritable<T> {
  ///Create new observable with init value (optional)
  Observable(T val, {Validator? validator}) : super(validator) {
    _value = val;
    _oldValue = val;
  }

  late T _oldValue;
  late T _value;

  @override
  T get oldValue => _oldValue;

  @override
  T get peek => _value;

  @override
  set value(T v) {
    if (_value == v) return;
    _oldValue = _value;
    _value = v;
    notify();
  }
}
