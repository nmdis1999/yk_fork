//! The Yorick TIR trace compiler.

#![cfg_attr(test, feature(test))]

#[macro_use]
extern crate dynasmrt;
#[macro_use]
extern crate lazy_static;
#[cfg(test)]
extern crate test;

use std::mem;
use ykbh::SIRInterpreter;
use ykpack::{Constant, Local, OffT, TypeId};

mod arch;
mod stack_builder;

// FIXME hard-wired use of the x86_64 backend.
// This should be made into a properly abstracted API.
pub use arch::x86_64::{compile_trace, TraceCompiler, REG_POOL};

#[derive(Debug, Clone, PartialEq)]
pub enum Location {
    /// A value in a register.
    Reg(u8),
    /// A statically known memory location relative to a register.
    Mem(RegAndOffset),
    /// A location that contains a pointer to some underlying storage.
    Indirect { ptr: IndirectLoc, off: OffT },
    /// A statically known constant.
    Const { val: Constant, ty: TypeId },
}

impl Location {
    /// Creates a new memory location from a register and an offset.
    fn new_mem(reg: u8, off: OffT) -> Self {
        Self::Mem(RegAndOffset { reg, off })
    }

    /// If `self` is a `Mem` then unwrap it, otherwise panic.
    fn unwrap_mem(&self) -> &RegAndOffset {
        if let Location::Mem(ro) = self {
            ro
        } else {
            panic!("tried to unwrap a Mem location when it wasn't a Mem");
        }
    }

    /// Returns which register (if any) is used in addressing this location.
    fn uses_reg(&self) -> Option<u8> {
        match self {
            Location::Reg(reg) => Some(*reg),
            Location::Mem(RegAndOffset { reg, .. }) => Some(*reg),
            Location::Indirect {
                ptr: IndirectLoc::Reg(reg),
                ..
            }
            | Location::Indirect {
                ptr: IndirectLoc::Mem(RegAndOffset { reg, .. }),
                ..
            } => Some(*reg),
            Location::Const { .. } => None,
        }
    }

    /// Apply an offset to the location, returning a new one.
    fn offset(self, off: OffT) -> Self {
        if off == 0 {
            return self;
        }
        match self {
            Location::Mem(ro) => Location::Mem(RegAndOffset {
                reg: ro.reg,
                off: ro.off + off,
            }),
            Location::Indirect { ptr, off: ind_off } => Location::Indirect {
                ptr,
                off: ind_off + off,
            },
            Location::Reg(..) | Location::Const { .. } => todo!("offsetting a constant"),
        }
    }

    /// Converts a direct place to an indirect place for use as a pointer.
    fn to_indirect(&self) -> Self {
        let ptr = match self {
            Location::Reg(r) => IndirectLoc::Reg(*r),
            Location::Mem(ro) => IndirectLoc::Mem(ro.clone()),
            _ => unreachable!(),
        };
        Location::Indirect { ptr, off: 0 }
    }
}

/// Represents a memory location using a register and an offset.
#[derive(Debug, Clone, PartialEq)]
pub struct RegAndOffset {
    reg: u8,
    off: OffT,
}

/// Describes the location of the pointer in Location::Indirect.
#[derive(Debug, Clone, PartialEq)]
pub enum IndirectLoc {
    /// There's a pointer in this register.
    Reg(u8),
    /// There's a pointer in memory somewhere.
    Mem(RegAndOffset),
}

/// The allocation of a register.
#[derive(Debug)]
enum RegAlloc {
    Local(Local),
    Free,
}

/// A native machine code trace.
pub struct CompiledTrace {
    /// A compiled trace.
    mc: dynasmrt::ExecutableBuffer,
}

impl CompiledTrace {
    /// Execute the trace by calling (not jumping to) the first instruction's address.
    pub unsafe fn execute<TT>(&self, args: &mut TT) -> *mut SIRInterpreter {
        let func: extern "sysv64" fn(&mut TT) -> *mut SIRInterpreter =
            mem::transmute(self.mc.ptr(dynasmrt::AssemblyOffset(0)));
        self.exec_trace(func, args)
    }

    /// Actually call the code. This is a separate function making it easier to set a debugger
    /// breakpoint right before entering the trace.
    fn exec_trace<TT>(
        &self,
        t_fn: extern "sysv64" fn(&mut TT) -> *mut SIRInterpreter,
        args: &mut TT,
    ) -> *mut SIRInterpreter {
        t_fn(args)
    }

    /// Return a pointer to the mmap'd block of memory containing the trace. The underlying data is
    /// guaranteed never to move in memory.
    pub fn ptr(&self) -> *const u8 {
        self.mc.ptr(dynasmrt::AssemblyOffset(0))
    }
}
