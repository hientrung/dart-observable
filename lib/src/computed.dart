import 'dart:async';

import 'observablebase.dart';
import 'validator.dart';

///Auto compute values from some observable by async update function
class Computed<T> extends ObservableBase<T> {
  late T _oldValue;
  late T _value;
  var _rebuildCount = 0;
  var _pause = false;

  final _depends = <ObservableBase>[];
  final _subscriptions = <Subscription>[];
  var _hasChanged = true;
  var _running = false;

  ///Function used to calculate value
  final FutureOr<T> Function() calculator;
  Timer? _asyncRebuild;
  Timer? _doRebuild;

  ///Function called if there are error in procession [calculator]
  final void Function(Object error, StackTrace stack)? onError;

  ///Only notify change and rebuild after a number period (millisecond)
  int rateLimit;

  ///Create a observable that calculate value base on other observables
  Computed(this.calculator,
      {this.rateLimit = 0, this.onError, Validator? validator})
      : assert(rateLimit >= 0),
        super(validator);

  @override
  T get oldValue {
    if (_rebuildCount == 0) {
      throw 'The computation function didn\'t run, maybe pausing';
    }
    return _oldValue;
  }

  @override
  T get peek {
    _rebuild();
    if (_rebuildCount == 0) {
      throw 'The computation function didn\'t run, maybe pausing';
    }
    if (_running) {
      throw 'The computation function is running. You can not access value';
    }
    return _value;
  }

  @override
  Subscription listen(Function callback) {
    final s = super.changed(callback);
    _rebuild();
    return s;
  }

  @override
  Subscription changed(Function callback) {
    final s = super.changed(callback);
    _rebuild(true);
    return s;
  }

  ///calculate to get value and depend observables
  void _rebuild([bool skipNotify = false]) {
    if (_pause || !_detectChanged()) return;
    _rebuildCount++;
    //print('computed run');
    //clear old depends
    _reset();

    //calculate with zone to get depends
    //Future/Stream async are running in zone context too
    //so it can get dependencies but it don't get value (it return already)
    var ok = true;
    _running = true;
    var val = runZonedGuarded(calculator, (err, stack) {
      ok = false;
      if (onError != null) {
        onError!(err, stack);
      } else {
        print(err);
      }
    }, zoneValues: {'computedDepends': _depends, 'computed': this});
    if (!ok) return;

    if (val is Future) {
      var v = val as Future<T>;
      v.then((_v) => _setValue(_v, skipNotify));
    } else {
      _setValue(val as T, skipNotify);
    }
  }

  void _setValue(T val, bool skipNotify) {
    //set false here to avoid access this computed again in listen
    _hasChanged = false;
    _running = false;

    //new subscribes, it there are no depends then it never run again
    for (var dep in _depends) {
      _subscriptions.add(dep.changed(() {
        _hasChanged = true;
        //force rebuild for observer
        if (hasListener && _asyncRebuild == null && !_pause) {
          //use async rebuild with rate
          //_asyncRebuild avoid loop in sync progress
          //that there are many depends changed toghether
          _asyncRebuild = Timer(Duration.zero, () {
            _doRebuild?.cancel();
            _doRebuild = Timer(Duration(milliseconds: rateLimit), _rebuild);
          });
        }
      }));
    }

    //update value
    if (rebuildCount == 1) {
      _oldValue = val;
      _value = val;
      if (!skipNotify) notify();
    } else if (val != _value) {
      _oldValue = _value;
      _value = val;
      notify();
    }
  }

  bool _detectChanged() {
    if (_hasChanged) return true;
    return _depends
        .any((element) => (element is Computed) && element._detectChanged());
  }

  void _reset() {
    _asyncRebuild?.cancel();
    _asyncRebuild = null;
    _doRebuild?.cancel();
    _doRebuild = null;
    for (var sub in _subscriptions) {
      sub.dispose();
    }
    _depends.clear();
    _subscriptions.clear();
  }

  ///Number of observable which this object depend on
  int get dependCount => _depends.length;

  ///Number times of calculator was called
  int get rebuildCount => _rebuildCount;

  ///The current subscription listen on to update computed
  List<Subscription> get subcriptions => _subscriptions;

  ///Temporary pause rebuild value if there are an observable changed
  void pause() {
    if (_pause) return;
    _pause = true;
    _reset();
  }

  ///Resume and rebuild value after paused
  void resume() {
    if (!_pause) return;
    _pause = false;
    _rebuild();
  }

  ///Current status rebuild value is pause or not
  bool get isPaused => _pause;

  ///Remember close a computed if you don't need it to avoid it auto rebuild
  @override
  void dispose() {
    _reset();
    super.dispose();
  }

  ///Ignore dependency all observables in callback for current Computed
  static T ignoreDependencies<T>(T Function() callback) {
    return runZoned(callback, zoneValues: {'ignoreDependencies': true});
  }

  ///Run a task depends on specific observables
  static Computed<T> task<T>(
      List<ObservableBase> depends, T Function() callback) {
    return Computed(() {
      //listen all
      for (var d in depends) {
        d.value;
      }
      return ignoreDependencies(callback);
    });
  }

  ///Create a computed used to listen on specific observable
  static Computed<int> version(List<ObservableBase> depends) {
    var ver = 0;
    return Computed(() {
      //listen all
      for (var d in depends) {
        d.value;
      }
      return ++ver;
    });
  }
}
