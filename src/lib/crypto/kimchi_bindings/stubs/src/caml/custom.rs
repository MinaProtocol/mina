//! Helpers to make writing OCaml wrapper types a pleasant endeavor.

/// Implement a wrapper type with a given number of optional traits to derive on the type.
macro_rules! impl_wrapper {
    ($name: ident, $typ: ty) => {
        impl_wrapper!($name, $typ,);
    };
    ($name: ident, $typ: ty, $($trait: ident),*) => {
        #[derive(ocaml_gen::CustomType, $($trait),*)]
        pub struct $name(pub $typ);

        impl std::ops::Deref for $name {
            type Target = $typ;

            fn deref(&self) -> &Self::Target {
                &self.0
            }
        }

        unsafe impl<'a> ocaml::FromValue<'a> for &$name {
            fn from_value(value: ocaml::Value) -> Self {
                let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
                x.as_ref()
            }
        }
    };
}

/// Implement a custom OCaml type
macro_rules! impl_custom {
    ($name: ident, $typ: ty) => {
        impl_wrapper!($name, $typ);
        ocaml::custom!($name);
    };
    ($name: ident, $typ: ty, $($trait: ident),*) => {
        impl_wrapper!($name, $typ, $($trait),*);
        ocaml::custom!($name);
    };
}
