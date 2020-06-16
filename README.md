# Obsobject
An observable, computed objects written in Dart with buit-in validation

# Install 
```yaml
dependencies:  
    obsobject: ^1.0.0
```
# Observable
An object will notify to all listeners/observers after its value changed.  

Example:
```dart
var a = Observable('test');
a.listen(() {
    print(a.value);
});
a.value = 'First test';
```
Output result:  
test  
First test


# Computed
It's an observable too, but its value will be calculated from other observable object.  
It's smart to know which observable object that it's depend on, and auto rebuild value when value of dependencies has changed.  

Example:  
```dart
var a = Observable(false);
var b = Observable(1);
var c = Computed(() => a.value ? b.value*10 : 0);

print(c.value); //result 0, depend on only 'a';
b.value = 2;
print(c.value); //result 0, depend on only 'a'
print(c.rebuildCount); //result 1, it is not recalculate;
a.value=true;
print(c.value);//result 20, depend on 'a', 'b'
```

Computed object is only recalculate if there are listeners on it or when access to its value.  
And the calculation is a asyn process, so observable can change value many times, but Computed just run one

Example:
```dart
var a = Observable(0);
var b = Computed(() => a.value);
b.changed(()=>print(b.value));
for(var i=0; i<1000; i++) a.value=i;
print(b.rebuildCount); //result 1
```  

Computed is just give readonly value, thus there are a object Commission used to read+write value

# Validator
Built-in validate:  
- required: value can not null, empty string, zero
- email: value must be valid email address
- range: check number value, string length, array length
- pattern: check string matched RegExp
- contains: value must in array
- unique: value not exist in array
- true: value must be true
- custom: check value by a custom function
- async: check value by a async function
- all: combine and check all validators
- least: combine and check all validators but it stopped at the first invalid
- not: negative a validator

Observable has a property **isValid**, it's an observable value of validation staus, and it also has features:
- condition: used to check something before excute validate
- message: custom message, default message, support for localize
- And easy way to custom or extends new validation

Example:
```dart
//use with Validator....
var email = Observable('')
            ..isValid.validator = 
                ValidatorLeast([ValidatorRequired(), ValidatorEmail()]);

//use with Map data config
var email = Observable('')
            ..isValid.validator = 
                Validator.convert({
'least': {
    'validators': {'required': 'Email is required', 'email': true}
}
                });
//current status
print(email.isValid.value);
//current invalid message
print(email.isValid.message);
//listen on validation
email.isValid.listen(() {
//do something
});
```

### View more details in [Wiki](https://github.com/hientrung/dart-observable/wiki), [API](https://pub.dev/documentation/obsobject/latest/)