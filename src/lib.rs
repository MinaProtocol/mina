extern crate libc;
use algebra::{
  biginteger::BigInteger384 as BigInteger,
  fields::{
    FpParameters,
    bn_382::fp::FpParameters as Fp_params,
    bn_382::fp::Fp as Fp,
    bn_382::fq::FqParameters as Fq_params,
    bn_382::fq::Fq as Fq,
    Field,
    SquareRootField,
  },
  UniformRand,
};
use rand::rngs::StdRng as StdRng;

/* NOTE: We always 'box' these values as pointers, since the FFI doesn't know
 * the size of the target type, and annotating them with (void *) on the other
 * side of the FFI would cause only the first 64 bits to be copied. */

/* Fp stubs */

#[no_mangle]
pub extern fn camlsnark_bn382_fp_size_in_bits() -> i32 {
    return Fp_params::MODULUS_BITS as i32;
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_size() -> *mut BigInteger {
    let ret = Fp_params::MODULUS;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_is_square(x : *const Fp) -> bool {
    let x_ = unsafe { &(*x) };
    let ret =
      match x_.sqrt() {
        | Some(_) => true,
        | None => false,
      };
    return ret;
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_sqrt(x : *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let ret =
      match x_.sqrt() {
        | Some(x) => x,
        | None => Fp::zero(),
      };
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_random() -> *mut Fp {
    let ret : Fp = UniformRand::rand(&mut rand::thread_rng());
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_of_int(i: u64) -> *mut Fp {
    let ret = Fp::from(i);
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_inv(x : *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let ret =
      match x_.inverse() {
        | Some(x) => x,
        | None => Fp::zero(),
      };
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_square(x : *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let ret = x_.square();
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_add(x : *const Fp, y : *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ + &y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_mul(x : *const Fp, y : *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ * &y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_sub(x : *const Fp, y : *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ - &y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_mut_add(x : *mut Fp, y : *const Fp) {
    let x_ = unsafe { &mut(*x) };
    let y_ = unsafe { &(*y) };
    *x_ += &y_;
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_mut_mul(x : *mut Fp, y : *const Fp) {
    let x_ = unsafe { &mut(*x) };
    let y_ = unsafe { &(*y) };
    *x_ *= &y_;
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_mut_sub(x : *mut Fp, y : *const Fp) {
    let x_ = unsafe { &mut(*x) };
    let y_ = unsafe { &(*y) };
    *x_ -= &y_;
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_copy(x : *mut Fp, y : *const Fp) {
    unsafe { (*x) = *y };
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_rng(i : i32) -> *mut Fp {
    /* We only care about entropy here, so we force a conversion i32 -> u32. */
    let i : u64 = (i as u32).into();
    let mut rng : StdRng = rand::SeedableRng::seed_from_u64(i);
    let ret : Fp = UniformRand::rand(&mut rng);
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_delete(x : *mut Fp) {
    /* Deallocation happens automatically when a box variable goes out of
     * scope. */
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_print(x : *const Fp) {
    let x_ = unsafe { &(*x) };
    println!("{}", x_);
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_equal(x : *const Fp, y : *const Fp) -> bool {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    return *x_ == *y_;
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_vector_create() -> *mut Vec<Fp> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_vector_length(v : *const Vec<Fp>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_vector_emplace_back(v : *mut Vec<Fp>, x : *const Fp) {
    let v_ = unsafe { &mut(*v) };
    let x_ = unsafe { &(*x) };
    v_.push(*x_);
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_vector_get(v : *mut Vec<Fp>, i : u32) -> *mut Fp {
    let v_ = unsafe { &mut(*v) };
    return Box::into_raw(Box::new((*v_)[i as usize]));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_vector_delete(v : *mut Vec<Fp>) {
    /* Deallocation happens automatically when a box variable goes out of
     * scope. */
    let _box = unsafe { Box::from_raw(v) };
}

/* Fq stubs */

#[no_mangle]
pub extern fn camlsnark_bn382_fq_size_in_bits() -> i32 {
    return Fq_params::MODULUS_BITS as i32;
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_size() -> *mut BigInteger {
    let ret = Fq_params::MODULUS;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_is_square(x : *const Fq) -> bool {
    let x_ = unsafe { &(*x) };
    let ret =
      match x_.sqrt() {
        | Some(_) => true,
        | None => false,
      };
    return ret;
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_sqrt(x : *const Fq) -> *mut Fq {
    let x_ = unsafe { &(*x) };
    let ret =
      match x_.sqrt() {
        | Some(x) => x,
        | None => Fq::zero(),
      };
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_random() -> *mut Fq {
    let ret : Fq = UniformRand::rand(&mut rand::thread_rng());
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_of_int(i: u64) -> *mut Fq {
    let ret = Fq::from(i);
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_inv(x : *const Fq) -> *mut Fq {
    let x_ = unsafe { &(*x) };
    let ret =
      match x_.inverse() {
        | Some(x) => x,
        | None => Fq::zero(),
      };
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_square(x : *const Fq) -> *mut Fq {
    let x_ = unsafe { &(*x) };
    let ret = x_.square();
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_add(x : *const Fq, y : *const Fq) -> *mut Fq {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ + &y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_mul(x : *const Fq, y : *const Fq) -> *mut Fq {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ * &y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_sub(x : *const Fq, y : *const Fq) -> *mut Fq {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ - &y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_mut_add(x : *mut Fq, y : *const Fq) {
    let x_ = unsafe { &mut(*x) };
    let y_ = unsafe { &(*y) };
    *x_ += &y_;
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_mut_mul(x : *mut Fq, y : *const Fq) {
    let x_ = unsafe { &mut(*x) };
    let y_ = unsafe { &(*y) };
    *x_ *= &y_;
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_mut_sub(x : *mut Fq, y : *const Fq) {
    let x_ = unsafe { &mut(*x) };
    let y_ = unsafe { &(*y) };
    *x_ -= &y_;
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_copy(x : *mut Fq, y : *const Fq) {
    unsafe { (*x) = *y };
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_rng(i : i32) -> *mut Fq {
    /* We only care about entropy here, so we force a conversion i32 -> u32. */
    let i : u64 = (i as u32).into();
    let mut rng : StdRng = rand::SeedableRng::seed_from_u64(i);
    let ret : Fq = UniformRand::rand(&mut rng);
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_delete(x : *mut Fq) {
    /* Deallocation happens automatically when a box variable goes out of
     * scope. */
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_print(x : *const Fq) {
    let x_ = unsafe { &(*x) };
    println!("{}", x_);
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_equal(x : *const Fq, y : *const Fq) -> bool {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    return *x_ == *y_;
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_vector_create() -> *mut Vec<Fq> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_vector_length(v : *const Vec<Fq>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_vector_emplace_back(v : *mut Vec<Fq>, x : *const Fq) {
    let v_ = unsafe { &mut(*v) };
    let x_ = unsafe { &(*x) };
    v_.push(*x_);
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_vector_get(v : *mut Vec<Fq>, i : u32) -> *mut Fq {
    let v_ = unsafe { &mut(*v) };
    return Box::into_raw(Box::new((*v_)[i as usize]));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_vector_delete(v : *mut Vec<Fq>) {
    /* Deallocation happens automatically when a box variable goes out of
     * scope. */
    let _box = unsafe { Box::from_raw(v) };
}
