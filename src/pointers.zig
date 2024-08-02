//! R External Pointers
const std = @import("std");

const r = @import("r.zig");
const rzig = @import("Rzig.zig");
const errors = rzig.errors;

const Robject = rzig.Robject;
const Anyfn = r.Anyfn;

/// Create an external pointer object.
/// `ptr` is the pointer. It is null checked.
/// `tag` is an R object that will be protected from GC.
/// `prot` is an R object that will be protected from GC.
///
/// By convention use `tag` field as some form of type identification and `prot`
/// field for protecting the memory that the external pointer represents.
/// If that memory is allocated from the R heap, both `tag` and `prot` can be
/// set to `r_null.*`
///
/// Use `makeExternalPtrFn` for function pointers.
pub fn makeExternalPtr(ptr: ?*anyopaque, tag: Robject, prot: Robject) Robject {
    if (ptr) |p| {
        return r.R_MakeExternalPtr(p, tag, prot);
    } else {
        errors.stop("Trying to make an external pointer with null address", .{});
    }
}

/// Get the pointer referenced by the external pointer object.
pub fn externalPtrAddr(obj: Robject) ?*anyopaque {
    if (obj.?.isTypeOf(.ExternalPointer)) {
        return r.R_ExternalPtrAddr(obj);
    } else {
        errors.stop("Expected external pointer, found: {any}", .{obj.?.typeOf()});
    }
}

/// Create an external pointer object to a function.
/// `fn_ptr` is the function pointer. It is null checked.
/// `tag` is an R object that will be protected from GC.
/// `prot` is an R object that will be protected from GC.
///
/// For more param details see `makeExternalPtr`.
///
/// Use `makeExternalPtr` for non-function pointers.
pub fn makeExternalPtrFn(fn_ptr: Anyfn, tag: Robject, prot: Robject) Robject {
    if (fn_ptr) |p| {
        return r.R_MakeExternalPtrFn(p, tag, prot);
    } else {
        errors.stop("Trying to make an external pointer to a function with null address. {}");
    }
}

/// Get the function pointer referenced by the external pointer object.
pub fn externalPtrAddrFn(obj: Robject) Anyfn {
    if (obj.?.isTypeOf(.ExternalPointer)) {
        return r.R_ExternalPtrAddrFn(obj);
    } else {
        errors.stop("Expected external pointer, found: {any}", .{obj.?.typeOf()});
    }
}
