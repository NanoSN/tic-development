library util;
import 'dart:async';
import 'dart:io';

Future<String> findFile(String path, String filename, {List<String> ignoreDirs}){
  var completer = new Completer();
  var found = null;
  Directory dir = new Directory(path);
  List<FileSystemEntity> lister = dir.listSync();
  for(final file in lister){
    var p = new Path(file.path);
    if(file is Directory
        && file.path.startsWith(path)
        && ignoreDirs != null
        && ignoreDirs.contains(p.filename)){
      findFile(file.path, filename)
        .catchError((e)=>print(e))
        .then((f){
        try{
          completer.complete(f);
        } on StateError {}
      });
    } else {
      print(file.path);
      if(file.path.endsWith(filename)){
        completer.complete(file.path);
      }
    }
  }
  return completer.future;
}
