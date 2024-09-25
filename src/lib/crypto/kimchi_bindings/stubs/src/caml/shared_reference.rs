//! [impl_shared_reference] implements an OCaml custom type that wraps
//! around a shared reference to a Rust object.

macro_rules! impl_shared_reference {
    ($name: ident => $typ: ty) => {
        #[derive(Debug, ::ocaml_gen::CustomType)]
        pub struct $name(pub ::std::sync::Arc<$typ>);

        //
        // necessary ocaml.rs stuff
        //

        impl $name {
            extern "C" fn caml_pointer_finalize(v: ::ocaml::Raw) {
                unsafe {
                    let v: ::ocaml::Pointer<Self> = v.as_pointer();
                    v.drop_in_place();
                }
            }

            extern "C" fn caml_pointer_compare(_: ::ocaml::Raw, _: ::ocaml::Raw) -> i32 {
                // Always return equal. We can use this for sanity checks,
                // anything else using this would be broken anyway.
                0
            }

            pub fn new(x: $typ) -> Self {
                Self(::std::sync::Arc::new(x))
            }
        }

        ::ocaml::custom!($name {
            finalize: $name::caml_pointer_finalize,
            compare: $name::caml_pointer_compare,
        });

        unsafe impl<'a> ::ocaml::FromValue<'a> for $name {
            fn from_value(value: ::ocaml::Value) -> Self {
                let x: ::ocaml::Pointer<Self> = ::ocaml::FromValue::from_value(value);
                Self(x.as_ref().0.clone())
            }
        }

        //
        // useful implementations
        //

        impl ::std::ops::Deref for $name {
            type Target = ::std::sync::Arc<$typ>;

            fn deref(&self) -> &Self::Target {
                &self.0
            }
        }
    };
}

#[derive(Debug, ::ocaml_gen::CustomType)]
pub struct MutArc(pub std::sync::Arc<::std::sync::RwLock<u64>>);

impl MutArc {
    fn modify_mut_arc(data: MutArc) {
        let mut data = data.0.write().unwrap();
        *data += 1;
    }

    fn read_mut_arc(data: MutArc) -> u64 {
        let data = data.0.read().unwrap();
        *data
    }

    extern "C" fn caml_pointer_finalize(v: ::ocaml::Raw) {
        unsafe {
            let v: ::ocaml::Pointer<Self> = v.as_pointer();
            v.drop_in_place();
        }
    }

    extern "C" fn caml_pointer_compare(_: ::ocaml::Raw, _: ::ocaml::Raw) -> i32 {
        // Always return equal. We can use this for sanity checks,
        // anything else using this would be broken anyway.
        0
    }

    pub fn new(x: u64) -> Self {
        Self(::std::sync::Arc::new(::std::sync::RwLock::new(x)))
    }
}

::ocaml::custom!(MutArc {
    finalize: MutArc::caml_pointer_finalize,
    compare: MutArc::caml_pointer_compare,
});

unsafe impl<'a> ::ocaml::FromValue<'a> for MutArc {
    fn from_value(value: ::ocaml::Value) -> Self {
        let x: ::ocaml::Pointer<Self> = ::ocaml::FromValue::from_value(value);
        Self(x.as_ref().0.clone())
    }
}

//
// useful implementations
//

impl ::std::ops::Deref for MutArc {
    type Target = ::std::sync::Arc<::std::sync::RwLock<u64>>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

//macro_rules! impl_shared_mutable_reference {
//    ($name: ident => $typ: ty) => {
//        #[derive(Debug, ::ocaml_gen::CustomType)]
//        pub struct $name(pub ::std::sync::Arc<::std::sync::Mutex<$typ>>);
//
//        //
//        // necessary ocaml.rs stuff
//        //
//
//        impl $name {
//            extern "C" fn caml_pointer_finalize(v: ::ocaml::Raw) {
//                unsafe {
//                    let v: ::ocaml::Pointer<Self> = v.as_pointer();
//                    v.drop_in_place();
//                }
//            }
//
//            extern "C" fn caml_pointer_compare(_: ::ocaml::Raw, _: ::ocaml::Raw) -> i32 {
//                // Always return equal. We can use this for sanity checks,
//                // anything else using this would be broken anyway.
//                0
//            }
//
//            pub fn new(x: $typ) -> Self {
//                Self(::std::sync::Arc::new(x))
//            }
//        }
//
//        ::ocaml::custom!($name {
//            finalize: $name::caml_pointer_finalize,
//            compare: $name::caml_pointer_compare,
//        });
//
//        unsafe impl<'a> ::ocaml::FromValue<'a> for $name {
//            fn from_value(value: ::ocaml::Value) -> Self {
//                let x: ::ocaml::Pointer<Self> = ::ocaml::FromValue::from_value(value);
//                Self(x.as_ref().0.clone())
//            }
//        }
//
//        //
//        // useful implementations
//        //
//
//        impl ::std::ops::Deref for $name {
//            type Target = ::std::sync::Arc<$typ>;
//
//            fn deref(&self) -> &Self::Target {
//                &self.0
//            }
//        }
//    };
//}
