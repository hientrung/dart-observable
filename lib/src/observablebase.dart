import 'dart:async';
import 'validator.dart';

///A listener on an observable, it can close listen in later
class Subscription {
  final ObservableBase observable;
  final void Function() callback;
  Subscription(this.observable, this.callback);

  //close listen on observable
  close() {
    observable._callbacks.remove(callback);
  }
}

///A base class for observable should has value and can notify to observers
abstract class ObservableBase<T> {
  var _callbacks = <void Function()>[];
  StreamController _streamer;
  Validator _validator;
  ObservableValidator _isValid;

  ///The old value if has change
  T get oldValue;

  ///The current value but ignore check depend on in Computed context
  T get peek;

  ///The current value, if value called in a computed context, it will set Computed is depend on this
  T get value {
    if (Zone.current['ignoreDependencies'] ?? false) return peek;
    List<ObservableBase> depends = Zone.current['computedDepends'];
    if (depends != null &&
        !depends.contains(this) &&
        this != Zone.current['computed']) depends.add(this);
    return peek;
  }

  ///Listen on value changed then run callback, it also run callback in first time
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
    for (var cb in _callbacks) cb();
  }

  ///Create a stream to listen value changes, it should call dispose to close stream when not needed
  Stream get stream {
    if (_streamer == null) {
      _streamer = StreamController.broadcast(sync: true);
      listen(() => _streamer.add(peek));
    }
    return _streamer.stream;
  }

  ///Check there are listeners on this observable
  bool get hasListener => _callbacks.length > 0;

  ///Check value has updated
  bool get modified => peek != oldValue;

  ///Get current validator used to validate value
  Validator get validator => _validator;

  ///Set validator used to validate value, check its status in isValid
  set validator(Validator v) {
    if (_validator == v) return;
    _validator = v;
    _isValid?.validator = _validator;
  }

  ///An observable keep current status validation
  ObservableValidator get isValid {
    if (_isValid == null)
      _isValid = ObservableValidator(this)..validator = _validator;
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
  final ObservableBase observable;
  bool _oldValue;
  bool _value;
  String _oldMessage;
  String _message;
  bool _hasChanged = true;

  ObservableValidator(this.observable)
      : assert(observable != null),
        super() {
    //insert at top list, so it can run update valid status before other listeners
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
    _update();
    return _value;
  }

  ///Get current validator used to validate observable's value
  Validator get validator => _validator;

  ///Set current validator used to validate observable's value
  ///It also forece update current status validation
  set validator(Validator val) {
    _validator = val;
    _hasChanged = true;
    _update();
  }

  ///A current invalid message, it dosen't has null, just empty or not
  String get message {
    _update();
    return _message ?? '';
  }

  ///update current valid status for observable
  ///it can still invalid but with difference message
  void _update() {
    if (!_hasChanged || _validator == null) return;
    _hasChanged = false;
    _oldMessage = _message;
    runZoned(() {
      _message = _validator.validate(observable.peek) ?? '';
    }, zoneValues: {'validatorCallback': _validatorCallback});
    _oldValue = _value;
    _value = _message.isEmpty;
    if (hasListener) notify();
  }

  ///Function callback by ValidatorAsync, they're communicate by Zone values
  void _validatorCallback(String msg) {
    //wait for other task changed finish
    //print('Validator callback: $msg');
    _oldMessage = _message;
    _message = msg ?? '';
    _oldValue = _value;
    _value = _message.isEmpty;
    if (hasListener) notify();
    //force all listener in observable there are change in isValid, due to it can listen in observable instead isValid
    for (var p in observable._callbacks) if (p != _observableChanged) p();
  }

  @override
  bool get modified => _oldValue != _value || _oldMessage != _message;

  @override
  Subscription listen(void Function() callback) {
    _update();
    return super.listen(callback);
  }

  @override
  void dispose() {
    _callbacks.remove(_observableChanged);
    super.dispose();
  }
}
