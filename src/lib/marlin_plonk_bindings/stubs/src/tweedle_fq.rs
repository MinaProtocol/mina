use crate::bigint_256;
use algebra::biginteger::BigInteger256;
use algebra::{
    fields::{Field, FpParameters, PrimeField, SquareRootField},
    tweedle::fq::{Fq, FqParameters as Fq_params},
    FftField, One, UniformRand, Zero,
};
use ff_fft::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use num_bigint::BigUint;
use oracle::sponge::ScalarChallenge;
use rand::rngs::StdRng;
use std::cmp::Ordering::{Equal, Greater, Less};

#[derive(Copy, Clone)]
pub struct CamlTweedleFq(pub Fq);

pub type CamlTweedleFqPtr = ocaml::Pointer<CamlTweedleFq>;

extern "C" fn caml_tweedle_fq_compare_raw(x: ocaml::Value, y: ocaml::Value) -> libc::c_int {
    let x: CamlTweedleFqPtr = ocaml::FromValue::from_value(x);
    let y: CamlTweedleFqPtr = ocaml::FromValue::from_value(y);

    match x.as_ref().0.cmp(&y.as_ref().0) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

impl From<&CamlTweedleFq> for BigInteger256 {
    fn from(x: &CamlTweedleFq) -> BigInteger256 {
        x.0.into_repr()
    }
}

impl From<&BigInteger256> for CamlTweedleFq {
    fn from(x: &BigInteger256) -> CamlTweedleFq {
        CamlTweedleFq(Fq::from_repr(*x))
    }
}

impl From<Fq> for CamlTweedleFq {
    fn from(x: Fq) -> Self {
        CamlTweedleFq(x)
    }
}

impl From<CamlTweedleFq> for Fq {
    fn from(x: CamlTweedleFq) -> Self {
        x.0
    }
}

impl From<ScalarChallenge<Fq>> for CamlTweedleFq {
    fn from(x: ScalarChallenge<Fq>) -> Self {
        CamlTweedleFq(x.0)
    }
}

impl From<CamlTweedleFq> for ScalarChallenge<Fq> {
    fn from(x: CamlTweedleFq) -> Self {
        ScalarChallenge(x.0)
    }
}

impl std::fmt::Display for CamlTweedleFq {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        bigint_256::to_biguint(&self.0.into_repr()).fmt(f)
    }
}

ocaml::custom!(CamlTweedleFq {
    compare: caml_tweedle_fq_compare_raw,
});

unsafe impl ocaml::FromValue for CamlTweedleFq {
    fn from_value(value: ocaml::Value) -> Self {
        CamlTweedleFqPtr::from_value(value).as_ref().clone()
    }
}

#[ocaml::func]
pub fn caml_tweedle_fq_size_in_bits() -> ocaml::Int {
    Fq_params::MODULUS_BITS as isize
}

#[ocaml::func]
pub fn caml_tweedle_fq_size() -> BigInteger256 {
    Fq_params::MODULUS
}

#[ocaml::func]
pub fn caml_tweedle_fq_add(x: CamlTweedleFqPtr, y: CamlTweedleFqPtr) -> CamlTweedleFq {
    CamlTweedleFq(x.as_ref().0 + y.as_ref().0)
}

#[ocaml::func]
pub fn caml_tweedle_fq_sub(x: CamlTweedleFqPtr, y: CamlTweedleFqPtr) -> CamlTweedleFq {
    CamlTweedleFq(x.as_ref().0 - y.as_ref().0)
}

#[ocaml::func]
pub fn caml_tweedle_fq_negate(x: CamlTweedleFqPtr) -> CamlTweedleFq {
    CamlTweedleFq(-x.as_ref().0)
}

#[ocaml::func]
pub fn caml_tweedle_fq_mul(x: CamlTweedleFqPtr, y: CamlTweedleFqPtr) -> CamlTweedleFq {
    CamlTweedleFq(x.as_ref().0 * y.as_ref().0)
}

#[ocaml::func]
pub fn caml_tweedle_fq_div(x: CamlTweedleFqPtr, y: CamlTweedleFqPtr) -> CamlTweedleFq {
    CamlTweedleFq(x.as_ref().0 / y.as_ref().0)
}

#[ocaml::func]
pub fn caml_tweedle_fq_inv(x: CamlTweedleFqPtr) -> Option<CamlTweedleFq> {
    match x.as_ref().0.inverse() {
        Some(x) => Some(CamlTweedleFq(x)),
        None => None,
    }
}

#[ocaml::func]
pub fn caml_tweedle_fq_square(x: CamlTweedleFqPtr) -> CamlTweedleFq {
    CamlTweedleFq(x.as_ref().0.square())
}

#[ocaml::func]
pub fn caml_tweedle_fq_is_square(x: CamlTweedleFqPtr) -> bool {
    let s = x.as_ref().0.pow(Fq_params::MODULUS_MINUS_ONE_DIV_TWO);
    s.is_zero() || s.is_one()
}

