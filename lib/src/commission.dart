import 'computed.dart';
import 'observablebase.dart';

///This class inherit from Computed
///and provide a function to set property 'value'
//Simple to use a Computed similar as an Observable
class Commission<T> extends Computed<T> with ObservableWritable<T> {
  ///Function used to compute value
  final T Function() reader;

  ///Function used to update value
  final void Function(T val) writer;

  ///Create a computed can writeable
  Commission({this.reader, this.writer})
      : assert(reader != null),
        assert(writer != null),
        super(reader);

  @override
  void set value(T val) {
    if (val != super.value) writer(val);
  }
}
