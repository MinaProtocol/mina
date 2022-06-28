use ark_ec::{AffineCurve, ProjectiveCurve};
use ark_ff::UniformRand;
use paste::paste;
use rand::rngs::StdRng;

macro_rules! impl_projective {
    ($name: ident, $GroupProjective: ty, $CamlG: ty, $CamlScalarField: ty, $BaseField: ty, $CamlBaseField: ty, $Projective: ty) => {

        paste! {
            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<caml_ $name:snake _one>]() -> $GroupProjective {
                $Projective::prime_subgroup_generator().into()
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<caml_ $name:snake _add>](
                x: ocaml::Pointer<$GroupProjective>,
                y: ocaml::Pointer<$GroupProjective>,
            ) -> $GroupProjective {
                x.as_ref() + y.as_ref()
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<caml_ $name:snake _sub>](
                x: ocaml::Pointer<$GroupProjective>,
                y: ocaml::Pointer<$GroupProjective>,
            ) -> $GroupProjective {
                x.as_ref() - y.as_ref()
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<caml_ $name:snake _negate>](
                x: ocaml::Pointer<$GroupProjective>,
            ) -> $GroupProjective {
                -(*x.as_ref())
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<caml_ $name:snake _double>](
                x: ocaml::Pointer<$GroupProjective>,
            ) -> $GroupProjective {
                x.as_ref().double().into()
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<caml_ $name:snake _scale>](
                x: ocaml::Pointer<$GroupProjective>,
                y: $CamlScalarField,
            ) -> $GroupProjective {
                let y: ark_ff::BigInteger256 = y.into();
                x.as_ref().mul(&y).into()
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<caml_ $name:snake _random>]() -> $GroupProjective {
                let rng = &mut rand::rngs::OsRng;
                let proj: $Projective = UniformRand::rand(rng);
                proj.into()
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<caml_ $name:snake _rng>](i: ocaml::Int) -> $GroupProjective {
                // We only care about entropy here, so we force a conversion i32 -> u32.
                let i: u64 = (i as u32).into();
                let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
                let proj: $Projective = UniformRand::rand(&mut rng);
                proj.into()
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub extern "C" fn [<caml_ $name:snake _endo_base>]() -> $CamlBaseField {
                let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffine>();
                endo_q.into()
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub extern "C" fn [<caml_ $name:snake _endo_scalar>]() -> $CamlScalarField {
                let (_endo_q, endo_r) = commitment_dlog::srs::endos::<GAffine>();
                endo_r.into()
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<caml_ $name:snake _to_affine>](x: ocaml::Pointer<$GroupProjective>) -> $CamlG {
                x.as_ref().into_affine().into()
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<caml_ $name:snake _of_affine>](x: $CamlG) -> $GroupProjective {
                Into::<GAffine>::into(x).into_projective().into()
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<caml_ $name:snake _of_affine_coordinates>](x: $CamlBaseField, y: $CamlBaseField) -> $GroupProjective {
                let res = $Projective::new(x.into(), y.into(), <$BaseField as ark_ff::One>::one());
                res.into()
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<caml_ $name:snake _affine_deep_copy>](x: $CamlG) -> $CamlG {
                x
            }
        }
    }
}

pub mod pallas {
    use super::*;
    use crate::arkworks::{CamlFp, CamlFq, CamlGPallas, CamlGroupProjectivePallas};
    use mina_curves::pasta::{
        fp::Fp,
        pallas::{Pallas as GAffine, Projective},
    };

    impl_projective!(
        pallas,
        CamlGroupProjectivePallas,
        CamlGPallas,
        CamlFq,
        Fp,
        CamlFp,
        Projective
    );
}

pub mod vesta {
    use super::*;
    use crate::arkworks::{CamlFp, CamlFq, CamlGVesta, CamlGroupProjectiveVesta};
    use mina_curves::pasta::{
        fq::Fq,
        vesta::{Projective, Vesta as GAffine},
    };

    impl_projective!(
        vesta,
        CamlGroupProjectiveVesta,
        CamlGVesta,
        CamlFp,
        Fq,
        CamlFq,
        Projective
    );
}
