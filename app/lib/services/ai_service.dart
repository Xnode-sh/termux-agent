import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import '../models/answer.dart';

typedef _AskC = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _AskDart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _FreeC = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);

class AiService {
  static DynamicLibrary? _lib;
  static _AskDart? _askFn;
  static _FreeDart? _freeFn;
  static bool _ready = false;

  static void init(String libPath) {
    try {
      _lib = DynamicLibrary.open(libPath);
      _askFn = _lib!.lookupFunction<_AskC, _AskDart>('rtl_ai_ask');
      _freeFn = _lib!.lookupFunction<_FreeC, _FreeDart>('rtl_ai_free');
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static Future<AskResult?> ask(String request) async {
    if (!_ready) return null;
    final reqPtr = request.toNativeUtf8();
    try {
      final resultPtr = _askFn!(reqPtr);
      final jsonStr = resultPtr.toDartString();
      _freeFn!(resultPtr);
      return AskResult.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (e) {
      return AskResult(blocked: e.toString());
    } finally {
      calloc.free(reqPtr);
    }
  }
}
