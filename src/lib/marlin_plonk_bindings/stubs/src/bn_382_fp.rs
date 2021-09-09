use crate::bigint_384;
use algebra::biginteger::BigInteger384;
use algebra::{
    bn_382::fp::{Fp, FpParameters as Fp_params},
    fields::{Field, FpParameters, PrimeField, SquareRootField},
    FftField, One, UniformRand, Zero,
};
use ff_fft::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use num_bigint::BigUint;
use rand::rngs::StdRng;
use std::cmp::Ordering::{Equal, Greater, Less};

#[derive(Copy, Clone)]
pub struct CamlBn382Fp(pub Fp);

pub type CamlBn382FpPtr = ocaml::Pointer<CamlBn382Fp>;

extern "C" fn caml_bn_382_fp_compare_raw(x: ocaml::Value, y: ocaml::Value) -> libc::c_int {
    let x: CamlBn382FpPtr = ocaml::FromValue::from_value(x);
    let y: CamlBn382FpPtr = ocaml::FromValue::from_value(y);

    match x.as_ref().0.cmp(&y.as_ref().0) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

impl From<&CamlBn382Fp> for BigInteger384 {
    fn from(x: &CamlBn382Fp) -> BigInteger384 {
        x.0.into_repr()
    }
}

impl From<&BigInteger384> for CamlBn382Fp {
    fn from(x: &BigInteger384) -> CamlBn382Fp {
        CamlBn382Fp(Fp::from_repr(*x))
    }
}

impl std::fmt::Display for CamlBn382Fp {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        bigint_384::to_biguint(&self.0.into_repr()).fmt(f)
    }
}

ocaml::custom!(CamlBn382Fp {
    compare: caml_bn_382_fp_compare_raw,
});

#[ocaml::func]
pub fn caml_bn_382_fp_size_in_bits() -> ocaml::Int {
    Fp_params::MODULUS_BITS as isize
}

#[ocaml::func]
pub fn caml_bn_382_fp_size() -> BigInteger384 {
    Fp_params::MODULUS
}

#[ocaml::func]
pub fn caml_bn_382_fp_add(x: CamlBn382FpPtr, y: CamlBn382FpPtr) -> CamlBn382Fp {
    CamlBn382Fp(x.as_ref().0 + y.as_ref().0)
}

#[ocaml::func]
pub fn caml_bn_382_fp_sub(x: CamlBn382FpPtr, y: CamlBn382FpPtr) -> CamlBn382Fp {
    CamlBn382Fp(x.as_ref().0 - y.as_ref().0)
}

#[ocaml::func]
pub fn caml_bn_382_fp_negate(x: CamlBn382FpPtr) -> CamlBn382Fp {
    CamlBn382Fp(-x.as_ref().0)
}

#[ocaml::func]
pub fn caml_bn_382_fp_mul(x: CamlBn382FpPtr, y: CamlBn382FpPtr) -> CamlBn382Fp {
    CamlBn382Fp(x.as_ref().0 * y.as_ref().0)
}

#[ocaml::func]
pub fn caml_bn_382_fp_div(x: CamlBn382FpPtr, y: CamlBn382FpPtr) -> CamlBn382Fp {
    CamlBn382Fp(x.as_ref().0 / y.as_ref().0)
}

#[ocaml::func]
pub fn caml_bn_382_fp_inv(x: CamlBn382FpPtr) -> Option<CamlBn382Fp> {
    match x.as_ref().0.inverse() {
        Some(x) => Some(CamlBn382Fp(x)),
        None => None,
    }
}

#[ocaml::func]
pub fn caml_bn_382_fp_square(x: CamlBn382FpPtr) -> CamlBn382Fp {
    CamlBn382Fp(x.as_ref().0.square())
}

#[ocaml::func]
pub fn caml_bn_382_fp_is_square(x: CamlBn382FpPtr) -> bool {
    let s = x.as_ref().0.pow(Fp_params::MODULUS_MINUS_ONE_DIV_TWO);
    s.is_zero() || s.is_one()
}

#[ocaml::func]
pub fn caml_bn_382_fp_sqrt(x: CamlBn382FpPtr) -> Option<CamlBn382Fp> {
    match x.as_ref().0.sqrt() {
        Some(x) => Some(CamlBn382Fp(x)),
        None => None,
    }
}

#[ocaml::func]
pub fn caml_bn_382_fp_of_int(i: ocaml::Int) -> CamlBn382Fp {
    CamlBn382Fp(Fp::from(i as u64))
}

