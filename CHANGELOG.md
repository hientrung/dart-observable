# CHANGE LOG

## 1.2.3

Add callable class.

```dart
final a = Observable(0);
a(); //similar a.value
```

## 1.2.2

Add rateLimit for class Observable

## 1.2.1

Fix bug validate observable value

## 1.2.0

Fix bug nested computed  
Remove `CancelableThen` and use `Timer` object  
Rewrite observable validation thus it can depend on other observable, remove `isValid` and changed to computed objects `valid`, `error`. We also can `setError` to mark observable invalid. When object changed valid, error status, then it also call notify change  
Remove validation async since it require setup UI while validating depend on development context

## 1.1.1

Improve performance rebuild Computed by use one Future instead create many CancelableThen

## 1.1.0

Update to support null safety

## 1.0.6

Add base class ObservableWritable used mixin for Observable, Commission
Add property hasValidator used to check has validate value
Fix bug notify in Computed
Export CancelableThen
Check hasListener before execute callbacks

## 1.0.5

Do not recompute Computed has isValid but there are no listener

## 1.0.4

Add function toString

## 1.0.3

Support listener function with parameters  
Reuse CancelableThen in ObservableValidator  
Spell check

## 1.0.2

Update follow dart analyze
Add example widget in Flutter

## 1.0.1

Update follow publish suggestions

## 1.0.0

First release
