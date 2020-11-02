use crate::bigint_256::{CamlBigint256, CamlBigint256Ptr};
use algebra::{
    fields::{Field, FpParameters, PrimeField, SquareRootField},
    tweedle::fp::{Fp, FpParameters as Fp_params},
    FftField, One, UniformRand, Zero,
};
use ff_fft::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use num_bigint::BigUint;
use rand::rngs::StdRng;
use std::cmp::Ordering::{Equal, Greater, Less};

#[derive(Copy, Clone)]
pub struct CamlTweedleFp(pub Fp);

pub type CamlTweedleFpPtr = ocaml::Pointer<CamlTweedleFp>;

extern "C" fn caml_tweedle_fp_compare_raw(x: ocaml::Value, y: ocaml::Value) -> libc::c_int {
    let x: CamlTweedleFpPtr = ocaml::FromValue::from_value(x);
    let y: CamlTweedleFpPtr = ocaml::FromValue::from_value(y);

    match x.as_ref().0.cmp(&y.as_ref().0) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

impl From<&CamlTweedleFp> for CamlBigint256 {
    fn from(x: &CamlTweedleFp) -> CamlBigint256 {
        CamlBigint256(x.0.into_repr())
    }
}

impl From<&CamlBigint256> for CamlTweedleFp {
    fn from(x: &CamlBigint256) -> CamlTweedleFp {
        CamlTweedleFp(Fp::from_repr(x.0))
    }
}

impl From<Fp> for CamlTweedleFp {
    fn from(x: Fp) -> Self {
        CamlTweedleFp(x)
    }
}

impl From<CamlTweedleFp> for Fp {
    fn from(x: CamlTweedleFp) -> Self {
        x.0
    }
}

impl std::fmt::Display for CamlTweedleFp {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        CamlBigint256::from(self).fmt(f)
    }
}

ocaml::custom!(CamlTweedleFp {
    compare: caml_tweedle_fp_compare_raw,
});

unsafe impl ocaml::FromValue for CamlTweedleFp {
    fn from_value(value: ocaml::Value) -> Self {
        CamlTweedleFpPtr::from_value(value).as_ref().clone()
    }
}

#[ocaml::func]
pub fn caml_tweedle_fp_size_in_bits() -> ocaml::Int {
    Fp_params::MODULUS_BITS as isize
}

#[ocaml::func]
pub fn caml_tweedle_fp_size() -> CamlBigint256 {
    CamlBigint256(Fp_params::MODULUS)
}

#[ocaml::func]
pub fn caml_tweedle_fp_add(x: CamlTweedleFpPtr, y: CamlTweedleFpPtr) -> CamlTweedleFp {
    CamlTweedleFp(x.as_ref().0 + y.as_ref().0)
}

#[ocaml::func]
pub fn caml_tweedle_fp_sub(x: CamlTweedleFpPtr, y: CamlTweedleFpPtr) -> CamlTweedleFp {
    CamlTweedleFp(x.as_ref().0 - y.as_ref().0)
}

#[ocaml::func]
pub fn caml_tweedle_fp_negate(x: CamlTweedleFpPtr) -> CamlTweedleFp {
    CamlTweedleFp(-x.as_ref().0)
}

#[ocaml::func]
pub fn caml_tweedle_fp_mul(x: CamlTweedleFpPtr, y: CamlTweedleFpPtr) -> CamlTweedleFp {
    CamlTweedleFp(x.as_ref().0 * y.as_ref().0)
}

#[ocaml::func]
pub fn caml_tweedle_fp_div(x: CamlTweedleFpPtr, y: CamlTweedleFpPtr) -> CamlTweedleFp {
    CamlTweedleFp(x.as_ref().0 / y.as_ref().0)
}

#[ocaml::func]
pub fn caml_tweedle_fp_inv(x: CamlTweedleFpPtr) -> Option<CamlTweedleFp> {
    match x.as_ref().0.inverse() {
        Some(x) => Some(CamlTweedleFp(x)),
        None => None,
    }
}

#[ocaml::func]
pub fn caml_tweedle_fp_square(x: CamlTweedleFpPtr) -> CamlTweedleFp {
    CamlTweedleFp(x.as_ref().0.square())
}

#[ocaml::func]
pub fn caml_tweedle_fp_is_square(x: CamlTweedleFpPtr) -> bool {
    let s = x.as_ref().0.pow(Fp_params::MODULUS_MINUS_ONE_DIV_TWO);
    s.is_zero() || s.is_one()
}

