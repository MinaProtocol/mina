use crate::bigint_256::{CamlBigint256, CamlBigint256Ptr};
use algebra::{
    fields::{Field, FpParameters, PrimeField, SquareRootField},
    pasta::fp::{Fp, FpParameters as Fp_params},
    FftField, One, UniformRand, Zero,
};
use ff_fft::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use num_bigint::BigUint;
use oracle::sponge::ScalarChallenge;
use rand::rngs::StdRng;
use std::cmp::Ordering::{Equal, Greater, Less};

#[derive(Copy, Clone)]
pub struct CamlPastaFp(pub Fp);

pub type CamlPastaFpPtr = ocaml::Pointer<CamlPastaFp>;

extern "C" fn caml_pasta_fp_compare_raw(x: ocaml::Value, y: ocaml::Value) -> libc::c_int {
    let x: CamlPastaFpPtr = ocaml::FromValue::from_value(x);
    let y: CamlPastaFpPtr = ocaml::FromValue::from_value(y);

    match x.as_ref().0.cmp(&y.as_ref().0) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

impl From<&CamlPastaFp> for CamlBigint256 {
    fn from(x: &CamlPastaFp) -> CamlBigint256 {
        CamlBigint256(x.0.into_repr())
    }
}

impl From<&CamlBigint256> for CamlPastaFp {
    fn from(x: &CamlBigint256) -> CamlPastaFp {
        CamlPastaFp(Fp::from_repr(x.0))
    }
}

impl From<Fp> for CamlPastaFp {
    fn from(x: Fp) -> Self {
        CamlPastaFp(x)
    }
}

impl From<CamlPastaFp> for Fp {
    fn from(x: CamlPastaFp) -> Self {
        x.0
    }
}

impl From<ScalarChallenge<Fp>> for CamlPastaFp {
    fn from(x: ScalarChallenge<Fp>) -> Self {
        CamlPastaFp(x.0)
    }
}

impl From<CamlPastaFp> for ScalarChallenge<Fp> {
    fn from(x: CamlPastaFp) -> Self {
        ScalarChallenge(x.0)
    }
}

impl std::fmt::Display for CamlPastaFp {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        CamlBigint256::from(self).fmt(f)
    }
}

ocaml::custom!(CamlPastaFp {
    compare: caml_pasta_fp_compare_raw,
});

unsafe impl ocaml::FromValue for CamlPastaFp {
    fn from_value(value: ocaml::Value) -> Self {
        CamlPastaFpPtr::from_value(value).as_ref().clone()
    }
}

#[ocaml::func]
pub fn caml_pasta_fp_size_in_bits() -> ocaml::Int {
    Fp_params::MODULUS_BITS as isize
}

#[ocaml::func]
pub fn caml_pasta_fp_size() -> CamlBigint256 {
    CamlBigint256(Fp_params::MODULUS)
}

