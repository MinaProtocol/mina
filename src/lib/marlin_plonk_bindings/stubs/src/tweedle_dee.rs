use algebra::{
    curves::{AffineCurve, ProjectiveCurve},
    tweedle::{
        dee::{Affine as GAffine, Projective as GProjective},
        fp::Fp,
        fq::Fq,
    },
    One, UniformRand,
};
use rand::rngs::StdRng;

#[ocaml::func]
pub fn caml_tweedle_dee_one() -> GProjective {
    GProjective::prime_subgroup_generator()
}

#[ocaml::func]
pub fn caml_tweedle_dee_add(
    x: ocaml::Pointer<GProjective>,
    y: ocaml::Pointer<GProjective>,
) -> GProjective {
    (*x.as_ref()) + (*y.as_ref())
}

#[ocaml::func]
pub fn caml_tweedle_dee_sub(
    x: ocaml::Pointer<GProjective>,
    y: ocaml::Pointer<GProjective>,
) -> GProjective {
    (*x.as_ref()) - (*y.as_ref())
}

#[ocaml::func]
pub fn caml_tweedle_dee_negate(x: ocaml::Pointer<GProjective>) -> GProjective {
    -(*x.as_ref())
}

#[ocaml::func]
pub fn caml_tweedle_dee_double(x: ocaml::Pointer<GProjective>) -> GProjective {
    x.as_ref().double()
}

#[ocaml::func]
pub fn caml_tweedle_dee_scale(x: ocaml::Pointer<GProjective>, y: Fp) -> GProjective {
    x.as_ref().mul(y)
}

#[ocaml::func]
pub fn caml_tweedle_dee_random() -> GProjective {
    let rng = &mut rand_core::OsRng;
    UniformRand::rand(rng)
}

#[ocaml::func]
pub fn caml_tweedle_dee_rng(i: ocaml::Int) -> GProjective {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    UniformRand::rand(&mut rng)
}

#[ocaml::func]
pub extern "C" fn caml_tweedle_dee_endo_base() -> Fq {
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffine>();
    endo_q
}

#[ocaml::func]
pub extern "C" fn caml_tweedle_dee_endo_scalar() -> Fp {
    let (_endo_q, endo_r) = commitment_dlog::srs::endos::<GAffine>();
    endo_r
}

#[ocaml::func]
pub fn caml_tweedle_dee_to_affine(x: ocaml::Pointer<GProjective>) -> GAffine {
    x.as_ref().into_affine().into()
}

#[ocaml::func]
pub fn caml_tweedle_dee_of_affine(x: GAffine) -> GProjective {
    Into::<GAffine>::into(x).into_projective()
}

#[ocaml::func]
pub fn caml_tweedle_dee_of_affine_coordinates(x: Fq, y: Fq) -> GProjective {
    GProjective::new(x, y, Fq::one())
}

#[ocaml::func]
pub fn caml_tweedle_dee_affine_deep_copy(x: GAffine) -> GAffine {
    x
}
