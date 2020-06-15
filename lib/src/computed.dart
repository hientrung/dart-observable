import 'dart:async';
import 'observablebase.dart';

///Auto compute values from some observable
class Computed<T> extends ObservableBase<T> {
  T _oldValue;
  T _value;
  var _rebuildCount = 0;
  var _pause = false;

  final _depends = <ObservableBase>[];
  final _subscriptions = <Subscription>[];
  var _hasChanged = true;
  final T Function() calculator;
  StreamSubscription _subRebuild;
  final void Function(Object error, StackTrace stack) onError;

  ///Only notify change and rebuild after a number period (millisecond)
  int rateLimit;

  Computed(this.calculator, {this.rateLimit = 0, this.onError})
      : assert(rateLimit >= 0),
        assert(calculator != null),
        super();

  @override
  T get oldValue => _oldValue;

  @override
  T get peek {
    _rebuild();
    return _value;
  }

  @override
  Subscription listen(void Function() callback) {
    _rebuild();
    return super.listen(callback);
  }

  ///calculate to get value and depend observables
  void _rebuild() {
    if (!_hasChanged) return;
    _rebuildCount++;
    //print('computed run');
    //clear old depends
    _reset();

    //calculate with zone to get depends
    //Future/Stream async are running in zone context too
    //so it can get dependencies but it don't get value (it return already)
    var val = runZonedGuarded(calculator, (err, stack) {
      if (onError != null) onError(err, stack);
    }, zoneValues: {'computedDepends': _depends, 'computed': this});
    if (val != _value) {
      _oldValue = _value;
      _value = val;
    }
    //set false here to avoid access this computed again in listen
    _hasChanged = false;

    //new subscribes, it there are no depends then it nerver run again
    for (var dep in _depends)
      _subscriptions.add(dep.changed(() {
        _hasChanged = true;
        //force rebuild for observer
        if (hasListener) {
          //use async rebuild with rate
          _subRebuild = Future.delayed(Duration(milliseconds: rateLimit))
              .asStream()
              .listen((event) {
            _rebuild();
            notify();
          });
        }
      }));
  }

  void _reset() {
    if (_subRebuild != null) {
      _subRebuild.cancel();
      _subRebuild = null;
    }
    for (var sub in _subscriptions) sub.close();
    _depends.clear();
    _subscriptions.clear();
  }

  ///Number of observable which this object depend on
  int get dependCount => _depends.length;

  ///Number times of calculator was called
  int get rebuildCount => _rebuildCount;

  ///Tempory pause rebuild value if there are an observable changed
  void pause() {
    if (_pause) return;
    _pause = true;
    _hasChanged = false;
    _reset();
  }

  ///Resume and rebuild value after paused
  void resume() {
    if (!_pause) return;
    _hasChanged = true;
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
      for (var d in depends) d.value;
      return ignoreDependencies(callback);
    });
  }
}
