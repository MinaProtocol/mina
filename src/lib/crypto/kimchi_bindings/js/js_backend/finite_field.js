/* global joo_global_object, Uint8Array_, BigInt_, _0n, _1n, _2n, _32n,
   caml_bigint_of_bytes, caml_js_to_bool, caml_string_of_jsstring
*/

// Provides: caml_pasta_p_bigint
// Requires: BigInt_
var caml_pasta_p_bigint = BigInt_('0x40000000000000000000000000000000224698fc094cf91b992d30ed00000001');
// Provides: caml_pasta_q_bigint
// Requires: BigInt_
var caml_pasta_q_bigint = BigInt_('0x40000000000000000000000000000000224698fc0994a8dd8c46eb2100000001');
// Provides: caml_pasta_pm1_odd_factor
// Requires: BigInt_
var caml_pasta_pm1_odd_factor = BigInt_('0x40000000000000000000000000000000224698fc094cf91b992d30ed');
// Provides: caml_pasta_qm1_odd_factor
// Requires: BigInt_
var caml_pasta_qm1_odd_factor = BigInt_('0x40000000000000000000000000000000224698fc0994a8dd8c46eb21');
// Provides: caml_generator_fp
// Requires: BigInt_
var caml_generator_fp = BigInt_('0x3ffffffffffffffffffffffffffffffd74c2a54b4f4982f3a1a55e68ffffffed');
// Provides: caml_generator_fq
// Requires: BigInt_
var caml_generator_fq = BigInt_('0x3ffffffffffffffffffffffffffffffd74c2a54b49f7778e96bc8c8cffffffed');

// roots were computed as
// caml_generator_fp ^ caml_pasta_pm1_odd_factor
// Provides: caml_twoadic_root_fp
// Requires: BigInt_
var caml_twoadic_root_fp = BigInt_('0x36af506de441e63f43e174a0d0486218e8d45c8e1e4e2aeafee6f241e866a1e2');
// Provides: caml_twoadic_root_fq
// Requires: BigInt_
var caml_twoadic_root_fq = BigInt_('0x208eb64428e3a2437f41103ce0bc78da9219cac2ca68b3377bb6a48c528523b2')

// Provides: caml_bigint_modulo
function caml_bigint_modulo(x, p) {
  x = x % p;
  if (x < 0) return x + p;
  return x;
}

// modular exponentiation, a^n % p
// Provides: caml_finite_field_power
// Requires: caml_bigint_modulo, _0n, _1n
function caml_finite_field_power(a, n, p) {
  a = caml_bigint_modulo(a, p);
  // this assumes that p is prime, so that a^(p-1) % p = 1
  n = caml_bigint_modulo(n, p - _1n);
  var x = _1n;
  for (; n > _0n; n >>= _1n) {
    if (n & _1n) x = caml_bigint_modulo(x * a, p);
    a = caml_bigint_modulo(a * a, p);
  }
  return x;
}

// inverting with EGCD, 1/a in Z_p
// Provides: caml_finite_field_inverse
// Requires: caml_bigint_modulo, _0n, _1n
function caml_finite_field_inverse(a, p) {
  var a_orig = a;
  a = caml_bigint_modulo(a, p);
  if (a === _0n) throw Error("cannot invert 0");
  var b = p;
  var x = _0n;
  var y = _1n;
  var u = _1n;
  var v = _0n;
  while (a !== _0n) {
    var q = b / a;
    var r = caml_bigint_modulo(b, a);
    var m = x - u * q;
    var n = y - v * q;
    b = a;
    a = r;
    x = u;
    y = v;
    u = m;
    v = n;
  }
  if (b !== _1n) throw Error("inverting failed (no inverse)");
  if (caml_bigint_modulo(x * a_orig, p) !== _1n) throw Error("caml_finite_field_inverse has a bug");
  return caml_bigint_modulo(x, p);
}

