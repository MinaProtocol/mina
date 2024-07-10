use crate::*;

/// CustomOps duplicates `sys::custom::custom_operations` to provide a slightly nicer experience in
/// Rust
///
/// This should rarely be constructed manually, `custom!` simplifies the process of creating custom
/// types.
///
/// See [the struct
/// custom_operations](https://caml.inria.fr/pub/docs/manual-ocaml/intfc.html#ss:c-custom-ops)
/// section in the OCaml manual for more information about each field
#[derive(Clone)]
#[repr(C)]
#[allow(missing_docs)]
pub struct CustomOps {
    pub identifier: *const ocaml_sys::Char,
    pub finalize: Option<unsafe extern "C" fn(v: Raw)>,
    pub compare: Option<unsafe extern "C" fn(v1: Raw, v2: Raw) -> i32>,
    pub hash: Option<unsafe extern "C" fn(v: Raw) -> Int>,

    pub serialize: Option<unsafe extern "C" fn(v: Raw, bsize_32: *mut Uint, bsize_64: *mut Uint)>,
    pub deserialize: Option<unsafe extern "C" fn(dst: *mut core::ffi::c_void) -> Uint>,
    pub compare_ext: Option<unsafe extern "C" fn(v1: Raw, v2: Raw) -> i32>,
    pub fixed_length: *const sys::custom_fixed_length,
}

impl Default for CustomOps {
    fn default() -> CustomOps {
        DEFAULT_CUSTOM_OPS
    }
}

/// `Custom` is used to define OCaml types that wrap existing Rust types, but are owned by the
/// garbage collector
///
/// A custom type can only be converted to a `Value` using `IntoValue`, but can't be converted from a
/// value. Once the Rust value is owned by OCaml it should be accessed using `ocaml::Pointer` to
/// avoid reallocating the same value
///
/// ```rust
/// struct Example(ocaml::Int);
///
/// ocaml::custom! (Example);
///
/// #[cfg(feature = "derive")]
/// #[ocaml::func]
/// pub unsafe fn example() -> Example {
///     Example(123)
/// }
///
/// #[cfg(feature = "derive")]
/// #[ocaml::func]
/// pub unsafe fn example_value(x: ocaml::Pointer<Example>) -> ocaml::Int {
///     x.as_ref().0
/// }
/// ```
pub trait Custom {
    /// Custom type name
    const NAME: &'static str;

    /// Custom type fixed length
    const FIXED_LENGTH: Option<sys::custom_fixed_length> = None;

    /// Custom operations
    const OPS: CustomOps;

    /// `used` parameter to `alloc_custom`. This helps determine the frequency of garbage
    /// collection related to this custom type.
    const USED: usize = 0;

    /// `max` parameter to `alloc_custom`. This helps determine the frequency of garbage collection
    /// related to this custom type
    const MAX: usize = 1;

    /// Get a static reference the this type's `CustomOps` implementation
    fn ops() -> &'static CustomOps {
        &Self::OPS
    }
}

unsafe impl<T: 'static + Custom> IntoValue for T {
    fn into_value(self, rt: &Runtime) -> Value {
        let val: crate::Pointer<T> = Pointer::alloc_custom(self);
        val.into_value(rt)
    }
}

/// Create a custom OCaml type from an existing Rust type
///
/// See [the struct
/// custom_operations](https://caml.inria.fr/pub/docs/manual-ocaml/intfc.html#ss:c-custom-ops)
/// section in the OCaml manual for more information about each field
///
/// ```rust
/// struct MyType {
///     s: String,
///     i: i32,
/// }
///
/// extern "C" fn mytype_finalizer(_: ocaml::Raw) {
///     println!("This runs when the value gets garbage collected");
/// }
///
/// unsafe extern "C" fn mytype_compare(a: ocaml::Raw, b: ocaml::Raw) -> i32 {
///     let a = a.as_pointer::<MyType>();
///     let b = b.as_pointer::<MyType>();
///
///     let a_i = a.as_ref().i;
///     let b_i = b.as_ref().i;
///
///     if a_i == b_i {
///         return 0
///     }
///
///     if a_i < b_i {
///         return -1;
///     }
///
///     1
/// }
///
/// ocaml::custom!(MyType {
///     finalize: mytype_finalizer,
///     compare: mytype_compare,
/// });
///
/// // This is equivalent to
/// struct MyType2 {
///     s: String,
///     i: i32,
/// }
///
/// impl ocaml::Custom for MyType2 {
///     const NAME: &'static str = "rust.MyType\0";
///
///     const OPS: ocaml::custom::CustomOps = ocaml::custom::CustomOps {
///         identifier: Self::NAME.as_ptr() as *mut ocaml::sys::Char,
///         finalize: Some(mytype_finalizer),
///         compare: Some(mytype_compare),
///         .. ocaml::custom::DEFAULT_CUSTOM_OPS
///     };
/// }
/// ```
///
/// Additionally, `custom` can be used inside the `impl` block:
///
/// ```rust
/// extern "C" fn implexample_finalizer(_: ocaml::Raw) {
///     println!("This runs when the value gets garbage collected");
/// }
///
/// struct ImplExample<'a>(&'a str);
///
/// impl<'a> ocaml::Custom for ImplExample<'a> {
///     ocaml::custom! {
///         name: "rust.ImplExample",
///         finalize: implexample_finalizer
///     }
/// }
///
/// // This is equivalent to:
///
/// struct ImplExample2<'a>(&'a str);
///
/// ocaml::custom!(ImplExample2<'a> {
///     finalize: implexample_finalizer,
/// });
/// ```
#[macro_export]
macro_rules! custom {
    ($name:ident $(<$t:tt>)? $({$($k:ident : $v:expr),* $(,)? })?) => {
        impl $(<$t>)? $crate::Custom for $name $(<$t>)? {
            $crate::custom! {
                name: concat!("rust.", stringify!($name))
                $(, $($k: $v),*)?
            }
        }
    };
    {name : $name:expr $(, fixed_length: $fl:expr)? $(, $($k:ident : $v:expr),*)? $(,)? } => {
        const NAME: &'static str = concat!($name, "\0");

        const OPS: $crate::custom::CustomOps = $crate::custom::CustomOps {
            identifier: Self::NAME.as_ptr() as *const $crate::sys::Char,
            $($($k: Some($v),)*)?
            .. $crate::custom::DEFAULT_CUSTOM_OPS
        };
    };
}

/// Derives `Custom` with the given finalizer for a type
///
/// ```rust,no_run
/// use ocaml::FromValue;
///
/// struct MyType {
///     name: String
/// }
///
/// unsafe extern "C" fn mytype_finalizer(v: ocaml::Raw) {
///     let p = v.as_pointer::<MyType>();
///     p.drop_in_place()
/// }
///
/// ocaml::custom_finalize!(MyType, mytype_finalizer);
///
/// // Which is a shortcut for:
///
/// struct MyType2 {
///     name: String
/// }
///
/// ocaml::custom!(MyType2 {
///     finalize: mytype_finalizer
/// });
/// ```
#[macro_export]
macro_rules! custom_finalize {
    ($name:ident  $(<$t:tt>)?, $f:path) => {
        $crate::custom!($name { finalize: $f });
    };
}

/// Default CustomOps
pub const DEFAULT_CUSTOM_OPS: CustomOps = CustomOps {
    identifier: core::ptr::null(),
    fixed_length: core::ptr::null_mut(),
    compare: None,
    compare_ext: None,
    deserialize: None,
    finalize: None,
    hash: None,
    serialize: None,
};
