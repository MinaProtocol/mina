use crate::pasta_fp::CamlFp;
use ark_ec::{AffineCurve, ProjectiveCurve};
use ark_ff::{One, UniformRand};
use mina_curves::pasta::{
    fp::Fp,
    fq::Fq,
    vesta::{Affine as GAffine, Projective},
};
use rand::rngs::StdRng;
use std::ops::{Add, Deref, Neg, Sub};

//
// Wrapper struct to implement OCaml bindings
//

#[derive(Clone, Copy)]
pub struct GProjective(pub Projective);

// handy implementations

impl Add for &GProjective {
    type Output = GProjective;

    fn add(self, other: Self) -> Self::Output {
        GProjective(self.0 + other.0)
    }
}

impl Sub for &GProjective {
    type Output = GProjective;

    fn sub(self, other: Self) -> Self::Output {
        GProjective(self.0 - other.0)
    }
}

impl Neg for &GProjective {
    type Output = GProjective;

    fn neg(self) -> Self::Output {
        GProjective(-self.0)
    }
}

impl Deref for GProjective {
    type Target = Projective;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

// ocaml stuff

unsafe impl ocaml::FromValue for GProjective {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Projective> = ocaml::FromValue::from_value(value);
        Self(x.as_ref().clone())
    }
}

impl GProjective {
    extern "C" fn caml_pointer_finalize(v: ocaml::Value) {
        let v: ocaml::Pointer<Self> = ocaml::FromValue::from_value(v);
        unsafe {
            v.drop_in_place();
        }
    }
}

ocaml::custom!(GProjective {
    finalize: GProjective::caml_pointer_finalize,
});

//
//
//

#[ocaml::func]
pub fn caml_pasta_vesta_one() -> GProjective {
    GProjective(Projective::prime_subgroup_generator())
}

#[ocaml::func]
pub fn caml_pasta_vesta_add(
    x: ocaml::Pointer<GProjective>,
    y: ocaml::Pointer<GProjective>,
) -> GProjective {
    x.as_ref() + y.as_ref()
}

#[ocaml::func]
pub fn caml_pasta_vesta_sub(
    x: ocaml::Pointer<GProjective>,
    y: ocaml::Pointer<GProjective>,
) -> GProjective {
    x.as_ref() - y.as_ref()
}

#[ocaml::func]
pub fn caml_pasta_vesta_negate(x: ocaml::Pointer<GProjective>) -> GProjective {
    -x.as_ref()
}

#[ocaml::func]
pub fn caml_pasta_vesta_double(x: ocaml::Pointer<GProjective>) -> GProjective {
    GProjective(x.as_ref().0.double())
}

#[ocaml::func]
pub fn caml_pasta_vesta_scale(
    x: ocaml::Pointer<GProjective>,
    y: ocaml::Pointer<Fp>,
) -> GProjective {
    let res = x.as_ref().0.mul(&y.as_ref().0);
    GProjective(res)
}

#[ocaml::func]
pub fn caml_pasta_vesta_random() -> GProjective {
    let rng = &mut rand::rngs::OsRng;
    UniformRand::rand(rng)
}

#[ocaml::func]
pub fn caml_pasta_vesta_rng(i: ocaml::Int) -> GProjective {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    UniformRand::rand(&mut rng)
}

#[ocaml::func]
pub extern "C" fn caml_pasta_vesta_endo_base() -> Fq {
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffine>();
    endo_q
}

#[ocaml::func]
pub extern "C" fn caml_pasta_vesta_endo_scalar() -> Fp {
    let (_endo_q, endo_r) = commitment_dlog::srs::endos::<GAffine>();
    endo_r
}

#[ocaml::func]
pub fn caml_pasta_vesta_to_affine(x: ocaml::Pointer<GProjective>) -> GAffine {
    x.as_ref().into_affine().into()
}

#[ocaml::func]
pub fn caml_pasta_vesta_of_affine(x: GAffine) -> GProjective {
    Into::<GAffine>::into(x).into_projective()
}

#[ocaml::func]
pub fn caml_pasta_vesta_of_affine_coordinates(x: Fq, y: Fq) -> GProjective {
    let res = Projective::new(x, y, Fq::one());
    GProjective(res)
}

#[ocaml::func]
pub fn caml_pasta_vesta_affine_deep_copy(x: GAffine) -> GAffine {
    x
}
