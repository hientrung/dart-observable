import 'dart:async';

import 'computed.dart';
import 'validator.dart';

///A listener on an observable, it can close listen in later
class Subscription {
  ///Current observable listening
  final ObservableBase observable;

  ///Function will be called
  final Function callback;

  ///Create a subscription
  Subscription(this.observable, this.callback);

  ///close listen on observable
  void dispose() {
    observable._callbacks.remove(callback);
  }
}

///A base class for observable should has value and can notify to observers
abstract class ObservableBase<T> {
  final _callbacks = <Function>[];
  StreamController? _streamer;
  final Validator? _validator;
  Computed<String>? _validate;
  String _error = '';
  bool _selfNotify = false;

  ///Create an observable with validator
  ObservableBase(this._validator) {
    if (_validator != null) {
      _validate = Computed(_doValidate);
      _validate!.listen((String v) {
        if (v != _error) {
          _error = v;
          if (_selfNotify) {
            _selfNotify = false;
          } else {
            _notifyStatus();
          }
        }
      });
    }
  }

  ///The old value if has change
  T get oldValue;

  ///The current value but ignore check depend on in Computed context
  T get peek;

  ///The current value, if value called in a computed context,
  ///it will set Computed is depend on this
  T get value {
    if (Zone.current['ignoreDependencies'] ?? false) return peek;
    List<ObservableBase>? depends = Zone.current['computedDepends'];
    if (depends != null &&
        !depends.contains(this) &&
        this != Zone.current['computed']) depends.add(this);
    return peek;
  }

  ///Listen on value changed then run callback,
  ///it also run callback in first time
  ///
  ///Function callback can has parameters
  ///- none
  ///- one: the current value
  ///- two: the current, old value
  Subscription listen(Function callback) {
    _executeCallback(callback);
    return changed(callback);
  }

  ///Listen on value changed then run callback
  ///
  ///Function callback can has parameters
  ///- none
  ///- one: the current value
  ///- two: the current, old value
  Subscription changed(Function callback) {
    _callbacks.add(callback);
    return Subscription(this, callback);
  }

  ///Notify to observers are listen on this observable
  void notify() {
    if (!hasListener) {
      return;
    }
    if (hasValidator) _selfNotify = true;
    for (var cb in _callbacks) {
      _executeCallback(cb);
    }
  }

  ///Error message if value invalid
  String get error {
    if (!hasValidator) return '';
    //mark it depend in Computed context
    _validate!.value;
    return _error;
  }

  ///Manual set error
  void setError(String msg) {
    if (msg == _error) return;
    _error = msg;
    _notifyStatus();
  }

  String _doValidate() {
    return _validator!.validate(value);
  }

  void _notifyStatus() {
    if (!hasListener) {
      return;
    }
    for (var cb in _callbacks) {
      if (cb != _doValidate) _executeCallback(cb);
    }
  }

  ///Validate status
  bool get valid => error.isEmpty;

  ///execute callback function, it can has 0, 1, 2 parameters
  void _executeCallback(Function cb) {
    if (cb is Function()) {
      cb();
    } else {
      if (cb is Function(T)) {
        cb(peek);
      } else {
        if (cb is Function(T, T)) {
          cb(peek, oldValue);
        } else {
          throw 'Callback function is invalid parameters';
        }
      }
    }
  }

  ///Create a stream to listen value changes,
  ///it should call [dispose] to close stream when it is no longer needed
  Stream get stream {
    if (_streamer == null) {
      _streamer = StreamController.broadcast(sync: true);
      listen(() => _streamer!.add(peek));
    }
    return _streamer!.stream;
  }

  ///Check there are listeners on this observable
  bool get hasListener => _callbacks.isNotEmpty;

  ///Check value has updated
  bool get modified => peek != oldValue;

  ///Check has using validate value
  bool get hasValidator => _validator != null;

  ///Close stream (if used) and all listeners on this observable
  void dispose() {
    _streamer?.close();
    _streamer = null;
    _callbacks.clear();
  }

  @override
  String toString() {
    return '${runtimeType.toString()}(${peek.toString()})';
  }
}

///Class used to mixin with observable can set value
mixin ObservableWritable<T> on ObservableBase<T> {
  ///Set current value
  set value(T value);
}
