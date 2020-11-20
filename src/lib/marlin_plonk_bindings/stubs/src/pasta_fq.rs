use crate::bigint_256::{CamlBigint256, CamlBigint256Ptr};
use algebra::{
    fields::{Field, FpParameters, PrimeField, SquareRootField},
    pasta::fq::{Fq, FqParameters as Fq_params},
    FftField, One, UniformRand, Zero,
};
use ff_fft::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use num_bigint::BigUint;
use oracle::sponge::ScalarChallenge;
use rand::rngs::StdRng;
use std::cmp::Ordering::{Equal, Greater, Less};

#[derive(Copy, Clone)]
pub struct CamlPastaFq(pub Fq);

pub type CamlPastaFqPtr = ocaml::Pointer<CamlPastaFq>;

extern "C" fn caml_pasta_fq_compare_raw(x: ocaml::Value, y: ocaml::Value) -> libc::c_int {
    let x: CamlPastaFqPtr = ocaml::FromValue::from_value(x);
    let y: CamlPastaFqPtr = ocaml::FromValue::from_value(y);

    match x.as_ref().0.cmp(&y.as_ref().0) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

impl From<&CamlPastaFq> for CamlBigint256 {
    fn from(x: &CamlPastaFq) -> CamlBigint256 {
        CamlBigint256(x.0.into_repr())
    }
}

impl From<&CamlBigint256> for CamlPastaFq {
    fn from(x: &CamlBigint256) -> CamlPastaFq {
        CamlPastaFq(Fq::from_repr(x.0))
    }
}

impl From<Fq> for CamlPastaFq {
    fn from(x: Fq) -> Self {
        CamlPastaFq(x)
    }
}

impl From<CamlPastaFq> for Fq {
    fn from(x: CamlPastaFq) -> Self {
        x.0
    }
}

impl From<ScalarChallenge<Fq>> for CamlPastaFq {
    fn from(x: ScalarChallenge<Fq>) -> Self {
        CamlPastaFq(x.0)
    }
}

impl From<CamlPastaFq> for ScalarChallenge<Fq> {
    fn from(x: CamlPastaFq) -> Self {
        ScalarChallenge(x.0)
    }
}

impl std::fmt::Display for CamlPastaFq {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        CamlBigint256::from(self).fmt(f)
    }
}

ocaml::custom!(CamlPastaFq {
    compare: caml_pasta_fq_compare_raw,
});

unsafe impl ocaml::FromValue for CamlPastaFq {
    fn from_value(value: ocaml::Value) -> Self {
        CamlPastaFqPtr::from_value(value).as_ref().clone()
    }
}

#[ocaml::func]
pub fn caml_pasta_fq_size_in_bits() -> ocaml::Int {
    Fq_params::MODULUS_BITS as isize
}

#[ocaml::func]
pub fn caml_pasta_fq_size() -> CamlBigint256 {
    CamlBigint256(Fq_params::MODULUS)
}

