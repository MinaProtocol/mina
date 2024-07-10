use crate::{FromValue, IntoValue, Runtime, Value};

/// Errors that are translated directly into OCaml exceptions
#[derive(Debug)]
pub enum CamlError {
    /// Not_found
    NotFound,

    /// Failure
    Failure(&'static str),

    /// Invalid_argument
    InvalidArgument(&'static str),

    /// Out_of_memory
    OutOfMemory,

    /// Stack_overflow
    StackOverflow,

    /// Sys_error
    SysError(Value),

    /// End_of_file
    EndOfFile,

    /// Zero_divide
    ZeroDivide,

    /// Array bound error
    ArrayBoundError,

    /// Sys_blocked_io
    SysBlockedIo,

    /// A pre-allocated OCaml exception
    Exception(Value),

    /// An exception type and argument
    WithArg(Value, Value),
}

/// Error returned by `ocaml-rs` functions
#[derive(Debug)]
pub enum Error {
    /// A value cannot be called using callback functions
    NotCallable,

    /// Array is not a double array
    NotDoubleArray,

    /// Error message
    Message(&'static str),

    /// General error
    #[cfg(not(feature = "no-std"))]
    Error(Box<dyn std::error::Error>),

    /// OCaml exceptions
    Caml(CamlError),
}

#[cfg(not(feature = "no-std"))]
impl<T: 'static + std::error::Error> From<T> for Error {
    fn from(x: T) -> Error {
        Error::Error(Box::new(x))
    }
}

impl From<CamlError> for Error {
    fn from(x: CamlError) -> Error {
        Error::Caml(x)
    }
}

impl Error {
    /// Re-raise an existing exception value
    pub fn reraise(exc: Value) -> Result<(), Error> {
        Err(CamlError::Exception(exc).into())
    }

    /// Raise an exception that has been registered using `Callback.register_exception` with no
    /// arguments
    pub fn raise<S: AsRef<str>>(exc: S) -> Result<(), Error> {
        let value = match unsafe { Value::named(exc.as_ref()) } {
            Some(v) => v,
            None => {
                return Err(Error::Message(
                    "Value has not been registered with the OCaml runtime",
                ))
            }
        };
        Err(CamlError::Exception(value).into())
    }

    /// Raise an exception that has been registered using `Callback.register_exception` with an
    /// argument
    pub fn raise_with_arg<S: AsRef<str>>(exc: S, arg: Value) -> Result<(), Error> {
        let value = match unsafe { Value::named(exc.as_ref()) } {
            Some(v) => v,
            None => {
                return Err(Error::Message(
                    "Value has not been registered with the OCaml runtime",
                ))
            }
        };

        Err(CamlError::WithArg(value, arg).into())
    }

    /// Raise `Not_found`
    pub fn not_found() -> Result<(), Error> {
        Err(CamlError::NotFound.into())
    }

    /// Raise `Out_of_memory`
    pub fn out_of_memory() -> Result<(), Error> {
        Err(CamlError::OutOfMemory.into())
    }

    /// Raise `Failure`
    pub fn failwith(s: &'static str) -> Result<(), Error> {
        Err(CamlError::Failure(s).into())
    }

    /// Raise `Invalid_argument`
    pub fn invalid_argument(s: &'static str) -> Result<(), Error> {
        Err(CamlError::Failure(s).into())
    }

    #[doc(hidden)]
    pub fn raise_failure(s: &str) -> ! {
        unsafe {
            let value = crate::sys::caml_alloc_string(s.len());
            let ptr = crate::sys::string_val(value);
            core::ptr::copy_nonoverlapping(s.as_ptr(), ptr, s.len());
            crate::sys::caml_failwith_value(value);
        }
        #[allow(clippy::empty_loop)]
        loop {}
    }

    #[doc(hidden)]
    pub fn raise_value(v: Value, s: &str) -> ! {
        unsafe {
            let st = crate::sys::caml_alloc_string(s.len());
            let ptr = crate::sys::string_val(st);
            core::ptr::copy_nonoverlapping(s.as_ptr(), ptr, s.len());
            crate::sys::caml_raise_with_arg(v.raw().0, st);
        }
        #[allow(clippy::empty_loop)]
        loop {}
    }

    /// Get named error registered using `Callback.register_exception`
    pub fn named<S: AsRef<str>>(s: S) -> Option<Value> {
        unsafe { Value::named(s.as_ref()) }
    }
}

#[cfg(not(feature = "no-std"))]
unsafe impl<T: IntoValue, E: 'static + std::error::Error> IntoValue for Result<T, E> {
    fn into_value(self, rt: &Runtime) -> Value {
        match self {
            Ok(x) => x.into_value(rt),
            Err(y) => {
                let e: Result<T, Error> = Err(Error::Error(Box::new(y)));
                e.into_value(rt)
            }
        }
    }
}

unsafe impl<T: IntoValue> IntoValue for Result<T, Error> {
    fn into_value(self, rt: &Runtime) -> Value {
        match self {
            Ok(x) => return x.into_value(rt),
            Err(Error::Caml(CamlError::Exception(e))) => unsafe {
                crate::sys::caml_raise(e.raw().0);
            },
            Err(Error::Caml(CamlError::NotFound)) => unsafe {
                crate::sys::caml_raise_not_found();
            },
            Err(Error::Caml(CamlError::ArrayBoundError)) => unsafe {
                crate::sys::caml_array_bound_error();
            },
            Err(Error::Caml(CamlError::OutOfMemory)) => unsafe {
                crate::sys::caml_array_bound_error();
            },
            Err(Error::Caml(CamlError::EndOfFile)) => unsafe {
                crate::sys::caml_raise_end_of_file()
            },
            Err(Error::Caml(CamlError::StackOverflow)) => unsafe {
                crate::sys::caml_raise_stack_overflow()
            },
            Err(Error::Caml(CamlError::ZeroDivide)) => unsafe {
                crate::sys::caml_raise_zero_divide()
            },
            Err(Error::Caml(CamlError::SysBlockedIo)) => unsafe {
                crate::sys::caml_raise_sys_blocked_io()
            },
            Err(Error::Caml(CamlError::InvalidArgument(s))) => {
                unsafe {
                    let s = crate::util::CString::new(s).expect("Invalid C string");
                    crate::sys::caml_invalid_argument(s.as_ptr() as *const ocaml_sys::Char)
                };
            }
            Err(Error::Caml(CamlError::WithArg(a, b))) => unsafe {
                crate::sys::caml_raise_with_arg(a.raw().0, b.raw().0)
            },
            Err(Error::Caml(CamlError::SysError(s))) => {
                unsafe { crate::sys::caml_raise_sys_error(s.raw().0) };
            }
            Err(Error::Message(s)) => {
                unsafe {
                    let s = crate::util::CString::new(s).expect("Invalid C string");
                    crate::sys::caml_failwith(s.as_ptr() as *const ocaml_sys::Char)
                };
            }
            Err(Error::Caml(CamlError::Failure(s))) => {
                unsafe {
                    let s = crate::util::CString::new(s).expect("Invalid C string");
                    crate::sys::caml_failwith(s.as_ptr() as *const ocaml_sys::Char)
                };
            }
            #[cfg(not(feature = "no-std"))]
            Err(Error::Error(e)) => {
                let s = format!("{:?}\0", e);
                unsafe { crate::sys::caml_failwith(s.as_ptr() as *const ocaml_sys::Char) };
            }
            Err(Error::NotDoubleArray) => {
                let s = "invalid double array\0";
                unsafe { crate::sys::caml_failwith(s.as_ptr() as *const ocaml_sys::Char) };
            }
            Err(Error::NotCallable) => {
                let s = "value is not callable\0";
                unsafe { crate::sys::caml_failwith(s.as_ptr() as *const ocaml_sys::Char) };
            }
        };

        unreachable!()
    }
}

unsafe impl<'a, T: FromValue<'a>> FromValue<'a> for Result<T, crate::Error> {
    fn from_value(value: Value) -> Result<T, crate::Error> {
        unsafe {
            if value.is_exception_result() {
                return Err(CamlError::Exception(value).into());
            }

            Ok(T::from_value(value))
        }
    }
}
