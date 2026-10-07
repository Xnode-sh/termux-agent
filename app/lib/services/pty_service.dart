import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class PtyService {
  static const _channel = MethodChannel('sh.xnode.rtl_agent/pty');

  static Future<String> exec(String cmd) async {
    try {
      final fd = await _channel.invokeMethod<int>('open', {
        'cmd': '/system/bin/sh',
        'rows': 24,
        'cols': 80,
      });
      if (fd == null || fd < 0) return '[PTY open failed]';

      await _channel.invokeMethod('write', {
        'fd': fd,
        'data': Uint8List.fromList(utf8.encode('$cmd\nexit \$?\n')),
      });

      final buf = StringBuffer();
      var retries = 0;
      while (retries < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        try {
          final data = await _channel.invokeMethod<Uint8List>('read', {'fd': fd});
          if (data == null || data.isEmpty) {
            retries++;
            continue;
          }
          retries = 0;
          buf.write(utf8.decode(data, allowMalformed: true));
        } catch (_) {
          break;
        }
      }

      await _channel.invokeMethod('close', {'fd': fd});
      return buf.toString().trimRight();
    } catch (e) {
      return '[Error: $e]';
    }
  }
}