#[ocaml::func]
pub fn caml_pasta_fp_add(x: CamlPastaFpPtr, y: CamlPastaFpPtr) -> CamlPastaFp {
    CamlPastaFp(x.as_ref().0 + y.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_fp_sub(x: CamlPastaFpPtr, y: CamlPastaFpPtr) -> CamlPastaFp {
    CamlPastaFp(x.as_ref().0 - y.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_fp_negate(x: CamlPastaFpPtr) -> CamlPastaFp {
    CamlPastaFp(-x.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_fp_mul(x: CamlPastaFpPtr, y: CamlPastaFpPtr) -> CamlPastaFp {
    CamlPastaFp(x.as_ref().0 * y.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_fp_div(x: CamlPastaFpPtr, y: CamlPastaFpPtr) -> CamlPastaFp {
    CamlPastaFp(x.as_ref().0 / y.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_fp_inv(x: CamlPastaFpPtr) -> Option<CamlPastaFp> {
    match x.as_ref().0.inverse() {
        Some(x) => Some(CamlPastaFp(x)),
        None => None,
    }
}

#[ocaml::func]
pub fn caml_pasta_fp_square(x: CamlPastaFpPtr) -> CamlPastaFp {
    CamlPastaFp(x.as_ref().0.square())
}

#[ocaml::func]
pub fn caml_pasta_fp_is_square(x: CamlPastaFpPtr) -> bool {
    let s = x.as_ref().0.pow(Fp_params::MODULUS_MINUS_ONE_DIV_TWO);
    s.is_zero() || s.is_one()
}

#[ocaml::func]
pub fn caml_pasta_fp_sqrt(x: CamlPastaFpPtr) -> Option<CamlPastaFp> {
    match x.as_ref().0.sqrt() {
        Some(x) => Some(CamlPastaFp(x)),
        None => None,
    }
}

#[ocaml::func]
pub fn caml_pasta_fp_of_int(i: ocaml::Int) -> CamlPastaFp {
    CamlPastaFp(Fp::from(i as u64))
}

#[ocaml::func]
pub fn caml_pasta_fp_to_string(x: CamlPastaFpPtr) -> String {
    x.as_ref().to_string()
}

#[ocaml::func]
pub fn caml_pasta_fp_of_string(s: &[u8]) -> Result<CamlPastaFp, ocaml::Error> {
    match BigUint::parse_bytes(s, 10) {
        Some(data) => Ok(CamlPastaFp::from(&(CamlBigint256::from(&data)))),
        None => Err(ocaml::Error::invalid_argument("caml_pasta_fp_of_string")
            .err()
            .unwrap()),
    }
}

#[ocaml::func]
pub fn caml_pasta_fp_print(x: CamlPastaFpPtr) {
    println!("{}", x.as_ref());
}

#[ocaml::func]
pub fn caml_pasta_fp_copy(mut x: CamlPastaFpPtr, y: CamlPastaFpPtr) {
    *x.as_mut() = *y.as_ref()
}

#[ocaml::func]
pub fn caml_pasta_fp_mut_add(mut x: CamlPastaFpPtr, y: CamlPastaFpPtr) {
    x.as_mut().0 += y.as_ref().0;
}

#[ocaml::func]
pub fn caml_pasta_fp_mut_sub(mut x: CamlPastaFpPtr, y: CamlPastaFpPtr) {
    x.as_mut().0 -= y.as_ref().0;
}

#[ocaml::func]
pub fn caml_pasta_fp_mut_mul(mut x: CamlPastaFpPtr, y: CamlPastaFpPtr) {
    x.as_mut().0 *= y.as_ref().0;
}

#[ocaml::func]
pub fn caml_pasta_fp_mut_square(mut x: CamlPastaFpPtr) {
    x.as_mut().0.square_in_place();
}

#[ocaml::func]
pub fn caml_pasta_fp_compare(x: CamlPastaFpPtr, y: CamlPastaFpPtr) -> ocaml::Int {
    match x.as_ref().0.cmp(&y.as_ref().0) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

#[ocaml::func]
pub fn caml_pasta_fp_equal(x: CamlPastaFpPtr, y: CamlPastaFpPtr) -> bool {
    x.as_ref().0 == y.as_ref().0
}

#[ocaml::func]
pub fn caml_pasta_fp_random() -> CamlPastaFp {
    CamlPastaFp(UniformRand::rand(&mut rand::thread_rng()))
}

#[ocaml::func]
pub fn caml_pasta_fp_rng(i: ocaml::Int) -> CamlPastaFp {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    CamlPastaFp(UniformRand::rand(&mut rng))
}

#[ocaml::func]
pub fn caml_pasta_fp_to_bigint(x: CamlPastaFpPtr) -> CamlBigint256 {
    x.as_ref().into()
}

#[ocaml::func]
pub fn caml_pasta_fp_of_bigint(x: CamlBigint256Ptr) -> CamlPastaFp {
    x.as_ref().into()
}

#[ocaml::func]
pub fn caml_pasta_fp_two_adic_root_of_unity() -> CamlPastaFp {
    CamlPastaFp(FftField::two_adic_root_of_unity())
}

#[ocaml::func]
pub fn caml_pasta_fp_domain_generator(
    log2_size: ocaml::Int,
) -> Result<CamlPastaFp, ocaml::Error> {
    match Domain::new(1 << log2_size) {
        Some(x) => Ok(CamlPastaFp(x.group_gen)),
        None => Err(
            ocaml::Error::invalid_argument("caml_pasta_fp_domain_generator")
                .err()
                .unwrap(),
        ),
    }
}

#[ocaml::func]
pub fn caml_pasta_fp_to_bytes(x: CamlPastaFpPtr) -> ocaml::Value {
    let len = std::mem::size_of::<CamlPastaFp>();
    let str = unsafe { ocaml::sys::caml_alloc_string(len) };
    unsafe {
        core::ptr::copy_nonoverlapping(x.as_ptr() as *const u8, ocaml::sys::string_val(str), len);
    }
    ocaml::Value(str)
}

#[ocaml::func]
pub fn caml_pasta_fp_of_bytes(x: &[u8]) -> Result<CamlPastaFp, ocaml::Error> {
    let len = std::mem::size_of::<CamlPastaFp>();
    if x.len() != len {
        ocaml::Error::failwith("caml_pasta_fp_of_bytes")?;
    };
    let x = unsafe { *(x.as_ptr() as *const CamlPastaFp) };
    Ok(x)
}
