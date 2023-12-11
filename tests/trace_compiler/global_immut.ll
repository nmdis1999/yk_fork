; Run-time:
;   env-var: YKD_PRINT_IR=jit-pre-opt
;   env-var: YKT_TRACE_BBS=main:0,main:1
;   stderr:
;      --- Begin jit-pre-opt ---
;      ...
;      define {{type}} @__yk_compiled_trace_0(...
;      ...
;      loopentry:...
;        %{{0}} = load i32, ptr @g, align 4
;        %{{1}} = add i32 %{{0}}, 1
;        br label %loopentry
;      }
;      ...
;      --- End jit-pre-opt ---

; Check the trace compiler correctly handles a not-mutated global.

@g = global i32 5

define void @main() {
entry:
    br label %bb1

bb1:
    %0 = load i32, ptr @g
    %1 = add i32 %0, 1
    unreachable
}
