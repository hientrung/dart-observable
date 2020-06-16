///Canncelable a callback function for Future.
///Ofcouse, we can not cancel a Future, this is just ignore call callback [then]
///
///Future return null if it's canceled
class CancelableThen<T> {
  ///Future listen on
  final Future<T> future;

  ///Future.then callback
  final dynamic Function(T value) then;
  bool _isCancel = false;
  bool _isComplete = false;

  ///Create a async function can cancel
  CancelableThen({this.future, this.then})
      : assert(future != null && then != null) {
    future.then((value) {
      if (!_isCancel) {
        var v = then(value);
        _isComplete = true;
        return v;
      } else {
        return null;
      }
    });
  }

  ///Check current status is canceled or not
  bool get isCancel => _isCancel;

  ///Check current status is completed or not
  bool get isComplete => _isComplete;

  ///Cancel do function callback
  void cancel() {
    _isCancel = true;
  }
}
