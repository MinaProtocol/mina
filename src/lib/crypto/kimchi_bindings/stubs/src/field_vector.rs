//! We implement a custom type for field vectors in order to quickly build field vectors from the OCaml side and avoid large vector clones.

use paste::paste;

macro_rules! impl_vector_old {
    ($name: ident, $F: ty) => {

        impl_caml_pointer!($name => Vec<$F>);

        paste! {
            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _create>]() -> $name {
                $name::create(Vec::new())
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _length>](v: $name) -> ocaml::Int {
                v.len() as isize
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _emplace_back>](mut v: $name, x: $F) {
                (*v).push(x);
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _get>](
                v: $name,
                i: ocaml::Int,
            ) -> Result<$F, ocaml::Error> {
                match v.get(i as usize) {
                    Some(x) => Ok(*x),
                    None => Err(ocaml::Error::invalid_argument("vector_get")
                        .err()
                        .unwrap()),
                }
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _set>](
                mut v: $name,
                i: ocaml::Int,
                value: $F,
            ) -> Result<(), ocaml::Error> {
                match v.get_mut(i as usize) {
                    Some(x) => Ok(*x = value),
                    None => Err(ocaml::Error::invalid_argument("vector_set")
                        .err()
                        .unwrap()),
                }
            }
        }
    };
}

#[allow(unused_macros)]
macro_rules! impl_vector {
    ($name: ident, $F: ty) => {

        impl_shared_rwlock!($name => Vec<$F>);

        paste! {
            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _create>]() -> $name {
                $name::new(Vec::new())
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _length>](v: $name) -> Result<ocaml::Int, ocaml::Error> {
                let v = v.read().map_err(|_| ocaml::CamlError::Failure("vector_length: could not capture lock"))?;
                Ok(v.len() as isize)
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _emplace_back>](v: $name, x: $F) -> Result<(), ocaml::Error> {
                let mut v = v.write().map_err(|_| ocaml::CamlError::Failure("vector_emplace_back: could not capture lock"))?;
                v.push(x);
                Ok(())
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _get>](
                v: $name,
                i: ocaml::Int,
            ) -> Result<$F, ocaml::Error> {
                let v = v.read().map_err(|_| ocaml::CamlError::Failure("vector_get: could not capture lock"))?;
                match v.get(i as usize) {
                    Some(x) => Ok(*x),
                    None => Err(ocaml::Error::invalid_argument("vector_get")
                        .err()
                        .unwrap()),
                }
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _set>](
                v: $name,
                i: ocaml::Int,
                value: $F,
            ) -> Result<(), ocaml::Error> {
                let mut v = v.write().map_err(|_| ocaml::CamlError::Failure("vector_set: could not capture lock"))?;
                match v.get_mut(i as usize) {
                    Some(x) => Ok(*x = value),
                    None => Err(ocaml::Error::invalid_argument("vector_set")
                        .err()
                        .unwrap()),
                }
            }
        }
    }
}

pub mod fp {
    use super::*;
    use mina_curves::pasta::Fp;

    impl_vector_old!(CamlFpVector, Fp);
}

pub mod fq {
    use super::*;
    use mina_curves::pasta::Fq;

    impl_vector_old!(CamlFqVector, Fq);
}
