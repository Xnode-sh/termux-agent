#include <jni.h>
#include <pty.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <errno.h>
#include <string.h>

JNIEXPORT jint JNICALL
Java_sh_xnode_rtl_1agent_MainActivity_nativePtyOpen(
    JNIEnv *env, jobject thiz, jstring jcmd, jint rows, jint cols) {
    int master;
    struct winsize ws = { .ws_row = rows, .ws_col = cols };
    pid_t pid = forkpty(&master, NULL, NULL, &ws);
    if (pid < 0) return -1;
    if (pid == 0) {
        const char *cmd = (*env)->GetStringUTFChars(env, jcmd, NULL);
        setenv("TERM", "xterm-256color", 1);
        setenv("COLORTERM", "truecolor", 1);
        setenv("HOME", getenv("HOME") ? getenv("HOME") : "/data/data/sh.xnode.rtl_agent/files", 1);
        execlp(cmd, cmd, NULL);
        _exit(127);
    }
    return master;
}

JNIEXPORT jint JNICALL
Java_sh_xnode_rtl_1agent_MainActivity_nativePtyRead(
    JNIEnv *env, jobject thiz, jint fd, jbyteArray buf) {
    jsize len = (*env)->GetArrayLength(env, buf);
    jbyte *ptr = (*env)->GetByteArrayElements(env, buf, NULL);
    ssize_t n = read(fd, ptr, len);
    (*env)->ReleaseByteArrayElements(env, buf, ptr, 0);
    return (jint)(n < 0 ? -errno : n);
}

JNIEXPORT jint JNICALL
Java_sh_xnode_rtl_1agent_MainActivity_nativePtyWrite(
    JNIEnv *env, jobject thiz, jint fd, jbyteArray data) {
    jsize len = (*env)->GetArrayLength(env, data);
    jbyte *ptr = (*env)->GetByteArrayElements(env, data, NULL);
    ssize_t n = write(fd, ptr, len);
    (*env)->ReleaseByteArrayElements(env, data, ptr, JNI_ABORT);
    return (jint)(n < 0 ? -errno : n);
}

JNIEXPORT jint JNICALL
Java_sh_xnode_rtl_1agent_MainActivity_nativePtyResize(
    JNIEnv *env, jobject thiz, jint fd, jint rows, jint cols) {
    struct winsize ws = { .ws_row = rows, .ws_col = cols };
    return ioctl(fd, TIOCSWINSZ, &ws) < 0 ? -errno : 0;
}

JNIEXPORT jint JNICALL
Java_sh_xnode_rtl_1agent_MainActivity_nativePtyClose(
    JNIEnv *env, jobject thiz, jint fd) {
    return close(fd);
}