// https://en.wikipedia.org/wiki/Tonelli-Shanks_algorithm#The_algorithm
// Provides: caml_finite_field_sqrt
// Requires: _32n, _0n, _1n, _2n, caml_finite_field_power, caml_bigint_modulo
function caml_finite_field_sqrt(n, p, pm1_odd, fp_root) {
  var M = _32n;
  var c = caml_finite_field_power(fp_root, pm1_odd, p); // z^Q
  var t = caml_finite_field_power(n, pm1_odd, p); // n^Q
  var R = caml_finite_field_power(n, (pm1_odd + _1n) / _2n, p); // n^((Q + 1)/2)
  while (true) {
    if (t === _0n) return _0n;
    if (t === _1n) {
      if (caml_bigint_modulo(R * R - n, p) !== _0n) throw Error("caml_finite_field_sqrt has a bug");
      return R;
    }
    // use repeated squaring to find the least i, 0 < i < M, such that t^(2^i) = 1
    var i = _0n;
    var s = t;
    while (s !== _1n) {
      s = caml_bigint_modulo(s * s, p);
      i = i + _1n;
    }
    if (i === M) return undefined; // no solution
    var b = caml_finite_field_power(c, (_1n << (M - i - _1n)), p); // c^(2^(M-i-1))
    M = i;
    c = caml_bigint_modulo(b * b, p);
    t = caml_bigint_modulo(t * c, p);
    R = caml_bigint_modulo(R * b, p);
  }
}

// Provides: caml_finite_field_is_square
// Requires: caml_finite_field_power, _0n, _1n, _2n
function caml_finite_field_is_square(x, p) {
  if (x === _0n) return 1;
  var sqrt_1 = caml_finite_field_power(x, (p - _1n) / _2n, p);
  return Number(sqrt_1 === _1n);
}

// Provides: caml_random_bytes
// Requires: Uint8Array_
var caml_random_bytes = (function() {
  // have to use platform-dependent secure randomness
  var crypto = joo_global_object.crypto;
  if (crypto !== undefined && crypto.getRandomValues !== undefined) {
    // browser / deno
    return function randomBytes(n) {
      return crypto.getRandomValues(new Uint8Array_(n));
    }
  } else if (typeof require !== "undefined") {
    // node (common JS)
    crypto = require("node:crypto");
    return function randomBytes(n) {
      return new Uint8Array_(crypto.randomBytes(n));
    }
  } else {
    throw Error("don't know how to find random number generator for this platform without breaking other platforms");
  }
})();

// Provides: caml_finite_field_random
// Requires: caml_random_bytes, caml_bigint_of_bytes
function caml_finite_field_random(p) {
  // strategy: find random 255-bit bigints and use the first that's smaller than p
  while (true) {
    var bytes = caml_random_bytes(32);
    bytes[31] &= 0x7f; // zero highest bit, so we get 255 random bits
    var x = caml_bigint_of_bytes(bytes);
    if (x < p) return x;
  }
}

// Provides: caml_pasta_fp_add
// Requires: caml_bigint_modulo, caml_pasta_p_bigint
function caml_pasta_fp_add(x, y) {
  return [caml_bigint_modulo(x[0] + y[0], caml_pasta_p_bigint)];
}
// Provides: caml_pasta_fq_add
// Requires: caml_bigint_modulo, caml_pasta_q_bigint
function caml_pasta_fq_add(x, y) {
  return [caml_bigint_modulo(x[0] + y[0], caml_pasta_q_bigint)];
}

// Provides: caml_pasta_fp_negate
// Requires: caml_pasta_p_bigint
function caml_pasta_fp_negate(x) {
  return [caml_pasta_p_bigint - x[0]];
}
// Provides: caml_pasta_fq_negate
// Requires: caml_pasta_q_bigint
function caml_pasta_fq_negate(x) {
  return [caml_pasta_q_bigint - x[0]];
}

