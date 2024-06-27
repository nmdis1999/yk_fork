// ignore-if: test $YK_JIT_COMPILER != "yk" -o "$YKB_TRACER" = "swt"
// Run-time:
//   env-var: YKD_LOG_IR=-:aot,jit-pre-opt
//   env-var: YKD_SERIALISE_COMPILATION=1
//   env-var: YKD_LOG_JITSTATE=-
//   stderr:
//     jitstate: start-tracing
//     4 -> 4.333300 4.840000
//     jitstate: stop-tracing
//     --- Begin aot ---
//     ...
//     func main(%arg0: i32, %arg1: ptr) -> i32 {
//     ...
//     %{{10_5}}: float = fadd %{{_}}, %{{_}}
//     %{{10_6}}: double = fp_ext %{{10_5}}, double
//     ...
//     %{{10_9}}: double = fadd %{{_}}, %{{_}}
//     ...
//     %{{_}}: i32 = call fprintf(%{{_}}, @{{_}}, %{{_}}, %10_6, %10_9)
//     ...
//     --- End aot ---
//     --- Begin jit-pre-opt ---
//     ...
//     %{{16}}: float = fadd %{{_}}, %{{_}}
//     %{{17}}: double = fp_ext %{{16}}
//     ...
//     %{{20}}: double = fadd %{{_}}, %{{_}}
//     ...
//     %{{_}}: i32 = call @fprintf(%{{_}}, %{{_}}, %{{_}}, %{{17}}, %{{20}})
//     ...
//     --- End jit-pre-opt ---
//     3 -> 3.333300 3.840000
//     jitstate: enter-jit-code
//     2 -> 2.333300 2.840000
//     1 -> 1.333300 1.840000
//     jitstate: deoptimise

// Check floating point addition works.

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <yk.h>
#include <yk_testing.h>

int main(int argc, char **argv) {
  YkMT *mt = yk_mt_new(NULL);
  yk_mt_hot_threshold_set(mt, 0);
  YkLocation loc = yk_location_new();

  int i = 4;
  float f = 0.3333;
  double d = 0.84;
  NOOPT_VAL(loc);
  NOOPT_VAL(i);
  NOOPT_VAL(f);
  while (i > 0) {
    yk_mt_control_point(mt, &loc);
    fprintf(stderr, "%d -> %f %f\n", i, (float)i + f, (double)i + d);
    i--;
  }
  yk_location_drop(loc);
  yk_mt_drop(mt);
  return (EXIT_SUCCESS);
}
