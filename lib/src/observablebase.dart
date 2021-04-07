import 'dart:async';
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
  ObservableValidator? _isValid;

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
    for (var cb in _callbacks) {
      _executeCallback(cb);
    }
  }

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
  bool get hasListener =>
      (_isValid == null && _callbacks.isNotEmpty) ||
      (_isValid != null && (_isValid!.hasListener || _callbacks.length > 1));

  ///Check value has updated
  bool get modified => peek != oldValue;

  ///An observable keep current status validation
  ObservableValidator get isValid {
    _isValid ??= ObservableValidator(this);
    return _isValid!;
  }

  ///Check has using validate value
  bool get hasValidator => _isValid != null;

  ///Close stream (if used) and all listeners on this observable
  void dispose() {
    _streamer?.close();
    _streamer = null;
    _isValid?.dispose();
    _callbacks.clear();
  }

  @override
  String toString() {
    return '${runtimeType.toString()}(${peek.toString()})';
  }
}

///Handle valid state for an observable
class ObservableValidator extends ObservableBase<bool> {
  Validator? _validator;

  ///Current observable use validate
  final ObservableBase observable;
  bool _oldValue = true;
  bool _value = true;
  String _oldMessage = '';
  String _message = '';
  bool _hasChanged = true;
  dynamic _oldObsValue;

  ///Create a observable validation
  ObservableValidator(this.observable) : super() {
    //insert at top list, so it can run update valid status
    //before other listeners called
    observable._callbacks.insert(0, _observableChanged);
  }

  void _observableChanged() {
    _hasChanged = true;
    if (hasListener) _update();
  }

  @override
  bool get oldValue => _oldValue;

  @override
  bool get peek {
    //check computed value
    if (!_hasChanged && _oldObsValue != observable.peek) _hasChanged = true;
    _update();
    return _value;
  }

  ///Get current validator used to validate observable value
  Validator? get validator => _validator;

  ///Set current validator used to validate observable value
  ///It also force update, notify current status validation
  set validator(Validator? val) {
    if (_validator == val) return;
    _validator = val;
    _hasChanged = true;
    if (hasListener) _update();
    _notifyObservable();
  }

  ///A current invalid message, it doesn't has null, just empty or not
  String get message {
    //check computed value
    if (!_hasChanged && _oldObsValue != observable.peek) _hasChanged = true;
    _update();
    return _message;
  }

  ///update current valid status for observable
  ///it can still invalid but with difference message
  void _update() {
    if (!_hasChanged || _validator == null) return;
    _oldObsValue = observable.peek;
    _hasChanged = false;
    late String? s;
    runZoned(() {
      s = _validator!.validate(observable.peek) ?? '';
    }, zoneValues: {'validatorCallback': _validatorCallback});
    if (s != _message) {
      _oldMessage = _message;
      _message = s ?? '';
      _oldValue = _value;
      _value = _message.isEmpty;
      notify();
    }
  }

  ///Function callback by ValidatorAsync, they're communicate by Zone values
  void _validatorCallback(String? msg) {
    //wait for other task changed finish
    //print('Validator callback: $msg');
    var s = msg ?? '';
    if (s != _message) {
      _oldMessage = _message;
      _message = s;
      _oldValue = _value;
      _value = _message.isEmpty;
      notify();
      _notifyObservable();
    }
  }

  @override
  bool get modified => _oldValue != _value || _oldMessage != _message;

  @override
  Subscription listen(Function callback) {
    _update();
    return super.listen(callback);
  }

  ///force all listener in observable
  ///there are change in isValid by async validate,
  ///due to it can listen in observable instead isValid
  void _notifyObservable() {
    for (var p in observable._callbacks) {
      if (p != _observableChanged) {
        _executeCallback(p);
      }
    }
  }

  @override
  void dispose() {
    _callbacks.remove(_observableChanged);
    super.dispose();
  }
}

///Class used to mixin with observable can set value
mixin ObservableWritable<T> on ObservableBase<T> {
  ///Set current value
  set value(T value);
}
