/* global joo_global_object, Uint8Array_, BigInt_, _0n, _1n, _2n, _32n,
   caml_bigint_to_bytes, caml_bigint_of_bytes
*/


// Provides: caml_pasta_p_bigint
// Requires: BigInt_
var caml_pasta_p_bigint = BigInt_('0x40000000000000000000000000000000224698fc094cf91b992d30ed00000001');
// Provides: caml_pasta_q_bigint
// Requires: BigInt_
var caml_pasta_q_bigint = BigInt_('0x40000000000000000000000000000000224698fc0994a8dd8c46eb2100000001');
// Provides: caml_pasta_pm1_odd_factor
// Requires: BigInt_
var caml_pasta_pm1_odd_factor = BigInt_('0x40000000000000000000000000000000224698fc094cf91b992d30ed')
// Provides: caml_pasta_qm1_odd_factor
// Requires: BigInt_
var caml_pasta_qm1_odd_factor = BigInt_('0x40000000000000000000000000000000224698fc0994a8dd8c46eb21')

// helper to easily copy over values from Rust
// Provides: caml_bigint_from_hex_limbs
// Requires: BigInt_, _1n
function caml_bigint_from_hex_limbs(limbs) {
  return BigInt_(limbs[0]) + 
    (_1n << BigInt_(1 * 64)) * BigInt_(limbs[1]) + 
    (_1n << BigInt_(2 * 64)) * BigInt_(limbs[2]) + 
    (_1n << BigInt_(3 * 64)) * BigInt_(limbs[3])
}

// Provides: caml_twoadic_root_fp
// Requires: caml_bigint_from_hex_limbs
var caml_twoadic_root_fp = caml_bigint_from_hex_limbs([
  "0xa28db849bad6dbf0", "0x9083cd03d3b539df", "0xfba6b9ca9dc8448e", "0x3ec928747b89c6da"
]);
// Provides: caml_twoadic_root_fq
// Requires: caml_bigint_from_hex_limbs
var caml_twoadic_root_fq = caml_bigint_from_hex_limbs([
  "0x218077428c9942de", "0xcc49578921b60494", "0xac2e5d27b2efbee2", "0x0b79fa897f2db056"
]);

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

// Provides: plonk_wasm
// Requires: caml_bigint_to_bytes, caml_bigint_of_bytes, caml_bigint_modulo, caml_pasta_p_bigint, caml_pasta_q_bigint, BigInt_, Uint8Array_, GroupProjective, caml_pallas_generator_projective, caml_vesta_generator_projective, caml_group_projective_sub, _0n, _1n, _2n, caml_finite_field_inverse, caml_finite_field_power, caml_finite_field_sqrt, caml_pallas_endo_base_const, caml_pallas_endo_scalar_const, caml_pasta_pm1_odd_factor, caml_pasta_qm1_odd_factor, caml_twoadic_root_fp, caml_twoadic_root_fq, caml_vesta_endo_base_const, caml_vesta_endo_scalar_const, caml_finite_field_random, caml_group_projective_add, caml_group_projective_neg, caml_group_projective_scale, caml_group_projective_to_affine
var plonk_wasm = {
  caml_bigint_256_num_limbs: function() {
    return 4;
  },
  caml_bigint_256_bytes_per_limb: function() {
    return 8;
  },
  caml_bigint_256_of_bytes: function(arr) {
    return [caml_bigint_of_bytes(arr)];
  },
  caml_bigint_256_of_decimal_string: function(s) {
    return [BigInt_(s)];
  },
  caml_bigint_256_to_string: function(b) {
    return b[0].toString();
  },
  caml_bigint_256_to_bytes: function(b) {
    return caml_bigint_to_bytes(b[0], 32);
  },
  caml_bigint_256_test_bit: function(b, i) {
    return Number(!!(b[0] & (BigInt_(1) << BigInt_(i))))
  },
  caml_bigint_256_compare: function(x, y) {
    x = x[0], y = y[0];
    if (x < y) return -1;
    if (x === y) return 0;
    return 1;
  },
  caml_pasta_fp_size: function() {
    return [caml_pasta_p_bigint];
  },
  caml_pasta_fq_size: function() {
    return [caml_pasta_q_bigint];
  },
  caml_pasta_fp_add: function(x, y) {
    return [caml_bigint_modulo(x[0] + y[0], caml_pasta_p_bigint)];
  },
  caml_pasta_fq_add: function(x, y) {
    return [caml_bigint_modulo(x[0] + y[0], caml_pasta_q_bigint)];
  },
  caml_pasta_fp_negate: function(x) {
    return [caml_pasta_p_bigint - x[0]];
  },
  caml_pasta_fq_negate: function(x) {
    return [caml_pasta_q_bigint - x[0]];
  },
  caml_pasta_fp_sub: function(x, y) {
    return [caml_bigint_modulo(x[0] - y[0], caml_pasta_p_bigint)];
  },
  caml_pasta_fq_sub: function(x, y) {
    return [caml_bigint_modulo(x[0] - y[0], caml_pasta_q_bigint)];
  },
  caml_pasta_fp_mul: function(x, y) {
    return [caml_bigint_modulo(x[0] * y[0], caml_pasta_p_bigint)];
  },
  caml_pasta_fq_mul: function(x, y) {
    return [caml_bigint_modulo(x[0] * y[0], caml_pasta_q_bigint)];
  },
  caml_pasta_fp_square: function(x) {
    return plonk_wasm.caml_pasta_fp_mul(x, x);
  },
  caml_pasta_fq_square: function(x) {
    return plonk_wasm.caml_pasta_fq_mul(x, x);
  },
  caml_pasta_fp_is_square: function(x) {
    x = x[0];
    if (x === _0n) return 1;
    var sqrt_1 = caml_finite_field_power(x, (caml_pasta_p_bigint - _1n) / _2n, caml_pasta_p_bigint);
    return Number(sqrt_1 === _1n);
  },
  caml_pasta_fq_is_square: function(x) {
    x = x[0];
    if (x === _0n) return 1;
    var sqrt_1 = caml_finite_field_power(x, (caml_pasta_q_bigint - _1n) / _2n, caml_pasta_q_bigint);
    return Number(sqrt_1 === _1n);
  },
  caml_pasta_fp_sqrt: function(x) {
    return [caml_finite_field_sqrt(x[0], caml_pasta_p_bigint, caml_pasta_pm1_odd_factor, caml_twoadic_root_fp)];
  },
  caml_pasta_fq_sqrt: function(x) {
    return [caml_finite_field_sqrt(x[0], caml_pasta_q_bigint, caml_pasta_qm1_odd_factor, caml_twoadic_root_fq)];
  },
  caml_pasta_fp_inv: function(x) {
    return [caml_finite_field_inverse(x[0], caml_pasta_p_bigint)];
  },
  caml_pasta_fq_inv: function(x) {
    return [caml_finite_field_inverse(x[0], caml_pasta_q_bigint)];
  },
  caml_pasta_fp_div: function(x, y) {
    return [caml_bigint_modulo(x[0] * caml_finite_field_inverse(y[0], caml_pasta_p_bigint), caml_pasta_p_bigint)];
  },
  caml_pasta_fq_div: function(x, y) {
    return [caml_bigint_modulo(x[0] * caml_finite_field_inverse(y[0], caml_pasta_q_bigint), caml_pasta_q_bigint)];
  },
  caml_pasta_fp_equal: function(x, y) {
    return Number(plonk_wasm.caml_pasta_fp_sub(x, y)[0] === _0n);
  },
  caml_pasta_fq_equal: function(x, y) {
    return Number(plonk_wasm.caml_pasta_fq_sub(x, y)[0] === _0n);
  },
  caml_pasta_fp_random: function() {
    return [caml_finite_field_random(caml_pasta_p_bigint)];
  },
  caml_pasta_fq_random: function() {
    return [caml_finite_field_random(caml_pasta_q_bigint)];
  },
  caml_pasta_fp_size_in_bits: function() {
    return 255;
  },
  caml_pasta_fq_size_in_bits: function() {
    return 255;
  },
  caml_pasta_fp_of_int: function(i) {
    return [BigInt_(i)];
  },
  caml_pasta_fq_of_int: function(i) {
    return [BigInt_(i)];
  },
  caml_pasta_fp_of_bigint: function(x) {
    return x;
  },
  caml_pasta_fq_of_bigint: function(x) {
    return x;
  },
  caml_pasta_fp_to_bigint: function(x) {
    return x;
  },
  caml_pasta_fq_to_bigint: function(x) {
    return x;
  },
  caml_pasta_fp_to_string: function(x) {
    return x[0].toString();
  },
  caml_pasta_fq_to_string: function(x) {
    return x[0].toString();
  },
};

