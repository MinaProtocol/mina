use crate::types::CamlBigInteger256;
use ark_ff::{FftField, Field, FpParameters, One, PrimeField, SquareRootField, UniformRand, Zero};
use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use mina_curves::pasta::fq::{Fq, FqParameters as Fq_params};
use num_bigint::BigUint;
use rand::rngs::StdRng;
use std::cmp::Ordering::{Equal, Greater, Less};

//
// Wrapper struct to implement OCaml bindings
//

#[derive(Clone, Copy)]
pub struct CamlFq(pub Fq);

unsafe impl ocaml::FromValue for CamlFq {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        x.as_ref().clone()
    }
}

impl CamlFq {
    extern "C" fn caml_pointer_finalize(v: ocaml::Value) {
        let v: ocaml::Pointer<Self> = ocaml::FromValue::from_value(v);
        unsafe {
            v.drop_in_place();
        }
    }

    extern "C" fn ocaml_compare(x: ocaml::Value, y: ocaml::Value) -> i32 {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(x);
        let y: ocaml::Pointer<Self> = ocaml::FromValue::from_value(y);
        match x.as_ref().0.cmp(&y.as_ref().0) {
            core::cmp::Ordering::Less => -1,
            core::cmp::Ordering::Equal => 0,
            core::cmp::Ordering::Greater => 1,
        }
    }
}

ocaml::custom!(CamlFq {
    finalize: CamlFq::caml_pointer_finalize,
    compare: CamlFq::ocaml_compare,
});

//
// Helpers
//

#[ocaml::func]
pub fn caml_pasta_fq_size_in_bits() -> ocaml::Int {
    Fq_params::MODULUS_BITS as isize
}

#[ocaml::func]
pub fn caml_pasta_fq_size() -> CamlBigInteger256 {
    Fq_params::MODULUS.into()
}