#[ocaml::func]
pub fn caml_tweedle_fq_sqrt(x: CamlTweedleFqPtr) -> Option<CamlTweedleFq> {
    match x.as_ref().0.sqrt() {
        Some(x) => Some(CamlTweedleFq(x)),
        None => None,
    }
}

#[ocaml::func]
pub fn caml_tweedle_fq_of_int(i: ocaml::Int) -> CamlTweedleFq {
    CamlTweedleFq(Fq::from(i as u64))
}

#[ocaml::func]
pub fn caml_tweedle_fq_to_string(x: CamlTweedleFqPtr) -> String {
    x.as_ref().to_string()
}

#[ocaml::func]
pub fn caml_tweedle_fq_of_string(s: &[u8]) -> Result<CamlTweedleFq, ocaml::Error> {
    match BigUint::parse_bytes(s, 10) {
        Some(data) => Ok(CamlTweedleFq::from(&(bigint_256::of_biguint(&data)))),
        None => Err(ocaml::Error::invalid_argument("caml_tweedle_fq_of_string")
            .err()
            .unwrap()),
    }
}

#[ocaml::func]
pub fn caml_tweedle_fq_print(x: CamlTweedleFqPtr) {
    println!("{}", x.as_ref());
}

#[ocaml::func]
pub fn caml_tweedle_fq_copy(mut x: CamlTweedleFqPtr, y: CamlTweedleFqPtr) {
    *x.as_mut() = *y.as_ref()
}

#[ocaml::func]
pub fn caml_tweedle_fq_mut_add(mut x: CamlTweedleFqPtr, y: CamlTweedleFqPtr) {
    x.as_mut().0 += y.as_ref().0;
}

#[ocaml::func]
pub fn caml_tweedle_fq_mut_sub(mut x: CamlTweedleFqPtr, y: CamlTweedleFqPtr) {
    x.as_mut().0 -= y.as_ref().0;
}

#[ocaml::func]
pub fn caml_tweedle_fq_mut_mul(mut x: CamlTweedleFqPtr, y: CamlTweedleFqPtr) {
    x.as_mut().0 *= y.as_ref().0;
}

#[ocaml::func]
pub fn caml_tweedle_fq_mut_square(mut x: CamlTweedleFqPtr) {
    x.as_mut().0.square_in_place();
}

#[ocaml::func]
pub fn caml_tweedle_fq_compare(x: CamlTweedleFqPtr, y: CamlTweedleFqPtr) -> ocaml::Int {
    match x.as_ref().0.cmp(&y.as_ref().0) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

#[ocaml::func]
pub fn caml_tweedle_fq_equal(x: CamlTweedleFqPtr, y: CamlTweedleFqPtr) -> bool {
    x.as_ref().0 == y.as_ref().0
}

#[ocaml::func]
pub fn caml_tweedle_fq_random() -> CamlTweedleFq {
    CamlTweedleFq(UniformRand::rand(&mut rand::thread_rng()))
}

#[ocaml::func]
pub fn caml_tweedle_fq_rng(i: ocaml::Int) -> CamlTweedleFq {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    CamlTweedleFq(UniformRand::rand(&mut rng))
}

#[ocaml::func]
pub fn caml_tweedle_fq_to_bigint(x: CamlTweedleFqPtr) -> BigInteger256 {
    x.as_ref().into()
}

#[ocaml::func]
pub fn caml_tweedle_fq_of_bigint(x: ocaml::Pointer<BigInteger256>) -> CamlTweedleFq {
    x.as_ref().into()
}

#[ocaml::func]
pub fn caml_tweedle_fq_two_adic_root_of_unity() -> CamlTweedleFq {
    CamlTweedleFq(FftField::two_adic_root_of_unity())
}

#[ocaml::func]
pub fn caml_tweedle_fq_domain_generator(
    log2_size: ocaml::Int,
) -> Result<CamlTweedleFq, ocaml::Error> {
    match Domain::new(1 << log2_size) {
        Some(x) => Ok(CamlTweedleFq(x.group_gen)),
        None => Err(
            ocaml::Error::invalid_argument("caml_tweedle_fq_domain_generator")
                .err()
                .unwrap(),
        ),
    }
}

#[ocaml::func]
pub fn caml_tweedle_fq_to_bytes(x: CamlTweedleFqPtr) -> ocaml::Value {
    let len = std::mem::size_of::<CamlTweedleFq>();
    let str = unsafe { ocaml::sys::caml_alloc_string(len) };
    unsafe {
        core::ptr::copy_nonoverlapping(x.as_ptr() as *const u8, ocaml::sys::string_val(str), len);
    }
    ocaml::Value(str)
}

#[ocaml::func]
pub fn caml_tweedle_fq_of_bytes(x: &[u8]) -> Result<CamlTweedleFq, ocaml::Error> {
    let len = std::mem::size_of::<CamlTweedleFq>();
    if x.len() != len {
        ocaml::Error::failwith("caml_tweedle_fq_of_bytes")?;
    };
    let x = unsafe { *(x.as_ptr() as *const CamlTweedleFq) };
    Ok(x)
}
