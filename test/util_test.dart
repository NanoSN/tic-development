
import 'dart:async';
import 'dart:io';

import 'package:unittest/unittest.dart';
import 'package:unittest/vm_config.dart';
import 'package:tic_development/util.dart';

void main(){
  useVMConfiguration();
  group( 'findFileFirstMatch', (){

    test('not null', () {
      findFileFirstMatch('.', 'test').then(expectAsync1( (e) {
          expect(e, isNotNull);
        }));
    });
    
    test('not a directory', () {
      findFileFirstMatch('.', 'test').then(expectAsync1( (e) {
          expect(FileSystemEntity.isDirectorySync(e), isFalse);
        }));
    });

    test('file exists', () {
      findFileFirstMatch('.', 'test').then(expectAsync1( (e) {
          expect(FileSystemEntity.isFileSync(e), isTrue);
        }));
    });

    test('not found (null)', () {
      findFileFirstMatch('.', 'testing123').then(expectAsync1( (e) {
          expect(e, isNull);
        }));
    });
    
  });
}
