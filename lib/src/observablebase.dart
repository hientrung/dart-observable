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

enum ValidateStatus { pending, invalid, valid }

///A base class for observable should has value and can notify to observers
abstract class ObservableBase<T> {
  final _callbacks = <Function>[];
  StreamController? _streamer;
  final Validator? _validator;
  late Computed<int> _validate;
  String? _error;
  ValidateStatus _status = ValidateStatus.valid;
  bool _selfNotify = false;
  Function? _validateFunc;

  ///Create an observable with validator
  ObservableBase(this._validator) {
    if (_validator != null) {
      var c = 0;
      _validate = Computed<int>(() {
        var v = _validator!.validate(value);
        if (v is Future) {
          if (_status != ValidateStatus.pending) {
            _status = ValidateStatus.pending;
            _validatedNotify();
          }
          (v as Future<String?>).then((s) {
            _error = s;
            _status =
                _error == null ? ValidateStatus.valid : ValidateStatus.invalid;
            _validatedNotify();
          });
        } else {
          if (_error != v) {
            _error = v;
            _status =
                _error == null ? ValidateStatus.valid : ValidateStatus.invalid;
            _validatedNotify();
          }
        }
        return ++c;
      });
      _validate.listen(() {
        _validateFunc = null;
        if (_validate.subcriptions
            .any((element) => element.observable == this)) {
          var sub = _validate.subcriptions
              .firstWhere((element) => element.observable == this);
          _validateFunc = sub.callback;
          _callbacks.remove(_validateFunc);
          _validate.subcriptions.remove(sub);
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
    _addDepend(this);
    return peek;
  }

  ///Add the object [obs] into dependency of current computed context
  void _addDepend(ObservableBase obs) {
    if (Zone.current['ignoreDependencies'] ?? false) return;
    List<ObservableBase>? depends = Zone.current['computedDepends'];
    if (depends != null &&
        !depends.contains(obs) &&
        obs != Zone.current['computed']) depends.add(obs);
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
    //fore update validate status instead waiting computed
    if (_validateFunc != null) {
      _selfNotify = true;
      _executeCallback(_validateFunc!);
      _validate.peek;
      _selfNotify = false;
    }

    if (!hasListener) {
      return;
    }

    for (var cb in _callbacks) {
      _executeCallback(cb);
    }
  }

  ///Error message if value invalid, otherwise is null
  String? get error {
    value;
    return _error;
  }

  ///Manual set error, used to update error message by validate outsite
  void setError(String? msg) {
    if (msg == _error) return;
    _error = msg;
    _status = _error != null ? ValidateStatus.invalid : ValidateStatus.valid;
    //notify ignore validate again
    if (hasValidator) {
      _validatedNotify();
    } else {
      notify();
    }
  }

  void _validatedNotify() {
    if (_selfNotify) return;
    for (var cb in _callbacks) {
      _executeCallback(cb);
    }
  }

  ///Get current status of validating process
  ValidateStatus get validStatus {
    value;
    return _status;
  }

  ///Validate status
  bool get valid => error == null && validStatus == ValidateStatus.valid;

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
    if (hasValidator) {
      _validate.dispose();
    }
    _callbacks.clear();
  }

  @override
  String toString() {
    return '${runtimeType.toString()}(${peek.toString()})';
  }

  T call() => value;
}

///Class used to mixin with observable can set value
mixin ObservableWritable<T> on ObservableBase<T> {
  ///Set current value
  set value(T value);
}
