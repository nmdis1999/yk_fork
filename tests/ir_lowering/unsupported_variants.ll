; Dump:
;   stdout:
;     ...
;     func main(...
;       bb0:
;         ...
;         unimplemented <<  %{{4}} = getelementptr i32, <8 x ptr> %{{1}}, i32 1>>
;         br bb1
;       bb1:
;         unimplemented <<  %{{6}} = alloca inalloca i32, align 4>>
;         unimplemented <<  %{{7}} = alloca i32, align 4, addrspace(4)>>
;         unimplemented <<  %{{8}} = alloca i32, i32 %2, align 4>>
;         br bb2
;      bb2:
;         unimplemented <<  %{{13}} = fadd nnan float %{{3}}, %{{3}}>>
;         unimplemented <<  %{{15}} = add <4 x i32> %{{44}}, %{{44}}>>
;         br bb3
;      bb3:
;         unimplemented <<  %{{17}} = call i32 @f(i32 swiftself 5)>>
;         unimplemented <<  %{{18}} = call inreg i32 @f(i32 5)>>
;         unimplemented <<  %{{19}} = call i32 @f(i32 5) #{{0}}>>
;         unimplemented <<  %{{20}} = call nnan float @g()>>
;         unimplemented <<  %{{21}} = call ghccc i32 @f(i32 5)>>
;         unimplemented <<  %{{22}} = call i32 @f(i32 5) [ "kcfi"(i32 1234) ]>>
;         unimplemented <<  %{{23}} = call addrspace(6) ptr @p()>>
;         br bb4
;      bb4:
;         unimplemented <<  %{{25}} = ptrtoint ptr %{{ptr}} to i8>>
;         unimplemented <<  %{{26}} = ptrtoint <8 x ptr> %{{ptrs}} to <8 x i8>>>
;         unimplemented <<  %{{_}} = sext <4 x i32> %{{_}} to <4 x i64>>>
;         unimplemented <<  %{{_}} = zext <4 x i32> %{{_}} to <4 x i64>>>
;         unimplemented <<  %{{_}} = trunc <4 x i32> %{{_}} to <4 x i8>>>
;         br bb5
;     bb5:
;         unimplemented <<  %{{27}} = icmp ne <4 x i32> %{{444}}, zeroinitializer>>
;         br bb6
;     bb6:
;         unimplemented <<  %{{_}} = load atomic i32, ptr %{{_}} acquire, align 4>>
;         unimplemented <<  %{{_}} = load i32, ptr addrspace(10) %{{_}}, align 4>>
;         unimplemented <<  %{{_}} = load i32, ptr %{{_}}, align 2>>
;         br ...
;         ...
;     bb10:
;       unimplemented <<  %{{_}} = phi nnan float...
;       br bb11
;     bb11:
;       unimplemented <<  store atomic i32 0, ptr %0 release, align 4>>
;       unimplemented <<  store i32 0, ptr addrspace(10) %5, align 4>>
;       unimplemented <<  store i32 0, ptr %0, align 2>>
;       ret
;     }
;     ...

; This test ensures that as-yet unsupported variants of LLVM instructions are
; serialised as an unsupported instruction in the AOT IR. This prevents the JIT
; from silently miscompiling things we haven't yet thought about.

define i32 @f(i32 %num) {
    ret i32 5
}

define float @g() {
    ret float 5.5
}

define ptr @p() addrspace(6) {
    ret ptr null
}

declare void @llvm.experimental.stackmap(i64, i32, ...);

