part of tic_development;

Future<String> findFileFirstMatch(String path, String filename,
    {List<String> ignoreDirs}){

  var completer = new Completer();
  var found = null;
  Directory dir = new Directory(path);
  List<FileSystemEntity> lister = dir.listSync(recursive: true,
      followLinks: false);

  for(int i=0; i<lister.length; i++){
    final file = lister[i];
    if(pathos.basename(file.path) == filename && file is !Directory){
      completer.complete(file.path);
      break;
    } else if(i == lister.length -1){
      completer.complete(null);
    }
  }
  return completer.future;
}
