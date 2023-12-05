use crate::arkworks::CamlBigInteger256;
use crate::caml::caml_bytes_string::CamlBytesString;
use ark_ff::{
    FftField, Field, FpParameters, One, PrimeField, SquareRootField, ToBytes, UniformRand, Zero,
};
use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use mina_curves::bn254::fields::FqParameters as Fq_params;
use mina_curves::bn254::Fq;
use num_bigint::BigUint;
use rand::rngs::StdRng;
use std::{
    cmp::Ordering::{Equal, Greater, Less},
    convert::{TryFrom, TryInto},
    ops::Deref,
};

#[derive(Clone, Copy, Debug, ocaml_gen::CustomType)]
pub struct CamlBn254Fq(pub Fq);

unsafe impl<'a> ocaml::FromValue<'a> for CamlBn254Fq {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        *x.as_ref()
    }
}

impl CamlBn254Fq {
    unsafe extern "C" fn caml_pointer_finalize(v: ocaml::Raw) {
        let ptr = v.as_pointer::<Self>();
        ptr.drop_in_place()
    }

    unsafe extern "C" fn ocaml_compare(x: ocaml::Raw, y: ocaml::Raw) -> i32 {
        let x = x.as_pointer::<Self>();
        let y = y.as_pointer::<Self>();
        match x.as_ref().0.cmp(&y.as_ref().0) {
            core::cmp::Ordering::Less => -1,
            core::cmp::Ordering::Equal => 0,
            core::cmp::Ordering::Greater => 1,
        }
    }
}

ocaml::custom!(CamlBn254Fq {
    finalize: CamlBn254Fq::caml_pointer_finalize,
    compare: CamlBn254Fq::ocaml_compare,
});