define void @main(ptr %ptr, <8 x ptr> %ptrs, i32 %num, float %flt, <4 x i32>
%vecnums, ptr addrspace(10) %asptr, i1 %choice, <4 x i32> %nums) optnone noinline {
geps:
  ; note `getelementptr inrange` cannot appear as a dedicated instruction, only
  ; as an inline expression. Hence no check for that in instruction form.
  %gep1 = getelementptr i32, <8 x ptr> %ptrs, i32 1
  br label %allocas
allocas:
  ; `inalloca` keyword
  %inalloca = alloca inalloca i32
  ; non-zero address space
  %alloca_aspace = alloca i32, addrspace(4)
  ; dynamic stack allocas
  %alloca_dyn = alloca i32, i32 %num
  ; Note that we don't test alloca's with number of elements not expressible in
  ; a `size_t`. At the time of writing using a type wider than i64 for the
  ; element count can crash selection dag.
  ; e.g.: `%blah = alloca i32, i66 36893488147419103232`
  br label %binops
binops:
  ; fast math flags
  %binop_fmathflag = fadd nnan float %flt, %flt
  ; vectors
  %binop_vec = add <4 x i32> %vecnums, %vecnums
  br label %calls
calls:
  ; FIXME: we are unable to test `musttail` because a tail call must be
  ; succeeded by either a `ret` or a `bitcast` and then a `ret`. But the JIT
  ; requires a stackmap after a call...
  ;
  ; param attrs
  %call_paramattr = call i32 @f(i32 swiftself 5)
  ; ret attrs
  %call_inreg = call inreg i32 @f(i32 5)
  ; func attrs
  %call_alignstack = call i32 @f(i32 5) alignstack(8)
  ; fast math flags
  %call_fmathflag = call nnan float @g()
  ; Non-C calling conventions
  %call_cconv = call ghccc i32 @f(i32 5)
  ; operand bundles
  %call_bundles = call i32 @f(i32 5) ["kcfi"(i32 1234)]
  ; non-zero address spaces
  %call_aspace = call addrspace(6) ptr @p()
  ; stackmap required (but irrelevant for the test) for all of the above calls.
  call void (i64, i32, ...) @llvm.experimental.stackmap(i64 7, i32 0);
  br label %casts
casts:
  ; ptrtoint to a smaller type
  %ptrtoint_trunc = ptrtoint ptr %ptr to i8
  ; vectors
  %ptrtoint_vec = ptrtoint <8 x ptr> %ptrs to <8 x i8>
  %sext_vec = sext <4 x i32> %nums to <4 x i64>
  %zext_vec = zext <4 x i32> %nums to <4 x i64>
  %trunc_vec = trunc <4 x i32> %nums to <4 x i8>
  br label %icmps
icmps:
  ; vector of comparisons
  %icmp_vec = icmp ne <4 x i32> %vecnums, zeroinitializer
  ; stackmap stops icmp from being optimised out.
  call void (i64, i32, ...) @llvm.experimental.stackmap(i64 8, i32 0, <4 x i1> %icmp_vec);
  br label %loads
loads:
  ; atomic loads
  ; note: atomic load must have explicit non-zero alignment
  %load_atom = load atomic i32, ptr %ptr acquire, align 4
  ; loads from exotic address spaces
  %load_aspace = load i32, ptr addrspace(10) %asptr
  ; potentially misaligned loads
  %load_misalign = load i32, ptr %ptr, align 2
  ; stackmap stops loads from being optimised out.
  call void (i64, i32, ...) @llvm.experimental.stackmap(i64 8, i32 0)
  br label %phi_setup1
phi_setup1:
  ; LLVM checks for nonsense PHI nodes, so we have to have sensible control
  ; flow to test them.
  call void (i64, i32, ...) @llvm.experimental.stackmap(i64 9, i32 0)
  br i1 %choice, label %phi_true, label %phi_false
phi_true:
  br label %phis
phi_false:
  br label %phis
phis:
  ; fast math flags
  %phi_fastmath = phi nnan float [0.0, %phi_true], [0.0, %phi_false]
  br label %stores
stores:
  ; atomic store
  ; note: atomic store must have explicit non-zero alignment
  store atomic i32 0, ptr %ptr release, align 4
  ; stores into exotic address spaces
  store i32 0, ptr addrspace(10) %asptr
  ; potentially misaligned stores
  store i32 0, ptr %ptr, align 2
  ret void
}
