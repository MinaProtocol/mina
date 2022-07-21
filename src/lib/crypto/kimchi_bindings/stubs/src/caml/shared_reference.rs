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