impl Deref for CamlBn254Fq {
    type Target = Fq;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

//
// Handy implementations
//

impl From<Fq> for CamlBn254Fq {
    fn from(fq: Fq) -> Self {
        CamlBn254Fq(fq)
    }
}

impl From<&Fq> for CamlBn254Fq {
    fn from(fq: &Fq) -> Self {
        CamlBn254Fq(*fq)
    }
}

impl From<CamlBn254Fq> for Fq {
    fn from(camlfq: CamlBn254Fq) -> Fq {
        camlfq.0
    }
}

impl From<&CamlBn254Fq> for Fq {
    fn from(camlfq: &CamlBn254Fq) -> Fq {
        camlfq.0
    }
}

impl TryFrom<CamlBigInteger256> for CamlBn254Fq {
    type Error = ocaml::Error;
    fn try_from(x: CamlBigInteger256) -> Result<Self, Self::Error> {
        Fq::from_repr(x.0)
            .map(Into::into)
            .ok_or(ocaml::Error::Message(
                "TryFrom<CamlBigInteger256>: integer is larger than order",
            ))
    }
}

//
// Helpers
//

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_size_in_bits() -> ocaml::Int {
    Fq_params::MODULUS_BITS as isize
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_size() -> CamlBigInteger256 {
    Fq_params::MODULUS.into()
}

//
// Arithmetic methods
//

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_add(
    x: ocaml::Pointer<CamlBn254Fq>,
    y: ocaml::Pointer<CamlBn254Fq>,
) -> CamlBn254Fq {
    CamlBn254Fq(x.as_ref().0 + y.as_ref().0)
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_sub(
    x: ocaml::Pointer<CamlBn254Fq>,
    y: ocaml::Pointer<CamlBn254Fq>,
) -> CamlBn254Fq {
    CamlBn254Fq(x.as_ref().0 - y.as_ref().0)
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_negate(x: ocaml::Pointer<CamlBn254Fq>) -> CamlBn254Fq {
    CamlBn254Fq(-x.as_ref().0)
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_mul(
    x: ocaml::Pointer<CamlBn254Fq>,
    y: ocaml::Pointer<CamlBn254Fq>,
) -> CamlBn254Fq {
    CamlBn254Fq(x.as_ref().0 * y.as_ref().0)
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_div(
    x: ocaml::Pointer<CamlBn254Fq>,
    y: ocaml::Pointer<CamlBn254Fq>,
) -> CamlBn254Fq {
    CamlBn254Fq(x.as_ref().0 / y.as_ref().0)
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_inv(x: ocaml::Pointer<CamlBn254Fq>) -> Option<CamlBn254Fq> {
    x.as_ref().0.inverse().map(CamlBn254Fq)
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_square(x: ocaml::Pointer<CamlBn254Fq>) -> CamlBn254Fq {
    CamlBn254Fq(x.as_ref().0.square())
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_is_square(x: ocaml::Pointer<CamlBn254Fq>) -> bool {
    let s = x.as_ref().0.pow(Fq_params::MODULUS_MINUS_ONE_DIV_TWO);
    s.is_zero() || s.is_one()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_sqrt(x: ocaml::Pointer<CamlBn254Fq>) -> Option<CamlBn254Fq> {
    x.as_ref().0.sqrt().map(CamlBn254Fq)
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_of_int(i: ocaml::Int) -> CamlBn254Fq {
    CamlBn254Fq(Fq::from(i as u64))
}

//
// Conversion methods
//

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_to_string(x: ocaml::Pointer<CamlBn254Fq>) -> String {
    CamlBigInteger256(x.as_ref().into_repr()).to_string()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_of_string(s: CamlBytesString) -> Result<CamlBn254Fq, ocaml::Error> {
    let biguint = BigUint::parse_bytes(s.0, 10).ok_or(ocaml::Error::Message(
        "caml_bn254_fq_of_string: couldn't parse input",
    ))?;
    let camlbigint: CamlBigInteger256 = biguint
        .try_into()
        .map_err(|_| ocaml::Error::Message("caml_bn254_fq_of_string: Biguint is too large"))?;
    CamlBn254Fq::try_from(camlbigint).map_err(|_| ocaml::Error::Message("caml_bn254_fq_of_string"))
}

//
// Data methods
//

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_print(x: ocaml::Pointer<CamlBn254Fq>) {
    println!(
        "{}",
        CamlBigInteger256(x.as_ref().0.into_repr()).to_string()
    );
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_print_rust(x: ocaml::Pointer<CamlBn254Fq>) {
    println!("{}", x.as_ref().0);
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_copy(mut x: ocaml::Pointer<CamlBn254Fq>, y: ocaml::Pointer<CamlBn254Fq>) {
    *x.as_mut() = *y.as_ref()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_mut_add(mut x: ocaml::Pointer<CamlBn254Fq>, y: ocaml::Pointer<CamlBn254Fq>) {
    x.as_mut().0 += y.as_ref().0;
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_mut_sub(mut x: ocaml::Pointer<CamlBn254Fq>, y: ocaml::Pointer<CamlBn254Fq>) {
    x.as_mut().0 -= y.as_ref().0;
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_mut_mul(mut x: ocaml::Pointer<CamlBn254Fq>, y: ocaml::Pointer<CamlBn254Fq>) {
    x.as_mut().0 *= y.as_ref().0;
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_mut_square(mut x: ocaml::Pointer<CamlBn254Fq>) {
    x.as_mut().0.square_in_place();
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_compare(
    x: ocaml::Pointer<CamlBn254Fq>,
    y: ocaml::Pointer<CamlBn254Fq>,
) -> ocaml::Int {
    match x.as_ref().0.cmp(&y.as_ref().0) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_equal(x: ocaml::Pointer<CamlBn254Fq>, y: ocaml::Pointer<CamlBn254Fq>) -> bool {
    x.as_ref().0 == y.as_ref().0
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_random() -> CamlBn254Fq {
    let fq: Fq = UniformRand::rand(&mut rand::thread_rng());
    CamlBn254Fq(fq)
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_rng(i: ocaml::Int) -> CamlBn254Fq {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    let fq: Fq = UniformRand::rand(&mut rng);
    CamlBn254Fq(fq)
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_to_bigint(x: ocaml::Pointer<CamlBn254Fq>) -> CamlBigInteger256 {
    CamlBigInteger256(x.as_ref().0.into_repr())
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_of_bigint(x: CamlBigInteger256) -> Result<CamlBn254Fq, ocaml::Error> {
    Fq::from_repr(x.0).map(CamlBn254Fq).ok_or_else(|| {
        let err = format!(
            "caml_bn254_fq_of_bigint was given an invalid CamlBigInteger256: {}",
            x.0
        );
        ocaml::Error::Error(err.into())
    })
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_two_adic_root_of_unity() -> CamlBn254Fq {
    let res: Fq = FftField::two_adic_root_of_unity();
    CamlBn254Fq(res)
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_domain_generator(log2_size: ocaml::Int) -> Result<CamlBn254Fq, ocaml::Error> {
    Domain::new(1 << log2_size)
        .map(|x| CamlBn254Fq(x.group_gen))
        .ok_or(ocaml::Error::Message("caml_bn254_fq_domain_generator"))
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_to_bytes(x: ocaml::Pointer<CamlBn254Fq>) -> [u8; std::mem::size_of::<Fq>()] {
    let mut res = [0u8; std::mem::size_of::<Fq>()];
    x.as_ref().0.write(&mut res[..]).unwrap();
    res
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_of_bytes(x: &[u8]) -> Result<CamlBn254Fq, ocaml::Error> {
    let len = std::mem::size_of::<CamlBn254Fq>();
    if x.len() != len {
        ocaml::Error::failwith("caml_bn254_fq_of_bytes")?;
    };
    let x = unsafe { *(x.as_ptr() as *const CamlBn254Fq) };
    Ok(x)
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fq_deep_copy(x: CamlBn254Fq) -> CamlBn254Fq {
    x
}
