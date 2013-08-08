library handlers;

import 'dart:async';
import 'dart:io';
import '../util.dart';
import 'package:web_ui/component_build.dart' as web_ui;
import 'package:mimetypes/mimetypes.dart';

class ClientFileHandler {
  String path;

  ClientFileHandler(this.path);

  void onRequest(HttpRequest req, HttpResponse res) {
    print('${req.method} ${req.uri.path}');
    var path = '${this.path}${req.uri.path}';
    new ClientFileServer(req, res)._handleSendFile(path);
  }
}

class ClientFileServer {
  HttpRequest request;
  HttpResponse response;
  String path;

  ClientFileServer(this.request, this.response);
 
  void _handleSendFile(String path, [String mimetype]){
    var result = ClientFileInfo.getInfo(path, mimetype);
    result
      .then(this._sendFile)
      .catchError((ex) => this._404(ex));
    
  }

  void _sendFile(ClientFileInfo info){
    var res = this.response;
    var headers = res.headers;

    if(info.lastModified == request.headers.ifModifiedSince){
      res.statusCode = HttpStatus.NOT_MODIFIED;
      res.contentLength = 0;
      res.close();
      return;
    }

    res.contentLength = info.length;
    headers.contentType = new ContentType.fromString(info.mimetype);
    headers.set(HttpHeaders.LAST_MODIFIED, info.lastModified);

    if(request.method == 'HEAD'){
      res.contentLength = 0;
      response.close();
      return;
    }
    info.file.openRead().pipe(response);
  }

  bool _404(Exception ex){
    print(ex);
    this.response.statusCode = HttpStatus.NOT_FOUND;
    this.response.write(ex.toString());
    this.response.close();
    return true;
  }
}

class ClientFileInfo {
  File file;
  String path;
  String mimetype;
  Date lastModified;
  int length;

  static Future<ClientFileInfo> getInfo(String path, [String mimetype]){
    var info = new ClientFileInfo();
    if(?mimetype) info.mimetype = mimetype;
    info.path = path;

    var exists = info._exists(info);
    return exists.then(info._getLastModified)
      .then(info._getLength)
      .then(info._getMimeType);
  }

  Future<ClientFileInfo> _exists(ClientFileInfo info){
    var completer = new Completer();
    File file = new File(info.path);
    file.exists().then((bool exists){
      if(exists){
        info.file = file;
        completer.complete(info);
      } else {
        completer.completeError(
            new Exception('File ${info.path} does not exist'));
      }
    });
    return completer.future;
  }

  Future<ClientFileInfo> _getLastModified(ClientFileInfo info){
    var completer = new Completer();

    //Sanity check
    if(info.file == null)
      completer.completeError(new Exception('file not init'));

    file.lastModified().then((Date date){
      info.lastModified = date;
      completer.complete(info);      
    });
    
    return completer.future;
  }

  Future<ClientFileInfo> _getLength(ClientFileInfo info){
    var completer = new Completer();
    //Sanity check
    if(info.file == null)
      completer.completeError(new Exception('file not init'));

    file.length().then((int length){
      info.length = length;
      completer.complete(info);
    });
    
    return completer.future;
  }
  
  Future<ClientFileInfo> _getMimeType(ClientFileInfo info){
    if(info.mimetype != null)
      return new Future.immediate(info);
    
    var mimetype = guessType(info.path);
    if(mimetype == null)
      mimetype = 'application/octet-stream';
    info.mimetype = mimetype;
    return new Future.immediate(info);
  }

  String toString() => """
${this.file}
${this.path}
${this.mimetype}
${this.lastModified}
${this.length}
    """;
}


class CommandDispatcherHandler {
  var _wsHandler;// = new WebSocketHandler();
  String path;
  String file;

  CommandDispatcherHandler(this.path){
    _wsHandler.onOpen = this.onOpen;

    //TODO: do we need ready flag before accepting requests?
    var handlersFile = findFile(this.path, 'command_handlers.dart',
        ignoreDirs:['packages', 'out']);
    
    handlersFile.then((file) {
      this.file = file;
      print('Ready to serve requests');
    });
  }
  
  void onRequest(HttpRequest req, HttpResponse res) =>
    _wsHandler.onRequest(req, res);

  void onOpen(WebSocketConnection conn){
    new CommandDispatcher(file, conn);
  }
}

class CommandDispatcher {

  final String file;
  WebSocketConnection connection;
  SendPort port;
  CommandDispatcher(this.file, this.connection){
    connection.onMessage = this.onMessage;
    connection.onClosed = this.onClosed;
    this.port = spawnUri(this.file);      
  }

  void onMessage(message) {
    port.call(message).then((reply){
      this.connection.send(reply);
    });
  }

  void onClosed(int status, String reason) {
    print('closed with $status for $reason');
  }
}

class WebUiHandler {

  final String path;
  final String mainfile = 'main.html';

  WebUiHandler(this.path);

  Future<String> _findMainFile(){
    return findFile(this.path, this.mainfile, ignoreDirs:['packages', 'out']);
  }

  Future<String> _build(String file) {
    var completer = new Completer();
    Timer.run(() {
      print('buiding $file ... ');
      var future = web_ui.build(new Options().arguments, [file]);
      Future.wait([future]).then((r){
        print('done!');
        print(r[0].outputs.values);
        var index = r[0].outputs.values.firstMatching((f) => f==file);
        print(r[0].outputs.keys);
        print(r[0].outputs.values);
        for(String key in r[0].outputs.keys){
          if(key.endsWith(mainfile)){
            completer.complete(key);
            break;
          }
        }
      });
    });
    return completer.future;
  }

  _redirectToBuiltFile(String outFile, HttpResponse res){
    res.headers.add(HttpHeaders.LOCATION, outFile.replaceAll(path, ''));
    res.statusCode = HttpStatus.MOVED_PERMANENTLY;
    res.close();
  }
  
  void onRequest(HttpRequest req, HttpResponse res) {
    print('${req.method} ${req.uri.path}');
    print(req.headers[HttpHeaders.USER_AGENT]);
    _findMainFile().then(_build).then((r) => _redirectToBuiltFile(r, res));
  }
}