#[ocaml::func]
pub fn caml_pasta_fq_add(x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) -> CamlFq {
    CamlFq(x.as_ref().0 + y.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_fq_sub(x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) -> CamlFq {
    CamlFq(x.as_ref().0 - y.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_fq_negate(x: ocaml::Pointer<CamlFq>) -> CamlFq {
    CamlFq(-x.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_fq_mul(x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) -> CamlFq {
    CamlFq(x.as_ref().0 * y.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_fq_div(x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) -> CamlFq {
    CamlFq(x.as_ref().0 / y.as_ref().0)
}

#[ocaml::func]
pub fn caml_pasta_fq_inv(x: ocaml::Pointer<CamlFq>) -> Option<CamlFq> {
    x.as_ref().0.inverse().map(CamlFq)
}

#[ocaml::func]
pub fn caml_pasta_fq_square(x: ocaml::Pointer<CamlFq>) -> CamlFq {
    CamlFq(x.as_ref().0.square())
}

#[ocaml::func]
pub fn caml_pasta_fq_is_square(x: ocaml::Pointer<CamlFq>) -> bool {
    let s = x.as_ref().0.pow(Fq_params::MODULUS_MINUS_ONE_DIV_TWO);
    s.is_zero() || s.is_one()
}

#[ocaml::func]
pub fn caml_pasta_fq_sqrt(x: ocaml::Pointer<CamlFq>) -> Option<CamlFq> {
    x.as_ref().0.sqrt().map(CamlFq)
}

#[ocaml::func]
pub fn caml_pasta_fq_of_int(i: ocaml::Int) -> CamlFq {
    CamlFq(Fq::from(i as u64))
}

//
// Conversion methods
//

#[ocaml::func]
pub fn caml_pasta_fq_to_string(x: ocaml::Pointer<CamlFq>) -> String {
    CamlBigInteger256(x.as_ref().0.into_repr())
        .to_biguint()
        .to_string()
}

#[ocaml::func]
pub fn caml_pasta_fq_of_string(s: &[u8]) -> Result<CamlFq, ocaml::Error> {
    BigUint::parse_bytes(s, 10)
        // TODO: implement from_repr on CamlFq
        .map(|data| CamlBigInteger256::of_biguint(&data).0)
        .map(Fq::from_repr)
        .flatten()
        .map(CamlFq)
        .ok_or(ocaml::Error::Message("caml_pasta_fp_of_string"))
}

//
// Data methods
//

#[ocaml::func]
pub fn caml_pasta_fq_print(x: ocaml::Pointer<CamlFq>) {
    println!(
        "{}",
        CamlBigInteger256(x.as_ref().0.into_repr()).to_biguint()
    );
}

#[ocaml::func]
pub fn caml_pasta_fq_copy(mut x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) {
    *x.as_mut() = y.as_ref().clone()
}

#[ocaml::func]
pub fn caml_pasta_fq_mut_add(mut x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) {
    x.as_mut().0 += y.as_ref().0;
}

#[ocaml::func]
pub fn caml_pasta_fq_mut_sub(mut x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) {
    x.as_mut().0 -= y.as_ref().0;
}

#[ocaml::func]
pub fn caml_pasta_fq_mut_mul(mut x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) {
    x.as_mut().0 *= y.as_ref().0;
}

#[ocaml::func]
pub fn caml_pasta_fq_mut_square(mut x: ocaml::Pointer<CamlFq>) {
    x.as_mut().0.square_in_place();
}

#[ocaml::func]
pub fn caml_pasta_fq_compare(x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) -> ocaml::Int {
    match x.as_ref().0.cmp(&y.as_ref().0) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

#[ocaml::func]
pub fn caml_pasta_fq_equal(x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) -> bool {
    x.as_ref().0 == y.as_ref().0
}

#[ocaml::func]
pub fn caml_pasta_fq_random() -> CamlFq {
    let fq: Fq = UniformRand::rand(&mut rand::thread_rng());
    CamlFq(fq)
}

#[ocaml::func]
pub fn caml_pasta_fq_rng(i: ocaml::Int) -> CamlFq {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    let fq: Fq = UniformRand::rand(&mut rng);
    CamlFq(fq)
}

#[ocaml::func]
pub fn caml_pasta_fq_to_bigint(x: ocaml::Pointer<CamlFq>) -> CamlBigInteger256 {
    CamlBigInteger256(x.as_ref().0.into_repr())
}

#[ocaml::func]
pub fn caml_pasta_fq_of_bigint(x: CamlBigInteger256) -> Result<CamlFq, ocaml::Error> {
    Fq::from_repr(x.0).map(CamlFq).ok_or(ocaml::Error::Message(
        "caml_pasta_fq_of_bigint was given an invalid CamlBigInteger256",
    ))
}

#[ocaml::func]
pub fn caml_pasta_fq_two_adic_root_of_unity() -> CamlFq {
    let res: Fq = FftField::two_adic_root_of_unity();
    CamlFq(res)
}

#[ocaml::func]
pub fn caml_pasta_fq_domain_generator(log2_size: ocaml::Int) -> Result<CamlFq, ocaml::Error> {
    Domain::new(1 << log2_size)
        .map(|x| CamlFq(x.group_gen))
        .ok_or(ocaml::Error::Message("caml_pasta_fq_domain_generator"))
}

#[ocaml::func]
pub fn caml_pasta_fq_to_bytes(x: ocaml::Pointer<CamlFq>) -> ocaml::Value {
    let len = std::mem::size_of::<CamlFq>();
    let str = unsafe { ocaml::sys::caml_alloc_string(len) };
    unsafe {
        core::ptr::copy_nonoverlapping(x.as_ptr() as *const u8, ocaml::sys::string_val(str), len);
    }
    ocaml::Value(str)
}

#[ocaml::func]
pub fn caml_pasta_fq_of_bytes(x: &[u8]) -> Result<CamlFq, ocaml::Error> {
    let len = std::mem::size_of::<CamlFq>();
    if x.len() != len {
        ocaml::Error::failwith("caml_pasta_fq_of_bytes")?;
    };
    let x = unsafe { *(x.as_ptr() as *const CamlFq) };
    Ok(x)
}

#[ocaml::func]
pub fn caml_pasta_fq_deep_copy(x: CamlFq) -> CamlFq {
    x
}