#[ocaml::func]
pub fn caml_tweedle_fp_sqrt(x: CamlTweedleFpPtr) -> Option<CamlTweedleFp> {
    match x.as_ref().0.sqrt() {
        Some(x) => Some(CamlTweedleFp(x)),
        None => None,
    }
}

#[ocaml::func]
pub fn caml_tweedle_fp_of_int(i: ocaml::Int) -> CamlTweedleFp {
    CamlTweedleFp(Fp::from(i as u64))
}

#[ocaml::func]
pub fn caml_tweedle_fp_to_string(x: CamlTweedleFpPtr) -> String {
    x.as_ref().to_string()
}

#[ocaml::func]
pub fn caml_tweedle_fp_of_string(s: &[u8]) -> Result<CamlTweedleFp, ocaml::Error> {
    match BigUint::parse_bytes(s, 10) {
        Some(data) => Ok(CamlTweedleFp::from(&(CamlBigint256::from(&data)))),
        None => Err(ocaml::Error::invalid_argument("caml_tweedle_fp_of_string")
            .err()
            .unwrap()),
    }
}

#[ocaml::func]
pub fn caml_tweedle_fp_print(x: CamlTweedleFpPtr) {
    println!("{}", x.as_ref());
}

#[ocaml::func]
pub fn caml_tweedle_fp_copy(x: CamlTweedleFpPtr) -> CamlTweedleFp {
    *x.as_ref()
}

#[ocaml::func]
pub fn caml_tweedle_fp_mut_add(mut x: CamlTweedleFpPtr, y: CamlTweedleFpPtr) {
    x.as_mut().0 += y.as_ref().0;
}

#[ocaml::func]
pub fn caml_tweedle_fp_mut_sub(mut x: CamlTweedleFpPtr, y: CamlTweedleFpPtr) {
    x.as_mut().0 -= y.as_ref().0;
}

#[ocaml::func]
pub fn caml_tweedle_fp_mut_mul(mut x: CamlTweedleFpPtr, y: CamlTweedleFpPtr) {
    x.as_mut().0 *= y.as_ref().0;
}

#[ocaml::func]
pub fn caml_tweedle_fp_mut_square(mut x: CamlTweedleFpPtr) {
    x.as_mut().0.square_in_place();
}

#[ocaml::func]
pub fn caml_tweedle_fp_compare(x: CamlTweedleFpPtr, y: CamlTweedleFpPtr) -> ocaml::Int {
    match x.as_ref().0.cmp(&y.as_ref().0) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

#[ocaml::func]
pub fn caml_tweedle_fp_equal(x: CamlTweedleFpPtr, y: CamlTweedleFpPtr) -> bool {
    x.as_ref().0 == y.as_ref().0
}

#[ocaml::func]
pub fn caml_tweedle_fp_random() -> CamlTweedleFp {
    CamlTweedleFp(UniformRand::rand(&mut rand::thread_rng()))
}

#[ocaml::func]
pub fn caml_tweedle_fp_rng(i: ocaml::Int) -> CamlTweedleFp {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    CamlTweedleFp(UniformRand::rand(&mut rng))
}

#[ocaml::func]
pub fn caml_tweedle_fp_to_bigint(x: CamlTweedleFpPtr) -> CamlBigint256 {
    x.as_ref().into()
}

#[ocaml::func]
pub fn caml_tweedle_fp_of_bigint(x: CamlBigint256Ptr) -> CamlTweedleFp {
    x.as_ref().into()
}

#[ocaml::func]
pub fn caml_tweedle_fp_two_adic_root_of_unity() -> CamlTweedleFp {
    CamlTweedleFp(FftField::two_adic_root_of_unity())
}

#[ocaml::func]
pub fn caml_tweedle_fp_domain_generator(
    log2_size: ocaml::Int,
) -> Result<CamlTweedleFp, ocaml::Error> {
    match Domain::new(1 << log2_size) {
        Some(x) => Ok(CamlTweedleFp(x.group_gen)),
        None => Err(
            ocaml::Error::invalid_argument("caml_tweedle_fp_domain_generator")
                .err()
                .unwrap(),
        ),
    }
}

#[ocaml::func]
pub fn caml_tweedle_fp_to_bytes(x: CamlTweedleFpPtr) -> ocaml::Value {
    let len = std::mem::size_of::<CamlTweedleFp>();
    let str = unsafe { ocaml::sys::caml_alloc_string(len) };
    unsafe {
        core::ptr::copy_nonoverlapping(x.as_ptr() as *const u8, ocaml::sys::string_val(str), len);
    }
    ocaml::Value(str)
}
