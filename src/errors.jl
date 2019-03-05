#
# errors.jl -
#
# Handling of errors for Julia interface to ActiveSilicon Phoenix (PHX)
# library.
#
#------------------------------------------------------------------------------
#
# This file is part of the `Phoenix.jl` package which is licensed under the MIT
# "Expat" License.
#
# Copyright (C) 2017-2019, Éric Thiébaut (https://github.com/emmt/Phoenix.jl).
# Copyright (C) 2016, Éric Thiébaut & Jonathan Léger.
#

Base.showerror(io::IO, e::PHXError) =
    print(io, "PHXError: ", geterrormessage(e.status), " [",
          geterrorsymbol(e.status), "]")

"""
   geterrormessage(code)

yields the error message corresponding to `code`.

See also: [`geterrorsymbol`](@ref), [`printerror`](@ref).

"""
function geterrormessage(code::Integer)
    buf = zeros(UInt8, 512)
    ccall(_PHX_ErrCodeDecode[], Nothing, (Ptr{UInt8}, Status), buf, code)
    return unsafe_string(pointer(buf))
end

"""
   geterrorsymbol(code)

yields the symbol corresponding to status value `code`.

See also: [`geterrormessage`](@ref), [`printerror`](@ref).

"""
geterrorsymbol(code::Integer) = get(_ERRSYM, code, :PHX_UNKNOWN_STATUS)

const _ERRSYM = Dict{Status, Symbol}()
for s in (:PHX_OK, :PHX_ERROR_BAD_HANDLE, :PHX_ERROR_BAD_PARAM,
          :PHX_ERROR_BAD_PARAM_VALUE, :PHX_ERROR_READ_ONLY_PARAM,
          :PHX_ERROR_OPEN_FAILED, :PHX_ERROR_INCOMPATIBLE,
          :PHX_ERROR_HANDSHAKE, :PHX_ERROR_INTERNAL_ERROR,
          :PHX_ERROR_OVERFLOW, :PHX_ERROR_NOT_IMPLEMENTED,
          :PHX_ERROR_HW_PROBLEM, :PHX_ERROR_NOT_SUPPORTED,
          :PHX_ERROR_OUT_OF_RANGE, :PHX_ERROR_MALLOC_FAILED,
          :PHX_ERROR_SYSTEM_CALL_FAILED, :PHX_ERROR_FILE_OPEN_FAILED,
          :PHX_ERROR_FILE_CLOSE_FAILED, :PHX_ERROR_FILE_INVALID,
          :PHX_ERROR_BAD_MEMBER, :PHX_ERROR_HW_NOT_CONFIGURED,
          :PHX_ERROR_INVALID_FLASH_PROPERTIES, :PHX_ERROR_ACQUISITION_STARTED,
          :PHX_ERROR_INVALID_POINTER, :PHX_ERROR_LIB_INCOMPATIBLE,
          :PHX_ERROR_SLAVE_MODE, :PHX_ERROR_DISPLAY_CREATE_FAILED,
          :PHX_ERROR_DISPLAY_DESTROY_FAILED, :PHX_ERROR_DDRAW_INIT_FAILED,
          :PHX_ERROR_DISPLAY_BUFF_CREATE_FAILED,
          :PHX_ERROR_DISPLAY_BUFF_DESTROY_FAILED,
          :PHX_ERROR_DDRAW_OPERATION_FAILED, :PHX_ERROR_WIN32_REGISTRY_ERROR,
          :PHX_ERROR_PROTOCOL_FAILURE,
          :PHX_WARNING_TIMEOUT, :PHX_WARNING_FLASH_RECONFIG,
          :PHX_WARNING_ZBT_RECONFIG, :PHX_WARNING_NOT_PHX_COM,
          :PHX_WARNING_NO_PHX_BOARD_REGISTERED, :PHX_WARNING_TIMEOUT_EXTENDED)
    _ERRSYM[@eval($s)] = s
end

"""

    printerror() -> curmode

yields the current error mode which indicates whether Phoenix error messages
are printed by the default error handler.  To choose the behavior, call:

    printerror(newmode) -> oldmode

which set the error mode to be `newmode` and yields the previous setting.

See also: [`geterrormessage`](@ref).

"""
printerror() = _PRNTERRMODE_REF[]
printerror(newmode::Bool) =
    (oldmode = _PRNTERRMODE_REF[]; _PRNTERRMODE_REF[] = newmode; oldmode)

# `_PRNTERRMODE_REF` is a global reference (hence non-volatile) to store whether or
# not print error messages.  In case of error, if `_PRNTERRMODE_REF[]` is true, the
# error handler `_errorhandler` will call Phoenix default error handler (to
# avoid using any Julia i/o routines); otherwise nothing is printed.  This
# mecanism is intended to be able to toggle printing of error messages while
# being thread safe because nothing from Julia is used.
#
const _PRNTERRMODE_REF = Ref{Bool}(true)
const _LASTERRFUNC_REF = Ref{Ptr{Cchar}}(C_NULL)
const _LASTERRCODE_REF = Ref{Status}(PHX_OK)
const _LASTERRMESG_REF = Ref{Ptr{Cchar}}(C_NULL)

"""
    _errorhandler(func, code, mesg)

error handler for the Phoenix library.  Temporarily stores last error and, if
`_PRNTERRMODE_REF[]` is true, immediately calls `_printlasterror()`; otherwise the
error message can be printed a bit later (however prior to calling any Phoenix
functions) by calling `_printlasterror()`.  This method is thread safe (it does
not use Julia engine) as you can check with:

    code_native(Phoenix._errorhandler, (Ptr{Cchar}, Cint, Ptr{Cchar}))

"""
function _errorhandler(func::Ptr{Cchar}, code::Status, mesg::Ptr{Cchar})
    _LASTERRFUNC_REF[] = func
    _LASTERRCODE_REF[] = code
    _LASTERRMESG_REF[] = mesg
    if _PRNTERRMODE_REF[]
        _printlasterror()
    end
end

"""
    _printlasterror()

prints last error (if and only if `_PRNTERRMODE_REF[]` is true) using the
default error handler of the Phoenix library and clear memorized error.  This
method is intended to be called right after an error occured.  This method is
thread safe (it does not use Julia engine) as you can check with:

    code_native(Phoenix._printlasterror, ())

"""
function _printlasterror()
    if _PRNTERRMODE_REF[] && _LASTERRFUNC_REF[] != C_NULL && _LASTERRMESG_REF[] != C_NULL
        ccall(_PHX_ErrHandlerDefault[], Cvoid, (Ptr{Cchar}, Status, Ptr{Cchar}),
              _LASTERRFUNC_REF[], _LASTERRCODE_REF[], _LASTERRMESG_REF[])
    end
    _LASTERRFUNC_REF[] = C_NULL
    _LASTERRCODE_REF[] = PHX_OK
    _LASTERRMESG_REF[] = C_NULL
    return nothing
end
