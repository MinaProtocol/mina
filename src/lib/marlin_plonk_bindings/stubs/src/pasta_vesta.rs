use crate::pasta_fp::{CamlPastaFp, CamlPastaFpPtr};
use crate::pasta_fq::{CamlPastaFq, CamlPastaFqPtr};
use algebra::{
    curves::{AffineCurve, ProjectiveCurve},
    pasta::{
        vesta::{Affine as GAffine, Projective as GProjective},
        fq::Fq,
    },
    One, UniformRand, Zero,
};
use rand::rngs::StdRng;

use commitment_dlog::commitment::PolyComm;

/* Projective representation is raw bytes on the OCaml heap. */

pub struct CamlPastaVesta(pub GProjective);
pub type CamlPastaVestaPtr = ocaml::Pointer<CamlPastaVesta>;

ocaml::custom!(CamlPastaVesta);

#[ocaml::func]
pub fn caml_pasta_vesta_one() -> CamlPastaVesta {
    CamlPastaVesta(GProjective::prime_subgroup_generator())
}

#[ocaml::func]
pub fn caml_pasta_vesta_add(x: CamlPastaVestaPtr, y: CamlPastaVestaPtr) -> CamlPastaVesta {
    CamlPastaVesta(x.as_ref().0 + y.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_vesta_sub(x: CamlPastaVestaPtr, y: CamlPastaVestaPtr) -> CamlPastaVesta {
    CamlPastaVesta(x.as_ref().0 - y.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_vesta_negate(x: CamlPastaVestaPtr) -> CamlPastaVesta {
    CamlPastaVesta(-x.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_vesta_double(x: CamlPastaVestaPtr) -> CamlPastaVesta {
    CamlPastaVesta(x.as_ref().0.double())
}

#[ocaml::func]
pub fn caml_pasta_vesta_scale(x: CamlPastaVestaPtr, y: CamlPastaFpPtr) -> CamlPastaVesta {
    CamlPastaVesta(x.as_ref().0.mul(y.as_ref().0))
}

#[ocaml::func]
pub fn caml_pasta_vesta_random() -> CamlPastaVesta {
    let rng = &mut rand_core::OsRng;
    CamlPastaVesta(UniformRand::rand(rng))
}

#[ocaml::func]
pub fn caml_pasta_vesta_rng(i: ocaml::Int) -> CamlPastaVesta {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    CamlPastaVesta(UniformRand::rand(&mut rng))
}

#[ocaml::func]
pub extern "C" fn caml_pasta_vesta_endo_base() -> CamlPastaFq {
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffine>();
    CamlPastaFq(endo_q)
}

#[ocaml::func]
pub extern "C" fn caml_pasta_vesta_endo_scalar() -> CamlPastaFp {
    let (_endo_q, endo_r) = commitment_dlog::srs::endos::<GAffine>();
    CamlPastaFp(endo_r)
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub enum CamlPastaVestaAffine<T> {
    Infinity,
    Finite((T, T)),
}

#[ocaml::func]
pub fn caml_pasta_vesta_to_affine(x: CamlPastaVestaPtr) -> CamlPastaVestaAffine<CamlPastaFq> {
    x.as_ref().0.into_affine().into()
}

#[ocaml::func]
pub fn caml_pasta_vesta_of_affine(x: CamlPastaVestaAffine<CamlPastaFqPtr>) -> CamlPastaVesta {
    CamlPastaVesta(Into::<GAffine>::into(x).into_projective())
}

#[ocaml::func]
pub fn caml_pasta_vesta_of_affine_coordinates(
    x: CamlPastaFqPtr,
    y: CamlPastaFqPtr,
) -> CamlPastaVesta {
    CamlPastaVesta(GProjective::new(x.as_ref().0, y.as_ref().0, Fq::one()))
}

impl From<GAffine> for CamlPastaVestaAffine<CamlPastaFq> {
    fn from(p: GAffine) -> Self {
        if p.is_zero() {
            CamlPastaVestaAffine::Infinity
        } else {
            CamlPastaVestaAffine::Finite((CamlPastaFq(p.x), CamlPastaFq(p.y)))
        }
    }
}

impl From<CamlPastaVestaAffine<CamlPastaFq>> for GAffine {
    fn from(p: CamlPastaVestaAffine<CamlPastaFq>) -> Self {
        match p {
            CamlPastaVestaAffine::Infinity => GAffine::zero(),
            CamlPastaVestaAffine::Finite((x, y)) => GAffine::new(x.0, y.0, false),
        }
    }
}

impl From<CamlPastaVestaAffine<CamlPastaFqPtr>> for GAffine {
    fn from(p: CamlPastaVestaAffine<CamlPastaFqPtr>) -> Self {
        match p {
            CamlPastaVestaAffine::Infinity => GAffine::zero(),
            CamlPastaVestaAffine::Finite((x, y)) => GAffine::new(x.as_ref().0, y.as_ref().0, false),
        }
    }
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlPastaVestaPolyComm<T> {
    shifted: Option<CamlPastaVestaAffine<T>>,
    unshifted: Vec<CamlPastaVestaAffine<CamlPastaFq>>,
}

impl From<PolyComm<GAffine>> for CamlPastaVestaPolyComm<CamlPastaFq> {
    fn from(c: PolyComm<GAffine>) -> Self {
        CamlPastaVestaPolyComm {
            shifted: Option::map(c.shifted, Into::into),
            unshifted: c.unshifted.into_iter().map(From::from).collect(),
        }
    }
}

impl From<CamlPastaVestaPolyComm<CamlPastaFq>> for PolyComm<GAffine> {
    fn from(c: CamlPastaVestaPolyComm<CamlPastaFq>) -> Self {
        PolyComm {
            shifted: Option::map(c.shifted, Into::into),
            unshifted: c.unshifted.into_iter().map(From::from).collect(),
        }
    }
}

impl From<CamlPastaVestaPolyComm<CamlPastaFqPtr>> for PolyComm<GAffine> {
    fn from(c: CamlPastaVestaPolyComm<CamlPastaFqPtr>) -> Self {
        PolyComm {
            shifted: Option::map(c.shifted, Into::into),
            unshifted: c.unshifted.into_iter().map(From::from).collect(),
        }
    }
}
