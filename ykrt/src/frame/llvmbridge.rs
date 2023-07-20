use llvm_sys::core::*;
use llvm_sys::orc2::LLVMOrcThreadSafeModuleRef;
use llvm_sys::prelude::{LLVMBasicBlockRef, LLVMModuleRef, LLVMTypeRef, LLVMValueRef};
use llvm_sys::target::{LLVMGetModuleDataLayout, LLVMTargetDataRef};
use llvm_sys::LLVMTypeKind;
use std::{ffi::CStr, fmt};

pub struct Module(LLVMModuleRef);

// Replicates struct of same name in `ykllvmwrap.cc`.
#[repr(C)]
pub struct BitcodeSection {
    pub data: *const u8,
    pub len: u64,
}

extern "C" {
    pub fn LLVMGetThreadSafeModule(bs: BitcodeSection) -> LLVMOrcThreadSafeModuleRef;
}

impl Module {
    pub unsafe fn new(module: LLVMModuleRef) -> Self {
        Self(module)
    }

    pub fn datalayout(&self) -> LLVMTargetDataRef {
        unsafe { LLVMGetModuleDataLayout(self.0) }
    }
}

#[derive(PartialEq, Eq, Clone, Copy, Hash)]
pub struct Type(LLVMTypeRef);
impl Type {
    pub fn kind(&self) -> LLVMTypeKind {
        unsafe { LLVMGetTypeKind(self.0) }
    }

    pub fn is_integer(&self) -> bool {
        matches!(self.kind(), LLVMTypeKind::LLVMIntegerTypeKind)
    }

    pub fn get_int_width(&self) -> u32 {
        debug_assert!(self.is_integer());
        unsafe { LLVMGetIntTypeWidth(self.0) }
    }
}

#[derive(PartialEq, Eq, Hash, Clone, Copy)]
pub struct Value(LLVMValueRef);
impl Value {
    pub unsafe fn new(vref: LLVMValueRef) -> Self {
        Value(vref)
    }

    pub fn get(&self) -> LLVMValueRef {
        self.0
    }

    pub fn is_instruction(&self) -> bool {
        unsafe { !LLVMIsAInstruction(self.0).is_null() }
    }

    pub fn is_alloca(&self) -> bool {
        unsafe { !LLVMIsAAllocaInst(self.0).is_null() }
    }

    pub fn is_call(&self) -> bool {
        unsafe { !LLVMIsACallInst(self.0).is_null() }
    }

    pub fn is_intrinsic(&self) -> bool {
        unsafe { !LLVMIsAIntrinsicInst(self.0).is_null() }
    }

    pub fn get_type(&self) -> Type {
        unsafe { Type(LLVMTypeOf(self.0)) }
    }

    pub fn get_operand(&self, idx: u32) -> Value {
        unsafe {
            debug_assert!(!LLVMIsAUser(self.0).is_null());
            Value(LLVMGetOperand(self.0, idx))
        }
    }
}

impl fmt::Debug for Value {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{:?}", unsafe {
            CStr::from_ptr(LLVMPrintValueToString(self.0))
        })
    }
}
