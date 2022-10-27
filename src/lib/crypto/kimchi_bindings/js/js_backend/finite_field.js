/* global joo_global_object, Uint8Array_, BigInt_
   caml_bigint_of_bytes, caml_js_to_bool, caml_string_of_jsstring
*/

// CONSTANTS

// the modulus. called `p` in most of our code.
// Provides: caml_pasta_p_bigint
// Requires: BigInt_
var caml_pasta_p_bigint = BigInt_('0x40000000000000000000000000000000224698fc094cf91b992d30ed00000001');
// Provides: caml_pasta_q_bigint
// Requires: BigInt_
var caml_pasta_q_bigint = BigInt_('0x40000000000000000000000000000000224698fc0994a8dd8c46eb2100000001');

// this is `t`, where p = 2^32 * t + 1
// Provides: caml_pasta_pm1_odd_factor
// Requires: BigInt_
var caml_pasta_pm1_odd_factor = BigInt_('0x40000000000000000000000000000000224698fc094cf91b992d30ed');
// Provides: caml_pasta_qm1_odd_factor
// Requires: BigInt_
var caml_pasta_qm1_odd_factor = BigInt_('0x40000000000000000000000000000000224698fc0994a8dd8c46eb21');

// primitive roots of unity, computed as (5^t mod p). this works because 5 generates the multiplicative group mod p
// Provides: caml_twoadic_root_fp
// Requires: BigInt_
var caml_twoadic_root_fp = BigInt_('0x2bce74deac30ebda362120830561f81aea322bf2b7bb7584bdad6fabd87ea32f');
// Provides: caml_twoadic_root_fq
// Requires: BigInt_
var caml_twoadic_root_fq = BigInt_('0x2de6a9b8746d3f589e5c4dfd492ae26e9bb97ea3c106f049a70e2c1102b6d05f')

// GENERAL FINITE FIELD ALGORITHMS

// Provides: caml_bigint_modulo
function caml_bigint_modulo(x, p) {
  x = x % p;
  if (x < 0) return x + p;
  return x;
}

// modular exponentiation, a^n % p
// Provides: caml_finite_field_power
// Requires: caml_bigint_modulo, BigInt_
function caml_finite_field_power(a, n, p) {
  a = caml_bigint_modulo(a, p);
  // this assumes that p is prime, so that a^(p-1) % p = 1
  n = caml_bigint_modulo(n, p - BigInt_(1));
  var x = BigInt_(1);
  for (; n > BigInt_(0); n >>= BigInt_(1)) {
    if (n & BigInt_(1)) x = caml_bigint_modulo(x * a, p);
    a = caml_bigint_modulo(a * a, p);
  }
  return x;
}