#[ocaml::func]
pub fn caml_bn_382_fp_to_string(x: CamlBn382FpPtr) -> String {
    x.as_ref().to_string()
}

#[ocaml::func]
pub fn caml_bn_382_fp_of_string(s: &[u8]) -> Result<CamlBn382Fp, ocaml::Error> {
    match BigUint::parse_bytes(s, 10) {
        Some(data) => Ok(CamlBn382Fp::from(&(bigint_384::of_biguint(&data)))),
        None => Err(ocaml::Error::invalid_argument("caml_bn_382_fp_of_string")
            .err()
            .unwrap()),
    }
}

#[ocaml::func]
pub fn caml_bn_382_fp_print(x: CamlBn382FpPtr) {
    println!("{}", x.as_ref());
}

#[ocaml::func]
pub fn caml_bn_382_fp_copy(mut x: CamlBn382FpPtr, y: CamlBn382FpPtr) {
    *x.as_mut() = *y.as_ref();
}

#[ocaml::func]
pub fn caml_bn_382_fp_mut_add(mut x: CamlBn382FpPtr, y: CamlBn382FpPtr) {
    x.as_mut().0 += y.as_ref().0;
}

#[ocaml::func]
pub fn caml_bn_382_fp_mut_sub(mut x: CamlBn382FpPtr, y: CamlBn382FpPtr) {
    x.as_mut().0 -= y.as_ref().0;
}

#[ocaml::func]
pub fn caml_bn_382_fp_mut_mul(mut x: CamlBn382FpPtr, y: CamlBn382FpPtr) {
    x.as_mut().0 *= y.as_ref().0;
}

#[ocaml::func]
pub fn caml_bn_382_fp_mut_square(mut x: CamlBn382FpPtr) {
    x.as_mut().0.square_in_place();
}

#[ocaml::func]
pub fn caml_bn_382_fp_compare(x: CamlBn382FpPtr, y: CamlBn382FpPtr) -> ocaml::Int {
    match x.as_ref().0.cmp(&y.as_ref().0) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

#[ocaml::func]
pub fn caml_bn_382_fp_equal(x: CamlBn382FpPtr, y: CamlBn382FpPtr) -> bool {
    x.as_ref().0 == y.as_ref().0
}

#[ocaml::func]
pub fn caml_bn_382_fp_random() -> CamlBn382Fp {
    CamlBn382Fp(UniformRand::rand(&mut rand::thread_rng()))
}

#[ocaml::func]
pub fn caml_bn_382_fp_rng(i: ocaml::Int) -> CamlBn382Fp {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    CamlBn382Fp(UniformRand::rand(&mut rng))
}

#[ocaml::func]
pub fn caml_bn_382_fp_to_bigint(x: CamlBn382FpPtr) -> BigInteger384 {
    x.as_ref().into()
}

#[ocaml::func]
pub fn caml_bn_382_fp_of_bigint(x: ocaml::Pointer<BigInteger384>) -> CamlBn382Fp {
    x.as_ref().into()
}

#[ocaml::func]
pub fn caml_bn_382_fp_two_adic_root_of_unity() -> CamlBn382Fp {
    CamlBn382Fp(FftField::two_adic_root_of_unity())
}

#[ocaml::func]
pub fn caml_bn_382_fp_domain_generator(log2_size: ocaml::Int) -> Result<CamlBn382Fp, ocaml::Error> {
    match Domain::new(1 << log2_size) {
        Some(x) => Ok(CamlBn382Fp(x.group_gen)),
        None => Err(
            ocaml::Error::invalid_argument("caml_bn_382_fp_domain_generator")
                .err()
                .unwrap(),
        ),
    }
}

#[ocaml::func]
pub fn caml_bn_382_fp_to_bytes(x: CamlBn382FpPtr) -> ocaml::Value {
    let len = std::mem::size_of::<CamlBn382Fp>();
    let str = unsafe { ocaml::sys::caml_alloc_string(len) };
    unsafe {
        core::ptr::copy_nonoverlapping(x.as_ptr() as *const u8, ocaml::sys::string_val(str), len);
    }
    ocaml::Value(str)
}

#[ocaml::func]
pub fn caml_bn_382_fp_of_bytes(x: &[u8]) -> Result<CamlBn382Fp, ocaml::Error> {
    let len = std::mem::size_of::<CamlBn382Fp>();
    if x.len() != len {
        ocaml::Error::failwith("caml_bn_382_fp_of_bytes")?;
    };
    let x = unsafe { *(x.as_ptr() as *const CamlBn382Fp) };
    Ok(x)
}
