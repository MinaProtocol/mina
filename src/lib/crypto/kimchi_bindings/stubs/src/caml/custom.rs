//! Helpers to make writing OCaml wrapper types a pleasant endeavor.

/// Implement a custom wrapper type with a given number of optional traits to derive on the type.
macro_rules! impl_custom {
    ($name: ident, $typ: ty) => {
        impl_custom!($name, $typ,);
    };
    ($name: ident, $typ: ty, $($trait: ident),*) => {
        #[derive(ocaml_gen::CustomType, $($trait),*)]
        pub struct $name(pub $typ);

        impl $name {
            extern "C" fn caml_pointer_finalize(v: ocaml::Raw) {
                unsafe {
                    let v: ocaml::Pointer<$name> = v.as_pointer();
                    v.drop_in_place();
                }
            }

            extern "C" fn caml_pointer_compare(_: ocaml::Raw, _: ocaml::Raw) -> i32 {
                panic!("comparing custom types is not supported");
            }
        }

        ocaml::custom!($name {
            finalize: $name::caml_pointer_finalize,
            compare: $name::caml_pointer_compare,
        });

        impl std::ops::Deref for $name {
            type Target = $typ;

            fn deref(&self) -> &Self::Target {
                &self.0
            }
        }
    };
}

/// Same as `impl_custom`, but also implements `FromValue` for the type.
/// It only works if the inner type is `Clone`.
macro_rules! impl_custom_clone {
    ($name: ident, $typ: ty) => {
        impl_custom_clone!($name, $typ,);
    };
    ($name: ident, $typ: ty, $($trait: ident),*) => {
        #[derive(ocaml_gen::CustomType, Clone, $($trait),*)]
        pub struct $name(pub $typ);

        impl $name {
            extern "C" fn caml_pointer_finalize(v: ocaml::Raw) {
                unsafe {
                    let v: ocaml::Pointer<$name> = v.as_pointer();
                    v.drop_in_place();
                }
            }

            extern "C" fn caml_pointer_compare(_: ocaml::Raw, _: ocaml::Raw) -> i32 {
                panic!("comparing custom types is not supported");
            }
        }

        ocaml::custom!($name {
            finalize: $name::caml_pointer_finalize,
            compare: $name::caml_pointer_compare,
        });

        impl std::ops::Deref for $name {
            type Target = $typ;

            fn deref(&self) -> &Self::Target {
                &self.0
            }
        }

        unsafe impl<'a> ocaml::FromValue<'a> for $name {
            fn from_value(value: ocaml::Value) -> Self {
                let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
                x.as_ref().clone()
            }
        }
    };
}
