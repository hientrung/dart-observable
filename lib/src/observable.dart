import 'observablebase.dart';

///A generic observable for a value
class Observable<T> extends ObservableBase<T> {
  ///Create new observable with init value (optional)
  Observable([T val]) : super() {
    _value = val;
    _oldValue = val;
  }

  T _oldValue;
  T _value;

  @override
  T get oldValue => _oldValue;

  @override
  T get peek => _value;

  set value(T v) {
    if (_value == v) return;
    _oldValue = _value;
    _value = v;
    notify();
  }
}
