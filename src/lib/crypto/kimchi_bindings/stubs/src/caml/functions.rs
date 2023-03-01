//! Helpers to make exporting OCaml functions a pleasant endeavor.

/// add the necessary attributes to all the functions listed.
macro_rules! impl_functions {
    ($fn: item) => {
        #[ocaml_gen::func]
        #[ocaml::func]
        $fn
    };
    ($fn: item $($fns: item)*) => {
        impl_functions!($fn);
        impl_functions!($($fns)*);
    };
}