// inverting with EGCD, 1/a in Z_p
// Provides: caml_finite_field_inverse
// Requires: caml_bigint_modulo, BigInt_
function caml_finite_field_inverse(a, p) {
  a = caml_bigint_modulo(a, p);
  if (a === BigInt_(0)) return undefined;
  var b = p;
  var x = BigInt_(0);
  var y = BigInt_(1);
  var u = BigInt_(1);
  var v = BigInt_(0);
  while (a !== BigInt_(0)) {
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
  if (b !== BigInt_(1)) return undefined;
  return caml_bigint_modulo(x, p);
}

// Provides: caml_finite_field_sqrt
// Requires: BigInt_, caml_finite_field_power, caml_bigint_modulo, caml_pasta_p_bigint, caml_pasta_q_bigint, caml_twoadic_root_fp, caml_twoadic_root_fq, caml_pasta_pm1_odd_factor, caml_pasta_qm1_odd_factor, caml_pasta_p_bigint, caml_pasta_q_bigint
var caml_finite_field_sqrt = (function () {
  var precomputed_c = {};
  return function caml_finite_field_sqrt(n, p, Q, z) {
    // https://en.wikipedia.org/wiki/Tonelli-Shanks_algorithm#The_algorithm
    // variable naming is the same as in that link ^
    // Q is what we call `t` elsewhere - the odd factor in p - 1
    // z is a known non-square mod p. we pass in the primitive root of unity
    var M = BigInt_(32);
    var c =
      precomputed_c[p.toString()] ||
      (precomputed_c[p.toString()] = caml_finite_field_power(z, Q, p)); // z^Q
    // TODO: can we save work by sharing computation between t and R?
    var t = caml_finite_field_power(n, Q, p); // n^Q
    var R = caml_finite_field_power(n, (Q + BigInt_(1)) / BigInt_(2), p); // n^((Q + 1)/2)
    while (true) {
      if (t === BigInt_(0)) return BigInt_(0);
      if (t === BigInt_(1)) return R;
      // use repeated squaring to find the least i, 0 < i < M, such that t^(2^i) = 1
      var i = BigInt_(0);
      var s = t;
      while (s !== BigInt_(1)) {
        s = caml_bigint_modulo(s * s, p);
        i = i + BigInt_(1);
      }
      if (i === M) return undefined; // no solution
      var b = caml_finite_field_power(c, (BigInt_(1) << (M - i - BigInt_(1))), p); // c^(2^(M-i-1))
      M = i;
      c = caml_bigint_modulo(b * b, p);
      t = caml_bigint_modulo(t * c, p);
      R = caml_bigint_modulo(R * b, p);
    }
  }
})();

// Provides: caml_finite_field_is_square
// Requires: caml_finite_field_power, BigInt_
function caml_finite_field_is_square(x, p) {
  if (x === BigInt_(0)) return 1;
  var sqrt_1 = caml_finite_field_power(x, (p - BigInt_(1)) / BigInt_(2), p);
  return Number(sqrt_1 === BigInt_(1));
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

// Provides: caml_finite_field_domain_generator
// Requires: caml_bigint_modulo, caml_bindings_debug, BigInt_
function caml_finite_field_domain_generator(i, p, primitive_root_of_unity) {
  // this takes an integer i and returns the 2^ith root of unity, i.e. a number `w` with
  // w^(2^i) = 1, w^(2^(i-1)) = -1
  // computed by taking the 2^32th root and squaring 32-i times
  if (i > 32 || i < 0) throw Error('log2 size of evaluation domain must be in [0, 32], got ' + i);
  if (i === 0) return BigInt_(1);
  var generator = primitive_root_of_unity;
  for (var j = 32; j > i; j--) {
    generator = caml_bigint_modulo(generator * generator, p);
  }
  return generator;
}

// SPECIALIZATIONS TO FP, FQ
// these get exported to ocaml, and should be mostly trivial

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
  if (!x[0]) return [x[0]];
  return [caml_pasta_p_bigint - x[0]];
}
// Provides: caml_pasta_fq_negate
// Requires: caml_pasta_q_bigint
function caml_pasta_fq_negate(x) {
  if (!x[0]) return [x[0]];
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

// Provides: caml_pasta_option
function caml_pasta_option(x) {
  if (x === undefined || x[0] === undefined) return 0; // None
  return [0, x]; // Some(x)
}

// Provides: caml_pasta_fp_option
// Requires: caml_pasta_option
var caml_pasta_fp_option = caml_pasta_option;
// Provides: caml_pasta_fq_option
// Requires: caml_pasta_option
var caml_pasta_fq_option = caml_pasta_option;

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
// Requires: caml_pasta_fp_sub, BigInt_
function caml_pasta_fp_equal(x, y) {
  return Number(x[0] === y[0]);
}
// Provides: caml_pasta_fq_equal
// Requires: caml_pasta_fq_sub, BigInt_
function caml_pasta_fq_equal(x, y) {
  return Number(x[0] === y[0]);
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

// Provides: caml_pasta_fp_domain_generator
// Requires: caml_finite_field_domain_generator, caml_pasta_p_bigint, caml_twoadic_root_fp
function caml_pasta_fp_domain_generator(i) {
  return [caml_finite_field_domain_generator(i, caml_pasta_p_bigint, caml_twoadic_root_fp)];
}
// Provides: caml_pasta_fq_domain_generator
// Requires: caml_finite_field_domain_generator, caml_pasta_q_bigint, caml_twoadic_root_fq
function caml_pasta_fq_domain_generator(i) {
  return [caml_finite_field_domain_generator(i, caml_pasta_q_bigint, caml_twoadic_root_fq)];
}

// TESTS (activate by setting caml_bindings_debug = true)

// Provides: caml_bindings_debug
var caml_bindings_debug = false;

// Provides: _test_finite_field
// Requires: caml_bindings_debug, caml_pasta_p_bigint, caml_pasta_q_bigint, caml_pasta_pm1_odd_factor, caml_pasta_qm1_odd_factor, BigInt_, caml_twoadic_root_fp, caml_twoadic_root_fq, caml_finite_field_power, caml_pasta_fp_is_square, caml_pasta_fq_is_square, caml_finite_field_domain_generator
var _test_finite_field = caml_bindings_debug && (function test() {
  var console = joo_global_object.console;
  // t is computed correctly from p = 2^32 * t + 1
  console.assert(caml_pasta_pm1_odd_factor * (BigInt_(1) << BigInt_(32)) + BigInt_(1) === caml_pasta_p_bigint);
  console.assert(caml_pasta_qm1_odd_factor * (BigInt_(1) << BigInt_(32)) + BigInt_(1) === caml_pasta_q_bigint);

  // the primitive root of unity is computed correctly as 5^t
  var generator = BigInt_(5);
  var root_fp = caml_finite_field_power(generator, caml_pasta_pm1_odd_factor, caml_pasta_p_bigint);
  console.assert(root_fp === caml_twoadic_root_fp);
  var root_fq = caml_finite_field_power(generator, caml_pasta_qm1_odd_factor, caml_pasta_q_bigint);
  console.assert(root_fq === caml_twoadic_root_fq);

  // the primitive roots of unity `r` actually satisfy the equations defining them:
  // r^(2^32) = 1, r^(2^31) != 1
  var should_be_1 = caml_finite_field_power(caml_twoadic_root_fp, (BigInt_(1) << BigInt_(32)), caml_pasta_p_bigint);
  var should_be_minus_1 = caml_finite_field_power(caml_twoadic_root_fp, (BigInt_(1) << BigInt_(31)), caml_pasta_p_bigint);
  console.assert(should_be_1 === BigInt_(1));
  console.assert(should_be_minus_1 + BigInt_(1) === caml_pasta_p_bigint);

  should_be_1 = caml_finite_field_power(caml_twoadic_root_fq, (BigInt_(1) << BigInt_(32)), caml_pasta_q_bigint);
  should_be_minus_1 = caml_finite_field_power(caml_twoadic_root_fq, (BigInt_(1) << BigInt_(31)), caml_pasta_q_bigint);
  console.assert(should_be_1 === BigInt_(1));
  console.assert(should_be_minus_1 + BigInt_(1) === caml_pasta_q_bigint);

  // the primitive roots of unity are non-squares
  // -> verifies that the two-adicity is 32, and that they can be used as non-squares in the sqrt algorithm
  console.assert(caml_pasta_fp_is_square([caml_twoadic_root_fp]) === 0);
  console.assert(caml_pasta_fq_is_square([caml_twoadic_root_fq]) === 0);

  // the domain generator for log2_size=i satisfies the equations we expect:
  // generator^(2^i) = 1, generator^(2^(i-1)) = -1
  var i = 10;
  var domain_gen = caml_finite_field_domain_generator(i, caml_pasta_p_bigint, caml_twoadic_root_fp);
  should_be_1 = caml_finite_field_power(domain_gen, BigInt_(1) << BigInt_(i), caml_pasta_p_bigint);
  should_be_minus_1 = caml_finite_field_power(domain_gen, BigInt_(1) << BigInt_(i-1), caml_pasta_p_bigint);
  console.assert(should_be_1 === BigInt_(1));
  console.assert(should_be_minus_1 + BigInt_(1) === caml_pasta_p_bigint);
})()
