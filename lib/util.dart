library util;
import 'dart:async';
import 'dart:io';

Future<String> findFile(String path, String filename, {List<String> ignoreDirs}){
  var completer = new Completer();
  var found = null;
  Directory dir = new Directory(path);
  DirectoryLister lister = dir.list();
  lister.onDir = (dir){
    var p = new Path(dir);
    if(dir.startsWith(path) && ignoreDirs != null && ignoreDirs.contains(p.filename))
      findFile(dir, filename)
        .catchError((e)=>print(e))
        .then((f){
        try{
          completer.complete(f);
        } on StateError {}
      });
  };

  lister.onFile = (file){
    if(file.endsWith(filename)){
      found = file;
    }
  };

  lister.onDone = (done) {
    if(found != null){
      completer.complete(found);
    }
  };
  return completer.future;
}
