# ObserverWidget

Here is example how to create a widget listen on observable in Flutter

```dart
import 'package:flutter/widgets.dart';
import 'package:obsobject/obsobject.dart';

///An observer of observable to update widget
class ObserverWidget<T> extends StatefulWidget {
  final Widget Function(BuildContext context, T value) builder;
  final ObservableBase<T> observable;
  const ObserverWidget(
      {Key key, @required this.observable, @required this.builder})
      : assert(observable != null),
        assert(builder != null),
        super(key: key);

  @override
  State<StatefulWidget> createState() => _ObserverWidgetState();
}

class _ObserverWidgetState<T> extends State<ObserverWidget<T>> {
  T value;
  Subscription _subscription;

  @override
  Widget build(BuildContext context) => widget.builder(context, value);

  @override
  void initState() {
    super.initState();
    value = widget.observable.value;
    _subscribe();
  }

  @override
  void didUpdateWidget(ObserverWidget<T> oldWidget) {
    //print('update');
    super.didUpdateWidget(oldWidget);
    if (oldWidget.observable != widget.observable) {
      value = widget.observable.value;
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    _unsubscribe();
    _subscription = widget.observable.changed((T val) {
      setState(() {
        value = val;
      });
    });
  }

  void _unsubscribe() {
    _subscription?.dispose();
  }
}
```
