; Run-time:
;   env-var: YKD_PRINT_IR=jit-pre-opt
;   env-var: YKT_TRACE_BBS=main:0,main:1
;   stderr:
;      --- Begin jit-pre-opt ---
;      ...
;      define {{type}} @__yk_compiled_trace_0(...
;        %{{0}} = add i32 1, 1
;        %{{1}} = add i32 2, 2
;        ret {{type}}...
;      }
;      ...
;      --- End jit-pre-opt ---

define void @main() {
entry:
    %0 = add i32 1, 1
    br label %bb2

bb2:
    %1 = add i32 2, 2
    unreachable
}