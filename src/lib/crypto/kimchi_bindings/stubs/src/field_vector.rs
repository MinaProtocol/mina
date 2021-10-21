//! TKTK
//!
use paste::paste;

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
            pub fn [<$name:snake _length>](v: $name) -> ocaml::Int {
                let v = v.read().unwrap();
                v.len() as isize
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _emplace_back>](v: $name, x: $CamlF) {
                let mut v = v.write().unwrap();
                v.push(x.into());
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _get>](
                v: $name,
                i: ocaml::Int,
            ) -> Result<$CamlF, ocaml::Error> {
                let v = v.read().unwrap();
                match v.get(i as usize) {
                    Some(x) => Ok(x.into()),
                    None => Err(ocaml::Error::invalid_argument("caml_pasta_fp_vector_get")
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

    impl_vector!(CamlFpVector, CamlFp, Fp);
}

pub mod fq {
    use super::*;
    use crate::arkworks::CamlFq;
    use mina_curves::pasta::fq::Fq;

    impl_vector!(CamlFqVector, CamlFq, Fq);
}
