extern crate libc;
use algebra::{
  biginteger::BigInteger,
  biginteger::BigInteger384,
  fields::{
    FpParameters,
    bn_382::fp::FpParameters as Fp_params,
    bn_382::fp::Fp as Fp,
    bn_382::fq::FqParameters as Fq_params,
    bn_382::fq::Fq as Fq,
    Field,
    SquareRootField,
    PrimeField,
  },
  UniformRand,
};
use rand::rngs::StdRng as StdRng;
use num_bigint::BigUint;

/* NOTE: We always 'box' these values as pointers, since the FFI doesn't know
 * the size of the target type, and annotating them with (void *) on the other
 * side of the FFI would cause only the first 64 bits to be copied. */

/* Bigint stubs */

const BIGINT_NUM_BITS : i32 = 384;
const BIGINT_LIMB_BITS : i32 = 64;
const BIGINT_NUM_LIMBS : i32 = (BIGINT_NUM_BITS + BIGINT_LIMB_BITS - 1) / BIGINT_LIMB_BITS;
const BIGINT_NUM_BYTES : usize = (BIGINT_NUM_LIMBS as usize) * 8;

fn bigint_of_biginteger(x : &BigInteger384) -> BigUint {
    let x_ = (*x).0.as_ptr() as *const u8;
    let x_ = unsafe { std::slice::from_raw_parts(x_, BIGINT_NUM_BYTES) };
    num_bigint::BigUint::from_bytes_le(x_)
}

/* NOTE: This drops the high bits. */
fn biginteger_of_bigint(x : &BigUint) -> BigInteger384 {
    let mut bytes = x.to_bytes_le();
    bytes.resize(BIGINT_NUM_BYTES, 0);
    let limbs = bytes.as_ptr();
    let limbs = limbs as *const [u64; BIGINT_NUM_LIMBS as usize];
    let limbs = unsafe { &(*limbs) };
    BigInteger384(*limbs)
}

#[no_mangle]
pub extern fn camlsnark_bn382_bigint_of_decimal_string(s : *const i8) -> *mut BigInteger384 {
    let c_str : &std::ffi::CStr = unsafe { std::ffi::CStr::from_ptr(s) };
    let s_ : &[u8] = c_str.to_bytes();
    let res =
      match BigUint::parse_bytes(s_, 10) {
        | Some(x) => x,
        | None => panic!("camlsnark_bn382_bigint_of_numeral: Could not convert numeral."),
      };
    return Box::into_raw(Box::new(biginteger_of_bigint(&res)));
}

#[no_mangle]
pub extern fn camlsnark_bn382_bigint_num_limbs() -> i32 {
    /* HACK: Manually compute the number of limbs. */
    return (BIGINT_NUM_BITS + BIGINT_LIMB_BITS - 1) / BIGINT_LIMB_BITS;
}

#[no_mangle]
pub extern fn camlsnark_bn382_bigint_to_data(x : *mut BigInteger384) -> *mut u64 {
    let x_ = unsafe { &mut (*x) };
    return (*x_).0.as_mut_ptr();
}

#[no_mangle]
pub extern fn camlsnark_bn382_bigint_of_data(x : *mut u64) -> *mut BigInteger384 {
    let x_ = unsafe { std::slice::from_raw_parts(x, BIGINT_NUM_LIMBS as usize) };
    let mut ret : std::boxed::Box<BigInteger384> = Box::new(Default::default());
    (*ret).0.copy_from_slice(x_);
    return Box::into_raw(ret);
}

#[no_mangle]
pub extern fn camlsnark_bn382_bigint_bytes_per_limb() -> i32 {
    /* HACK: Manually compute the bytes per limb. */
    return BIGINT_LIMB_BITS / 8;
}

#[no_mangle]
pub extern fn camlsnark_bn382_bigint_div(x : *const BigInteger384, y : *const BigInteger384) -> *mut BigInteger384 {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let res = bigint_of_biginteger(&x_) / &bigint_of_biginteger(&y_);
    return Box::into_raw(Box::new(biginteger_of_bigint(&res)));
}

#[no_mangle]
pub extern fn camlsnark_bn382_bigint_of_numeral(s : *const u8, len : u32, base : u32) -> *mut BigInteger384 {
    let s_ = unsafe { std::slice::from_raw_parts(s, len as usize) };
    let res =
      match BigUint::parse_bytes(s_, base) {
        | Some(x) => x,
        | None => panic!("camlsnark_bn382_bigint_of_numeral: Could not convert numeral."),
      };
    return Box::into_raw(Box::new(biginteger_of_bigint(&res)));
}

#[no_mangle]
pub extern fn camlsnark_bn382_bigint_compare(x : *const BigInteger384, y : *const BigInteger384) -> bool {
    let _x = unsafe { &(*x) };
    let _y = unsafe { &(*y) };
    return _x < _y;
}

#[no_mangle]
pub extern fn camlsnark_bn382_bigint_test_bit(x : *const BigInteger384, i : i32) -> bool {
    let _x = unsafe { &(*x) };
    return _x.get_bit(i as usize);
}

#[no_mangle]
pub extern fn camlsnark_bn382_bigint_delete(x : *mut BigInteger384) {
    /* Deallocation happens automatically when a box variable goes out of
     * scope. */
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern fn camlsnark_bn382_bigint_print(x : *const BigInteger384) {
    let x_ = unsafe { &(*x) };
    println!("{}", *x_);
}

#[no_mangle]
pub extern fn camlsnark_bn382_bigint_find_wnaf(_size : usize, x : *const BigInteger384) -> *const Vec<i64> {
    /* FIXME:
     * - as it stands, we have to ignore the first parameter
     * - in snarky the return type will be a Long_vector.t, which is a C++ vector, not a rust one
     */
    if true {
      panic!("camlsnark_bn382_bigint_find_wnaf is not implemented");
    }
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(x_.find_wnaf()));
}

/* Fp stubs */

#[no_mangle]
pub extern fn camlsnark_bn382_fp_size_in_bits() -> i32 {
    return Fp_params::MODULUS_BITS as i32;
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_size() -> *mut BigInteger384 {
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
    println!("{}", *x_);
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_equal(x : *const Fp, y : *const Fp) -> bool {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    return *x_ == *y_;
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_to_bigint(x : *const Fp) -> *mut BigInteger384 {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(x_.into_repr()));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fp_of_bigint(x : *const BigInteger384) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(Fp::from_repr(*x_)));
}

/* Fp vector stubs */

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
pub extern fn camlsnark_bn382_fq_size() -> *mut BigInteger384 {
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
pub extern fn camlsnark_bn382_fq_to_bigint(x : *const Fq) -> *mut BigInteger384 {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(x_.into_repr()));
}

#[no_mangle]
pub extern fn camlsnark_bn382_fq_of_bigint(x : *const BigInteger384) -> *mut Fq {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(Fq::from_repr(*x_)));
}

/* Fq vector stubs */

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
