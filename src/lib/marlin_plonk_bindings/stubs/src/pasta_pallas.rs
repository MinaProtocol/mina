use crate::pasta_fp::{CamlPastaFp, CamlPastaFpPtr};
use crate::pasta_fq::{CamlPastaFq, CamlPastaFqPtr};
use algebra::{
    curves::{AffineCurve, ProjectiveCurve},
    pasta::{
        pallas::{Affine as GAffine, Projective as GProjective},
        fp::Fp,
    },
    One, UniformRand, Zero,
};
use rand::rngs::StdRng;

use commitment_dlog::commitment::PolyComm;

/* Projective representation is raw bytes on the OCaml heap. */

pub struct CamlPastaPallas(pub GProjective);
pub type CamlPastaPallasPtr = ocaml::Pointer<CamlPastaPallas>;

ocaml::custom!(CamlPastaPallas);

#[ocaml::func]
pub fn caml_pasta_pallas_one() -> CamlPastaPallas {
    CamlPastaPallas(GProjective::prime_subgroup_generator())
}

#[ocaml::func]
pub fn caml_pasta_pallas_add(x: CamlPastaPallasPtr, y: CamlPastaPallasPtr) -> CamlPastaPallas {
    CamlPastaPallas(x.as_ref().0 + y.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_pallas_sub(x: CamlPastaPallasPtr, y: CamlPastaPallasPtr) -> CamlPastaPallas {
    CamlPastaPallas(x.as_ref().0 - y.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_pallas_negate(x: CamlPastaPallasPtr) -> CamlPastaPallas {
    CamlPastaPallas(-x.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_pallas_double(x: CamlPastaPallasPtr) -> CamlPastaPallas {
    CamlPastaPallas(x.as_ref().0.double())
}

#[ocaml::func]
pub fn caml_pasta_pallas_scale(x: CamlPastaPallasPtr, y: CamlPastaFqPtr) -> CamlPastaPallas {
    CamlPastaPallas(x.as_ref().0.mul(y.as_ref().0))
}

#[ocaml::func]
pub fn caml_pasta_pallas_random() -> CamlPastaPallas {
    let rng = &mut rand_core::OsRng;
    CamlPastaPallas(UniformRand::rand(rng))
}

#[ocaml::func]
pub fn caml_pasta_pallas_rng(i: ocaml::Int) -> CamlPastaPallas {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    CamlPastaPallas(UniformRand::rand(&mut rng))
}

#[ocaml::func]
pub extern "C" fn caml_pasta_pallas_endo_base() -> CamlPastaFp {
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffine>();
    CamlPastaFp(endo_q)
}

#[ocaml::func]
pub extern "C" fn caml_pasta_pallas_endo_scalar() -> CamlPastaFq {
    let (_endo_q, endo_r) = commitment_dlog::srs::endos::<GAffine>();
    CamlPastaFq(endo_r)
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub enum CamlPastaPallasAffine<T> {
    Infinity,
    Finite((T, T)),
}

#[ocaml::func]
pub fn caml_pasta_pallas_to_affine(x: CamlPastaPallasPtr) -> CamlPastaPallasAffine<CamlPastaFp> {
    x.as_ref().0.into_affine().into()
}

#[ocaml::func]
pub fn caml_pasta_pallas_of_affine(x: CamlPastaPallasAffine<CamlPastaFpPtr>) -> CamlPastaPallas {
    CamlPastaPallas(Into::<GAffine>::into(x).into_projective())
}

#[ocaml::func]
pub fn caml_pasta_pallas_of_affine_coordinates(
    x: CamlPastaFpPtr,
    y: CamlPastaFpPtr,
) -> CamlPastaPallas {
    CamlPastaPallas(GProjective::new(x.as_ref().0, y.as_ref().0, Fp::one()))
}

impl From<GAffine> for CamlPastaPallasAffine<CamlPastaFp> {
    fn from(p: GAffine) -> Self {
        if p.is_zero() {
            CamlPastaPallasAffine::Infinity
        } else {
            CamlPastaPallasAffine::Finite((CamlPastaFp(p.x), CamlPastaFp(p.y)))
        }
    }
}

impl From<CamlPastaPallasAffine<CamlPastaFp>> for GAffine {
    fn from(p: CamlPastaPallasAffine<CamlPastaFp>) -> Self {
        match p {
            CamlPastaPallasAffine::Infinity => GAffine::zero(),
            CamlPastaPallasAffine::Finite((x, y)) => GAffine::new(x.0, y.0, false),
        }
    }
}

impl From<CamlPastaPallasAffine<CamlPastaFpPtr>> for GAffine {
    fn from(p: CamlPastaPallasAffine<CamlPastaFpPtr>) -> Self {
        match p {
            CamlPastaPallasAffine::Infinity => GAffine::zero(),
            CamlPastaPallasAffine::Finite((x, y)) => GAffine::new(x.as_ref().0, y.as_ref().0, false),
        }
    }
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlPastaPallasPolyComm<T> {
    shifted: Option<CamlPastaPallasAffine<T>>,
    unshifted: Vec<CamlPastaPallasAffine<CamlPastaFp>>,
}

impl From<PolyComm<GAffine>> for CamlPastaPallasPolyComm<CamlPastaFp> {
    fn from(c: PolyComm<GAffine>) -> Self {
        CamlPastaPallasPolyComm {
            shifted: Option::map(c.shifted, Into::into),
            unshifted: c.unshifted.into_iter().map(From::from).collect(),
        }
    }
}

impl From<CamlPastaPallasPolyComm<CamlPastaFp>> for PolyComm<GAffine> {
    fn from(c: CamlPastaPallasPolyComm<CamlPastaFp>) -> Self {
        PolyComm {
            shifted: Option::map(c.shifted, Into::into),
            unshifted: c.unshifted.into_iter().map(From::from).collect(),
        }
    }
}

impl From<CamlPastaPallasPolyComm<CamlPastaFpPtr>> for PolyComm<GAffine> {
    fn from(c: CamlPastaPallasPolyComm<CamlPastaFpPtr>) -> Self {
        PolyComm {
            shifted: Option::map(c.shifted, Into::into),
            unshifted: c.unshifted.into_iter().map(From::from).collect(),
        }
    }
}
