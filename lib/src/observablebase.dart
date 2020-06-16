import 'dart:async';
import 'validator.dart';

///A listener on an observable, it can close listen in later
class Subscription {
  ///Current observable listening
  final ObservableBase observable;

  ///Function will be called
  final void Function() callback;

  ///Create a subscription
  Subscription(this.observable, this.callback);

  ///close listen on observable
  void dispose() {
    observable._callbacks.remove(callback);
  }
}

///A base class for observable should has value and can notify to observers
abstract class ObservableBase<T> {
  final _callbacks = <void Function()>[];
  StreamController _streamer;
  ObservableValidator _isValid;

  ///The old value if has change
  T get oldValue;

  ///The current value but ignore check depend on in Computed context
  T get peek;

  ///The current value, if value called in a computed context,
  ///it will set Computed is depend on this
  T get value {
    if (Zone.current['ignoreDependencies'] ?? false) return peek;
    List<ObservableBase> depends = Zone.current['computedDepends'];
    if (depends != null &&
        !depends.contains(this) &&
        this != Zone.current['computed']) depends.add(this);
    return peek;
  }

  ///Listen on value changed then run callback,
  ///it also run callback in first time
  Subscription listen(void Function() callback) {
    callback();
    return changed(callback);
  }

  ///Listen on value changed then run callback
  Subscription changed(void Function() callback) {
    _callbacks.add(callback);
    return Subscription(this, callback);
  }

  ///Notify to observers are listen on this observable
  void notify() {
    for (var cb in _callbacks) {
      cb();
    }
  }

  ///Create a stream to listen value changes,
  ///it should call dispose to close stream when it is no longer needed
  Stream get stream {
    if (_streamer == null) {
      _streamer = StreamController.broadcast(sync: true);
      listen(() => _streamer.add(peek));
    }
    return _streamer.stream;
  }

  ///Check there are listeners on this observable
  bool get hasListener => _callbacks.isNotEmpty;

  ///Check value has updated
  bool get modified => peek != oldValue;

  ///An observable keep current status validation
  ObservableValidator get isValid {
    _isValid ??= ObservableValidator(this);
    return _isValid;
  }

  ///Close stream (if used) and all listeners on this observable
  void dispose() {
    _streamer?.close();
    _streamer = null;
    _isValid?.dispose();
    _callbacks.clear();
  }
}

///Handle valid state for an observable
class ObservableValidator extends ObservableBase<bool> {
  Validator _validator;

  ///Current observable use validate
  final ObservableBase observable;
  bool _oldValue = true;
  bool _value = true;
  String _oldMessage = '';
  String _message = '';
  bool _hasChanged = true;
  dynamic _oldObsValue;

  ///Create a observable's validation
  ObservableValidator(this.observable)
      : assert(observable != null),
        super() {
    //insert at top list, so it can run update valid status
    //before other listeners called
    observable._callbacks.insert(0, _observableChanged);
    _oldObsValue = observable.peek;
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

  ///Get current validator used to validate observable's value
  Validator get validator => _validator;

  ///Set current validator used to validate observable's value
  ///It also force update, notify current status validation
  set validator(Validator val) {
    if (_validator == val) return;
    _validator = val;
    _hasChanged = true;
    if (hasListener) _update();
    _notifyObservable();
  }

  ///A current invalid message, it dosen't has null, just empty or not
  String get message {
    //check computed value
    if (!_hasChanged && _oldObsValue != observable.peek) _hasChanged = true;
    _update();
    return _message ?? '';
  }

  ///update current valid status for observable
  ///it can still invalid but with difference message
  void _update() {
    if (!_hasChanged || _validator == null) return;
    _oldObsValue = observable.peek;
    _hasChanged = false;
    String s;
    runZoned(() {
      s = _validator.validate(observable.peek) ?? '';
    }, zoneValues: {'validatorCallback': _validatorCallback});
    if (s != _message) {
      _oldMessage = _message;
      _message = s;
      _oldValue = _value;
      _value = _message.isEmpty;
      notify();
    }
  }

  ///Function callback by ValidatorAsync, they're communicate by Zone values
  void _validatorCallback(String msg) {
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
  Subscription listen(void Function() callback) {
    _update();
    return super.listen(callback);
  }

  ///force all listener in observable there are change in isValid,
  ///due to it can listen in observable instead isValid
  void _notifyObservable() {
    for (var p in observable._callbacks) {
      if (p != _observableChanged) {
        p();
      }
    }
  }

  @override
  void dispose() {
    _callbacks.remove(_observableChanged);
    super.dispose();
  }
}
