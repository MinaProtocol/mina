use crate::arkworks::{BigInteger256, Fp256};
use crate::caml::caml_bytes_string::CamlBytesString;
use ark_ff::ToBytes;
use ark_ff::{FftField, Field, FpParameters, One, PrimeField, SquareRootField, UniformRand, Zero};
use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use mina_curves::pasta::fq::{Fq, FqParameters as Fq_params};
use num_bigint::BigUint;
use rand::rngs::StdRng;
use std::ops::Neg;
use std::{
    cmp::Ordering::{Equal, Greater, Less},
    convert::{TryFrom, TryInto},
};

/// Our wrapper around Fq
pub type CamlFq = Fp256<Fq_params>;

//
// Helpers
//

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_size_in_bits() -> ocaml::Int {
    Fq_params::MODULUS_BITS as isize
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_size() -> BigInteger256 {
    Fq_params::MODULUS.into()
}

//
// Arithmetic methods
//

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_add(x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) -> CamlFq {
    *x.as_ref() + *y.as_ref()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_sub(x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) -> CamlFq {
    *x.as_ref() - *y.as_ref()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_negate(x: ocaml::Pointer<CamlFq>) -> CamlFq {
    x.as_ref().neg()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_mul(x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) -> CamlFq {
    *x.as_ref() * *y.as_ref()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_div(x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) -> CamlFq {
    *x.as_ref() / *y.as_ref()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_inv(x: ocaml::Pointer<CamlFq>) -> Option<CamlFq> {
    x.as_ref().inverse().map(Into::into)
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_square(x: ocaml::Pointer<CamlFq>) -> CamlFq {
    x.as_ref().square()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_is_square(x: ocaml::Pointer<CamlFq>) -> bool {
    let s = x.as_ref().pow(Fq_params::MODULUS_MINUS_ONE_DIV_TWO);
    s.is_zero() || s.is_one()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_sqrt(x: ocaml::Pointer<CamlFq>) -> Option<CamlFq> {
    x.as_ref().sqrt().map(Into::into)
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_of_int(i: ocaml::Int) -> CamlFq {
    CamlFq::from(i as u64)
}

//
// Conversion methods
//

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_to_string(x: ocaml::Pointer<CamlFq>) -> String {
    x.as_ref().into_repr().to_string()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_of_string(s: CamlBytesString) -> Result<CamlFq, ocaml::Error> {
    let biguint = BigUint::parse_bytes(s.0, 10).ok_or(ocaml::Error::Message(
        "caml_pasta_fq_of_string: couldn't parse input",
    ))?;
    let camlbigint: ark_ff::BigInteger256 = biguint
        .try_into()
        .map_err(|_| ocaml::Error::Message("caml_pasta_fq_of_string: Biguint is too large"))?;
    CamlFq::try_from(camlbigint).map_err(|_| ocaml::Error::Message("caml_pasta_fq_of_string"))
}

//
// Data methods
//

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_print(x: ocaml::Pointer<CamlFq>) {
    println!("{}", x.as_ref().into_repr().to_string());
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_copy(mut x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) {
    *x.as_mut() = *y.as_ref()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_mut_add(mut x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) {
    *x.as_mut() += y.as_ref();
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_mut_sub(mut x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) {
    *x.as_mut() -= y.as_ref();
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_mut_mul(mut x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) {
    *x.as_mut() *= y.as_ref();
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_mut_square(mut x: ocaml::Pointer<CamlFq>) {
    x.as_mut().square_in_place();
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_compare(x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) -> ocaml::Int {
    match x.as_ref().cmp(&y.as_ref()) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_equal(x: ocaml::Pointer<CamlFq>, y: ocaml::Pointer<CamlFq>) -> bool {
    x.as_ref() == y.as_ref()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_random() -> CamlFq {
    let fq: Fq = UniformRand::rand(&mut rand::thread_rng());
    fq.into()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_rng(i: ocaml::Int) -> CamlFq {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    let fq: Fq = UniformRand::rand(&mut rng);
    fq.into()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_to_bigint(x: ocaml::Pointer<CamlFq>) -> BigInteger256 {
    x.as_ref().into_repr().into()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_of_bigint(x: BigInteger256) -> Result<CamlFq, ocaml::Error> {
    Fq::from_repr(x.0).map(CamlFq::from).ok_or_else(|| {
        let err = format!(
            "caml_pasta_fq_of_bigint was given an invalid CamlBigInteger256: {}",
            x
        );
        ocaml::Error::Error(err.into())
    })
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_two_adic_root_of_unity() -> CamlFq {
    let res: Fq = FftField::two_adic_root_of_unity();
    res.into()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_domain_generator(log2_size: ocaml::Int) -> Result<CamlFq, ocaml::Error> {
    Domain::new(1 << log2_size)
        .map(|x| x.group_gen)
        .ok_or(ocaml::Error::Message("caml_pasta_fq_domain_generator"))
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_to_bytes(x: ocaml::Pointer<CamlFq>) -> [u8; std::mem::size_of::<Fq>()] {
    let mut res = [0u8; std::mem::size_of::<Fq>()];
    x.as_ref().write(&mut res[..]).unwrap();
    res
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_of_bytes(x: &[u8]) -> Result<CamlFq, ocaml::Error> {
    let len = std::mem::size_of::<CamlFq>();
    if x.len() != len {
        ocaml::Error::failwith("caml_pasta_fq_of_bytes")?;
    };
    let x = unsafe { *(x.as_ptr() as *const CamlFq) };
    Ok(x)
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_deep_copy(x: CamlFq) -> CamlFq {
    x
}
