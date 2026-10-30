/*
 * allow_ptrace.c — LD_PRELOAD shim to allow gdb attach under ptrace_scope=1.
 *
 * When loaded via LD_PRELOAD, this calls prctl(PR_SET_PTRACER, PR_SET_PTRACER_ANY)
 * at process startup, permitting any process (not just the parent) to ptrace it.
 * Used by run.sh --pause-on-deadlock so that gdb can attach to a stuck instance.
 *
 * Build:  gcc -shared -fPIC -o allow_ptrace.so allow_ptrace.c
 */
#include <sys/prctl.h>

#ifndef PR_SET_PTRACER_ANY
#define PR_SET_PTRACER_ANY ((unsigned long)-1)
#endif

__attribute__((constructor))
static void allow_ptrace(void) {
    prctl(PR_SET_PTRACER, PR_SET_PTRACER_ANY, 0, 0, 0);
}
