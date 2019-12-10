extern crate libc;
use algebra::{
  fields::{FpParameters}
};

#[no_mangle]
pub extern fn camlsnark_bn382_fp_size_in_bits() -> u32 {
    return algebra::fields::bn_382::fp::FpParameters::MODULUS_BITS;
}