// Provides: caml_pasta_fp_sub
// Requires: caml_bigint_modulo, caml_pasta_p_bigint
function caml_pasta_fp_sub(x, y) {
  return [caml_bigint_modulo(x[0] - y[0], caml_pasta_p_bigint)];
}
// Provides: caml_pasta_fq_sub
// Requires: caml_bigint_modulo, caml_pasta_q_bigint
function caml_pasta_fq_sub(x, y) {
  return [caml_bigint_modulo(x[0] - y[0], caml_pasta_q_bigint)];
}

// Provides: caml_pasta_fp_mul
// Requires: caml_bigint_modulo, caml_pasta_p_bigint
function caml_pasta_fp_mul(x, y) {
  return [caml_bigint_modulo(x[0] * y[0], caml_pasta_p_bigint)];
}
// Provides: caml_pasta_fq_mul
// Requires: caml_bigint_modulo, caml_pasta_q_bigint
function caml_pasta_fq_mul(x, y) {
  return [caml_bigint_modulo(x[0] * y[0], caml_pasta_q_bigint)];
}

// Provides: caml_pasta_fp_option
function caml_pasta_fp_option(x) {
  if (x === undefined) return 0; // None
  return [0, x]; // Some(x)
}
// Provides: caml_pasta_fq_option
function caml_pasta_fq_option(x) {
  if (x === undefined) return 0; // None
  return [0, x]; // Some(x)
}

// Provides: caml_pasta_fp_inv
// Requires: caml_finite_field_inverse, caml_pasta_p_bigint, caml_pasta_fp_option
function caml_pasta_fp_inv(x) {
  var xinv = [caml_finite_field_inverse(x[0], caml_pasta_p_bigint)];
  return caml_pasta_fp_option(xinv);
}
// Provides: caml_pasta_fq_inv
// Requires: caml_finite_field_inverse, caml_pasta_q_bigint, caml_pasta_fq_option
function caml_pasta_fq_inv(x) {
  var xinv = [caml_finite_field_inverse(x[0], caml_pasta_q_bigint)];
  return caml_pasta_fq_option(xinv);
}

// Provides: caml_pasta_fp_div
// Requires: caml_bigint_modulo, caml_finite_field_inverse, caml_pasta_p_bigint
function caml_pasta_fp_div(x, y) {
  return [caml_bigint_modulo(x[0] * caml_finite_field_inverse(y[0], caml_pasta_p_bigint), caml_pasta_p_bigint)];
}
// Provides: caml_pasta_fq_div
// Requires: caml_bigint_modulo, caml_finite_field_inverse, caml_pasta_q_bigint
function caml_pasta_fq_div(x, y) {
  return [caml_bigint_modulo(x[0] * caml_finite_field_inverse(y[0], caml_pasta_q_bigint), caml_pasta_q_bigint)];
}

// Provides: caml_pasta_fp_square
// Requires: caml_pasta_fp_mul
function caml_pasta_fp_square(x) {
  return caml_pasta_fp_mul(x, x);
}
// Provides: caml_pasta_fq_square
// Requires: caml_pasta_fq_mul
function caml_pasta_fq_square(x) {
  return caml_pasta_fq_mul(x, x);
}

// Provides: caml_pasta_fp_is_square
// Requires: caml_finite_field_is_square, caml_pasta_p_bigint, caml_js_to_bool
function caml_pasta_fp_is_square(x) {
  var is_square = caml_finite_field_is_square(x[0], caml_pasta_p_bigint);
  return caml_js_to_bool(is_square);
}
// Provides: caml_pasta_fq_is_square
// Requires: caml_finite_field_is_square, caml_pasta_q_bigint, caml_js_to_bool
function caml_pasta_fq_is_square(x) {
  var is_square = caml_finite_field_is_square(x[0], caml_pasta_q_bigint);
  return caml_js_to_bool(is_square);
}