#[ocaml::func]
pub fn caml_pasta_fq_add(x: CamlPastaFqPtr, y: CamlPastaFqPtr) -> CamlPastaFq {
    CamlPastaFq(x.as_ref().0 + y.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_fq_sub(x: CamlPastaFqPtr, y: CamlPastaFqPtr) -> CamlPastaFq {
    CamlPastaFq(x.as_ref().0 - y.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_fq_negate(x: CamlPastaFqPtr) -> CamlPastaFq {
    CamlPastaFq(-x.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_fq_mul(x: CamlPastaFqPtr, y: CamlPastaFqPtr) -> CamlPastaFq {
    CamlPastaFq(x.as_ref().0 * y.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_fq_div(x: CamlPastaFqPtr, y: CamlPastaFqPtr) -> CamlPastaFq {
    CamlPastaFq(x.as_ref().0 / y.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_fq_inv(x: CamlPastaFqPtr) -> Option<CamlPastaFq> {
    match x.as_ref().0.inverse() {
        Some(x) => Some(CamlPastaFq(x)),
        None => None,
    }
}

#[ocaml::func]
pub fn caml_pasta_fq_square(x: CamlPastaFqPtr) -> CamlPastaFq {
    CamlPastaFq(x.as_ref().0.square())
}

#[ocaml::func]
pub fn caml_pasta_fq_is_square(x: CamlPastaFqPtr) -> bool {
    let s = x.as_ref().0.pow(Fq_params::MODULUS_MINUS_ONE_DIV_TWO);
    s.is_zero() || s.is_one()
}

#[ocaml::func]
pub fn caml_pasta_fq_sqrt(x: CamlPastaFqPtr) -> Option<CamlPastaFq> {
    match x.as_ref().0.sqrt() {
        Some(x) => Some(CamlPastaFq(x)),
        None => None,
    }
}

#[ocaml::func]
pub fn caml_pasta_fq_of_int(i: ocaml::Int) -> CamlPastaFq {
    CamlPastaFq(Fq::from(i as u64))
}

#[ocaml::func]
pub fn caml_pasta_fq_to_string(x: CamlPastaFqPtr) -> String {
    x.as_ref().to_string()
}

#[ocaml::func]
pub fn caml_pasta_fq_of_string(s: &[u8]) -> Result<CamlPastaFq, ocaml::Error> {
    match BigUint::parse_bytes(s, 10) {
        Some(data) => Ok(CamlPastaFq::from(&(CamlBigint256::from(&data)))),
        None => Err(ocaml::Error::invalid_argument("caml_pasta_fq_of_string")
            .err()
            .unwrap()),
    }
}

#[ocaml::func]
pub fn caml_pasta_fq_print(x: CamlPastaFqPtr) {
    println!("{}", x.as_ref());
}

#[ocaml::func]
pub fn caml_pasta_fq_copy(mut x: CamlPastaFqPtr, y: CamlPastaFqPtr) {
    *x.as_mut() = *y.as_ref()
}

#[ocaml::func]
pub fn caml_pasta_fq_mut_add(mut x: CamlPastaFqPtr, y: CamlPastaFqPtr) {
    x.as_mut().0 += y.as_ref().0;
}

#[ocaml::func]
pub fn caml_pasta_fq_mut_sub(mut x: CamlPastaFqPtr, y: CamlPastaFqPtr) {
    x.as_mut().0 -= y.as_ref().0;
}

#[ocaml::func]
pub fn caml_pasta_fq_mut_mul(mut x: CamlPastaFqPtr, y: CamlPastaFqPtr) {
    x.as_mut().0 *= y.as_ref().0;
}

#[ocaml::func]
pub fn caml_pasta_fq_mut_square(mut x: CamlPastaFqPtr) {
    x.as_mut().0.square_in_place();
}

#[ocaml::func]
pub fn caml_pasta_fq_compare(x: CamlPastaFqPtr, y: CamlPastaFqPtr) -> ocaml::Int {
    match x.as_ref().0.cmp(&y.as_ref().0) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

#[ocaml::func]
pub fn caml_pasta_fq_equal(x: CamlPastaFqPtr, y: CamlPastaFqPtr) -> bool {
    x.as_ref().0 == y.as_ref().0
}

#[ocaml::func]
pub fn caml_pasta_fq_random() -> CamlPastaFq {
    CamlPastaFq(UniformRand::rand(&mut rand::thread_rng()))
}

#[ocaml::func]
pub fn caml_pasta_fq_rng(i: ocaml::Int) -> CamlPastaFq {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    CamlPastaFq(UniformRand::rand(&mut rng))
}

#[ocaml::func]
pub fn caml_pasta_fq_to_bigint(x: CamlPastaFqPtr) -> CamlBigint256 {
    x.as_ref().into()
}

#[ocaml::func]
pub fn caml_pasta_fq_of_bigint(x: CamlBigint256Ptr) -> CamlPastaFq {
    x.as_ref().into()
}

#[ocaml::func]
pub fn caml_pasta_fq_two_adic_root_of_unity() -> CamlPastaFq {
    CamlPastaFq(FftField::two_adic_root_of_unity())
}

#[ocaml::func]
pub fn caml_pasta_fq_domain_generator(
    log2_size: ocaml::Int,
) -> Result<CamlPastaFq, ocaml::Error> {
    match Domain::new(1 << log2_size) {
        Some(x) => Ok(CamlPastaFq(x.group_gen)),
        None => Err(
            ocaml::Error::invalid_argument("caml_pasta_fq_domain_generator")
                .err()
                .unwrap(),
        ),
    }
}

#[ocaml::func]
pub fn caml_pasta_fq_to_bytes(x: CamlPastaFqPtr) -> ocaml::Value {
    let len = std::mem::size_of::<CamlPastaFq>();
    let str = unsafe { ocaml::sys::caml_alloc_string(len) };
    unsafe {
        core::ptr::copy_nonoverlapping(x.as_ptr() as *const u8, ocaml::sys::string_val(str), len);
    }
    ocaml::Value(str)
}

#[ocaml::func]
pub fn caml_pasta_fq_of_bytes(x: &[u8]) -> Result<CamlPastaFq, ocaml::Error> {
    let len = std::mem::size_of::<CamlPastaFq>();
    if x.len() != len {
        ocaml::Error::failwith("caml_pasta_fq_of_bytes")?;
    };
    let x = unsafe { *(x.as_ptr() as *const CamlPastaFq) };
    Ok(x)
}
