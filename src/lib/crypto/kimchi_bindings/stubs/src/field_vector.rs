//! We implement a custom type for field vectors in order to quickly build field vectors from the OCaml side and avoid large vector clones.

use paste::paste;

macro_rules! impl_vector_old {
    ($name: ident, $CamlF: ty, $F: ty) => {

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
            pub fn [<$name:snake _emplace_back>](mut v: $name, x: $CamlF) {
                (*v).push(x.into());
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _get>](
                v: $name,
                i: ocaml::Int,
            ) -> Result<$CamlF, ocaml::Error> {
                match v.get(i as usize) {
                    Some(x) => Ok(x.into()),
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
                value: $CamlF,
            ) -> Result<(), ocaml::Error> {
                match v.get_mut(i as usize) {
                    Some(x) => Ok(*x = value.into()),
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
    ($name: ident, $CamlF: ty, $F: ty) => {

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
            pub fn [<$name:snake _emplace_back>](v: $name, x: $CamlF) -> Result<(), ocaml::Error> {
                let mut v = v.write().map_err(|_| ocaml::CamlError::Failure("vector_emplace_back: could not capture lock"))?;
                v.push(x.into());
                Ok(())
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _get>](
                v: $name,
                i: ocaml::Int,
            ) -> Result<$CamlF, ocaml::Error> {
                let v = v.read().map_err(|_| ocaml::CamlError::Failure("vector_get: could not capture lock"))?;
                match v.get(i as usize) {
                    Some(x) => Ok(x.into()),
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
                value: $CamlF,
            ) -> Result<(), ocaml::Error> {
                let mut v = v.write().map_err(|_| ocaml::CamlError::Failure("vector_set: could not capture lock"))?;
                match v.get_mut(i as usize) {
                    Some(x) => Ok(*x = value.into()),
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
    use crate::arkworks::CamlFp;
    use mina_curves::pasta::fp::Fp;

    impl_vector_old!(CamlFpVector, CamlFp, Fp);
}

pub mod fq {
    use super::*;
    use crate::arkworks::CamlFq;
    use mina_curves::pasta::fq::Fq;

    impl_vector_old!(CamlFqVector, CamlFq, Fq);
}