// Provides: caml_pasta_fp_sqrt
// Requires: caml_finite_field_sqrt, caml_pasta_fp_option, caml_pasta_p_bigint, caml_pasta_pm1_odd_factor, caml_twoadic_root_fp
function caml_pasta_fp_sqrt(x) {
  var sqrt = [caml_finite_field_sqrt(x[0], caml_pasta_p_bigint, caml_pasta_pm1_odd_factor, caml_twoadic_root_fp)];
  return caml_pasta_fp_option(sqrt);
}
// Provides: caml_pasta_fq_sqrt
// Requires: caml_finite_field_sqrt, caml_pasta_fq_option, caml_pasta_q_bigint, caml_pasta_qm1_odd_factor, caml_twoadic_root_fq
function caml_pasta_fq_sqrt(x) {
  var sqrt = [caml_finite_field_sqrt(x[0], caml_pasta_q_bigint, caml_pasta_qm1_odd_factor, caml_twoadic_root_fq)];
  return caml_pasta_fq_option(sqrt);
}

// Provides: caml_pasta_fp_equal
// Requires: caml_pasta_fp_sub, _0n
function caml_pasta_fp_equal(x, y) {
  return Number(caml_pasta_fp_sub(x, y)[0] === _0n);
}
// Provides: caml_pasta_fq_equal
// Requires: caml_pasta_fq_sub, _0n
function caml_pasta_fq_equal(x, y) {
  return Number(caml_pasta_fq_sub(x, y)[0] === _0n);
}

// Provides: caml_pasta_fp_random
// Requires: caml_finite_field_random, caml_pasta_p_bigint
function caml_pasta_fp_random() {
  return [caml_finite_field_random(caml_pasta_p_bigint)];
}
// Provides: caml_pasta_fq_random
// Requires: caml_finite_field_random, caml_pasta_q_bigint
function caml_pasta_fq_random() {
  return [caml_finite_field_random(caml_pasta_q_bigint)];
}

// Provides: caml_pasta_fp_of_int
// Requires: BigInt_
function caml_pasta_fp_of_int(i) {
  return [BigInt_(i)];
}
// Provides: caml_pasta_fq_of_int
// Requires: BigInt_
function caml_pasta_fq_of_int(i) {
  return [BigInt_(i)];
}

// Provides: caml_pasta_fp_of_bigint
function caml_pasta_fp_of_bigint(x) { return x; }
// Provides: caml_pasta_fq_of_bigint
function caml_pasta_fq_of_bigint(x) { return x; }
// Provides: caml_pasta_fp_to_bigint
function caml_pasta_fp_to_bigint(x) { return x; }
// Provides: caml_pasta_fq_to_bigint
function caml_pasta_fq_to_bigint(x) { return x; }

// Provides: caml_pasta_fp_to_string
// Requires: caml_string_of_jsstring
function caml_pasta_fp_to_string(x) {
  return caml_string_of_jsstring(x[0].toString());
}
// Provides: caml_pasta_fq_to_string
// Requires: caml_string_of_jsstring
function caml_pasta_fq_to_string(x) {
  return caml_string_of_jsstring(x[0].toString());
}

// Provides: caml_pasta_fp_size
// Requires: caml_pasta_p_bigint
function caml_pasta_fp_size() {
  return [caml_pasta_p_bigint];
}
// Provides: caml_pasta_fq_size
// Requires: caml_pasta_q_bigint
function caml_pasta_fq_size() {
  return [caml_pasta_q_bigint];
}
// Provides: caml_pasta_fp_size_in_bits
function caml_pasta_fp_size_in_bits() { return 255; }
// Provides: caml_pasta_fq_size_in_bits
function caml_pasta_fq_size_in_bits() { return 255; }


