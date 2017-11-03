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
# Copyright (C) 2016, Éric Thiébaut & Jonathan Léger.
# Copyright (C) 2017, Éric Thiébaut.
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
    ccall(_PHX_ErrCodeDecode, Void, (Ptr{UInt8}, Status), buf, code)
    return unsafe_string(pointer(buf))
end

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
   geterrorsymbol(code)

yields the symbol corresponding to status value `code`.

See also: [`geterrormessage`](@ref), [`printerror`](@ref).

"""
geterrorsymbol(code::Integer) = get(_ERRSYM, code, :PHX_UNKNOWN_STATUS)

"""

    printerror() -> curmode

yields the current error mode which indicates whether Phoenix error messages
are printed by the default error handler.  To choose the behavior, call:

    printerror(newmode) -> oldmode

which set the error mode to be `newmode` and yields the previous setting.

See also: [`geterrormessage`](@ref).

"""
printerror() = _printerror[]
printerror(newmode::Bool) =
    (oldmode = _printerror[]; _printerror[] = newmode; oldmode)

# `_printerror` is a global reference (hence non-volatile) to store whether or
# not print error messages.  In case of error, if `_printerror[]` is true, the
# error handler `_errorhandler` will call Phoenix default error handler (to
# avoid using any Julia i/o routines); otherwise nothing is printed.  This
# mecanism is intended to be able to toggle printing of error messages while
# being thread safe because nothing from Julia is used.
#
const _printerror = Ref{Bool}(true)
const _lasterrfunc = Ref{Ptr{Cchar}}(C_NULL)
const _lasterrcode = Ref{Status}(PHX_OK)
const _lasterrmesg = Ref{Ptr{Cchar}}(C_NULL)

"""
    _errorhandler(func, code, mesg)

error handler for the Phoenix library.  Temporarily stores last error and, if
`_printerror[]` is true, immediately calls `_printlasterror()`; otherwise the
error message can be printed a bit later (however prior to calling any Phoenix
functions) by calling `_printlasterror()`.  This method is thread safe (it does
not use Julia engine) as you can check with:

    code_native(Phoenix._errorhandler, (Ptr{Cchar}, Cint, Ptr{Cchar}))

"""
function _errorhandler(func::Ptr{Cchar}, code::Status, mesg::Ptr{Cchar})
    _lasterrfunc[] = func
    _lasterrcode[] = code
    _lasterrmesg[] = mesg
    if _printerror[]
        _printlasterror()
    end
end

"""
    _printlasterror()

prints last error (if any and if `_printerror[]` is true) using the default
error handler of the Phoenix library and clear memorized error.  This method is
intended to be called right after an error occured.  This method is thread safe
(it does not use Julia engine) as you can check with:

    code_native(Phoenix._printlasterror, ())

"""
function _printlasterror()
    if _printerror[] && _lasterrfunc[] != C_NULL && _lasterrmesg[] != C_NULL
        ccall(_PHX_ErrHandlerDefault, Void, (Ptr{Cchar}, Status, Ptr{Cchar}),
              _lasterrfunc[], _lasterrcode[], _lasterrmesg[])
    end
    _lasterrfunc[] = C_NULL
    _lasterrcode[] = PHX_OK
    _lasterrmesg[] = C_NULL
    return nothing
end
