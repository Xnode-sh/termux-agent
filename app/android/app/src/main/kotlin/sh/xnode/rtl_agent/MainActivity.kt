package sh.xnode.rtl_agent

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        init {
            System.loadLibrary("rtl_pty")
        }
    }

    private external fun nativePtyOpen(cmd: String, rows: Int, cols: Int): Int
    private external fun nativePtyRead(fd: Int, buf: ByteArray): Int
    private external fun nativePtyWrite(fd: Int, data: ByteArray): Int
    private external fun nativePtyResize(fd: Int, rows: Int, cols: Int): Int
    private external fun nativePtyClose(fd: Int): Int

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sh.xnode.rtl_agent/pty").setMethodCallHandler { call, result ->
            when (call.method) {
                "open" -> {
                    val cmd = call.argument<String>("cmd") ?: "/system/bin/sh"
                    val rows = call.argument<Int>("rows") ?: 24
                    val cols = call.argument<Int>("cols") ?: 80
                    val fd = nativePtyOpen(cmd, rows, cols)
                    if (fd >= 0) result.success(fd) else result.error("PTY", "forkpty failed", fd)
                }
                "read" -> {
                    val fd = call.argument<Int>("fd")!!
                    val buf = ByteArray(4096)
                    val n = nativePtyRead(fd, buf)
                    if (n >= 0) result.success(buf.copyOf(n)) else result.error("PTY", "read error", n)
                }
                "write" -> {
                    val fd = call.argument<Int>("fd")!!
                    val data = call.argument<ByteArray>("data")!!
                    result.success(nativePtyWrite(fd, data))
                }
                "resize" -> {
                    val fd = call.argument<Int>("fd")!!
                    val rows = call.argument<Int>("rows")!!
                    val cols = call.argument<Int>("cols")!!
                    result.success(nativePtyResize(fd, rows, cols))
                }
                "close" -> {
                    val fd = call.argument<Int>("fd")!!
                    result.success(nativePtyClose(fd))
                }
                else -> result.notImplemented()
            }
        }
    }
}