// Provides: caml_pasta_fp_copy
function caml_pasta_fp_copy(x, y) {
  x[0] = y[0];
}
// Provides: caml_pasta_fq_copy
function caml_pasta_fq_copy(x, y) {
  x[0] = y[0];
}
// Provides: operation_to_mutation
function operation_to_mutation(op) {
  return function (x, y) {
    x[0] = op(x, y)[0];
  }
}
// Provides: caml_pasta_fp_mut_add
// Requires: operation_to_mutation, caml_pasta_fp_add
var caml_pasta_fp_mut_add = operation_to_mutation(caml_pasta_fp_add);
// Provides: caml_pasta_fq_mut_add
// Requires: operation_to_mutation, caml_pasta_fq_add
var caml_pasta_fq_mut_add = operation_to_mutation(caml_pasta_fq_add);
// Provides: caml_pasta_fp_mut_sub
// Requires: operation_to_mutation, caml_pasta_fp_sub
var caml_pasta_fp_mut_sub = operation_to_mutation(caml_pasta_fp_sub);
// Provides: caml_pasta_fq_mut_sub
// Requires: operation_to_mutation, caml_pasta_fq_sub
var caml_pasta_fq_mut_sub = operation_to_mutation(caml_pasta_fq_sub);
// Provides: caml_pasta_fp_mut_mul
// Requires: operation_to_mutation, caml_pasta_fp_mul
var caml_pasta_fp_mut_mul = operation_to_mutation(caml_pasta_fp_mul);
// Provides: caml_pasta_fq_mut_mul
// Requires: operation_to_mutation, caml_pasta_fq_mul
var caml_pasta_fq_mut_mul = operation_to_mutation(caml_pasta_fq_mul);
// Provides: caml_pasta_fp_mut_square
// Requires: caml_pasta_fp_copy, caml_pasta_fp_square
function caml_pasta_fp_mut_square(x) {
  caml_pasta_fp_copy(x, caml_pasta_fp_square(x));
}
// Provides: caml_pasta_fq_mut_square
// Requires: caml_pasta_fq_copy, caml_pasta_fq_square
function caml_pasta_fq_mut_square(x) {
  caml_pasta_fq_copy(x, caml_pasta_fq_square(x));
}


// Provides: caml_bindings_debug
var caml_bindings_debug = false;

// TODO fix failing assertions
// Provides: _test_finite_field
// Requires: caml_bindings_debug, caml_pasta_p_bigint, caml_pasta_q_bigint, caml_pasta_pm1_odd_factor, caml_pasta_qm1_odd_factor, BigInt_, _1n, _32n, caml_twoadic_root_fp, caml_twoadic_root_fq, caml_finite_field_power, caml_pasta_fp_is_square, caml_pasta_fq_is_square
var _test_finite_field = caml_bindings_debug && (function test() {
  var console = joo_global_object.console;
  console.assert(caml_pasta_pm1_odd_factor * (_1n << _32n) + _1n === caml_pasta_p_bigint);
  console.assert(caml_pasta_qm1_odd_factor * (_1n << _32n) + _1n === caml_pasta_q_bigint);

  // var generator = BigInt_(5); // works for both fp and fq
  // var alt_root_fp = caml_finite_field_power(generator, caml_pasta_pm1_odd_factor, caml_pasta_p_bigint);
  // console.log(alt_root_fp.toString(16));
  // var alt_root_fq = caml_finite_field_power(generator_fq, caml_pasta_qm1_odd_factor, caml_pasta_q_bigint);
  // console.log(alt_root_fq.toString(16));

  var should_be_1 = caml_finite_field_power(caml_twoadic_root_fp, (_1n << _32n), caml_pasta_p_bigint);
  var should_be_minus_1 = caml_finite_field_power(caml_twoadic_root_fp, (_1n << BigInt_(31)), caml_pasta_p_bigint);
  console.assert(should_be_1 === _1n);
  console.assert(should_be_minus_1 + _1n === caml_pasta_p_bigint);

  should_be_1 = caml_finite_field_power(caml_twoadic_root_fq, (_1n << _32n), caml_pasta_q_bigint);
  should_be_minus_1 = caml_finite_field_power(caml_twoadic_root_fq, (_1n << BigInt_(31)), caml_pasta_q_bigint);
  console.assert(should_be_1 === _1n);
  console.assert(should_be_minus_1 + _1n === caml_pasta_q_bigint);

  console.assert(caml_pasta_fp_is_square([caml_twoadic_root_fp]) === 0);
  console.assert(caml_pasta_fq_is_square([caml_twoadic_root_fq]) === 0);
})()