// Provides: caml_bindings_debug
var caml_bindings_debug = false;

// TODO fix failing assertions
// Provides: _test_js_backend
// Requires: caml_pasta_p_bigint, caml_pasta_q_bigint, caml_pasta_pm1_odd_factor, caml_pasta_qm1_odd_factor, BigInt_, _1n, _32n, caml_twoadic_root_fp, caml_twoadic_root_fq, caml_finite_field_power, caml_bigint_from_hex_limbs, plonk_wasm, caml_bindings_debug
var _test_js_backend = caml_bindings_debug && (function test() {
  var console = joo_global_object.console;
  console.assert(caml_pasta_pm1_odd_factor * (_1n << _32n) + _1n === caml_pasta_p_bigint);
  console.assert(caml_pasta_qm1_odd_factor * (_1n << _32n) + _1n === caml_pasta_q_bigint);
  console.assert(caml_bigint_from_hex_limbs(["0x992d30ed00000001","0x224698fc094cf91b","0x0","0x4000000000000000"]) === caml_pasta_p_bigint);

  console.assert(plonk_wasm.caml_pasta_fp_is_square([caml_twoadic_root_fp]) === 0);
  console.assert(plonk_wasm.caml_pasta_fq_is_square([caml_twoadic_root_fq]) === 0);

  // console.log(caml_finite_field_power(caml_twoadic_root_fp, (_1n << _32n), caml_pasta_p_bigint));
  // console.log(caml_pasta_p_bigint);
  // console.assert(caml_finite_field_power(caml_twoadic_root_fp, (_1n << _32n), caml_pasta_p_bigint) === _1n);
  // console.assert(caml_finite_field_power(caml_twoadic_root_fp, (_1n << BigInt_(31)), caml_pasta_p_bigint) === -_1n);

  // console.log(caml_finite_field_power(caml_twoadic_root_fq, (_1n << _32n), caml_pasta_q_bigint));
  // console.assert(caml_finite_field_power(caml_twoadic_root_fq, (_1n << _32n), caml_pasta_q_bigint) === _1n);
  // console.assert(caml_finite_field_power(caml_twoadic_root_fq, (_1n << BigInt_(31)), caml_pasta_q_bigint) === -_1n);
})()
