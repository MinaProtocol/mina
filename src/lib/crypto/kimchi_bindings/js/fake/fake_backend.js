// Provides: caml_bindings_debug
var caml_bindings_debug = false;

// Provides: BigInt_
var BigInt_ = joo_global_object.BigInt;
// Provides: Uint8Array
var Uint8Array = joo_global_object.Uint8Array;
// Provides: _0n
var _0n = joo_global_object.BigInt(0);
// Provides: _1n
var _1n = joo_global_object.BigInt(1);
// Provides: _2n
var _2n = joo_global_object.BigInt(2);
// Provides: _32n
var _32n = joo_global_object.BigInt(32);

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

// Provides: caml_pallas_generator_projective
// Requires: BigInt_, caml_pasta_p_bigint
var caml_pallas_generator_projective = {
  x: BigInt_(1),
  y: BigInt_("12418654782883325593414442427049395787963493412651469444558597405572177144507"),
  z: BigInt_(1)
}
// Provides: caml_vesta_generator_projective
// Requires: BigInt_, caml_pasta_q_bigint
var caml_vesta_generator_projective = {
  x: BigInt_(1),
  y: BigInt_("11426906929455361843568202299992114520848200991084027513389447476559454104162"),
  z: BigInt_(1)
}

// TODO check if these really should be hardcoded, otherwise compute them
// Provides: caml_vesta_endo_base_const
var caml_vesta_endo_base_const = new Uint8Array([
  79, 14, 170, 80, 224, 210, 169, 42,
175, 51, 192, 71, 125,  70, 237, 15,
  90, 15, 247, 28, 216, 180,  29, 81,
142, 82,  62, 40,  88, 154, 129,  6
]);
// Provides: caml_pallas_endo_base_const
var caml_pallas_endo_base_const = new Uint8Array([
  71, 181,   1,   2,  47, 210, 127, 123,
 210, 199, 159, 209,  41,  13,  39,   5,
  80,  78,  85, 168,  35,  42,  85, 211,
 142,  69,  50, 181, 124,  53,  51,  45
]);
// Provides: caml_vesta_endo_scalar_const
var caml_vesta_endo_scalar_const = new Uint8Array([
  185,  74, 254, 253, 189,  94, 173, 29,
   73,  49, 173,  55, 210, 139,  31, 29,
  176, 177, 170,  87, 220, 213, 170, 44,
  113, 186, 205,  74, 131, 202, 204, 18
]);
// Provides: caml_pallas_endo_scalar_const
var caml_pallas_endo_scalar_const = new Uint8Array([
  177, 241,  85, 175,  64,  24, 157,  97,
   46, 117, 212, 193, 126,  82,  89,  18,
  166, 240,   8, 227,  39,  75, 226, 174,
  113, 173, 193, 215, 167, 101, 126,  57
]);

// Provides: bigIntToBytes
// Requires: BigInt_, Uint8Array
function bigIntToBytes(x, length) {
  var bytes = [];
  for (; x > 0; x >>= BigInt_(8)) {
    bytes.push(Number(x & BigInt_(0xff)));
  }
  var array = new Uint8Array(bytes);
  if (length === undefined) return array;
  if (array.length > length)
    throw Error("bigint doesn't fit into" + length + " bytes.");
  var sizedArray = new Uint8Array(length);
  sizedArray.set(array);
  return sizedArray;
}
// Provides: bytesToBigInt
// Requires: BigInt_, _0n
function bytesToBigInt(bytes) {
  var x = _0n;
  var bitPosition = _0n;
  for (var i = 0; i < bytes.length; i++) {
    x += BigInt_(bytes[i]) << bitPosition;
    bitPosition += BigInt_(8);
  }
  return x;
}
// Provides: caml_bigint_modulo
function caml_bigint_modulo(x, p) {
  x = x % p;
  if (x < 0) return x + p;
  return x;
}

// projective repr: { x: bigint, y: bigint, z: bigint }
// Provides: GroupProjective
var GroupProjective = (function() {
  var GroupProjective = function(obj) {
    this.x = obj.x;
    this.y = obj.y;
    this.z = obj.z;
    // this.ptr = obj;
  };
  GroupProjective.prototype.free = function() {};
  return GroupProjective;
})();

// affine repr: { x: bigint, y: bigint, infinity: boolean }
// Provides: GroupAffine
var GroupAffine = (function() {
  var GroupAffine = function(obj) {
    this.x = obj.x;
    this.y = obj.y;
    this.infinity = obj.infinity;
    // this.ptr = obj;
  };
  GroupAffine.prototype.free = function() {};
  return GroupAffine;
})();

// Provides: caml_group_projective_neg
// Requires: GroupProjective
function caml_group_projective_neg(g, p) {
  return new GroupProjective({ x: g.x, y: p - g.y, z: g.z });
}

// Provides: caml_group_projective_add
// Requires: BigInt_, GroupProjective, caml_bigint_modulo, _2n
function caml_group_projective_add(g, h, p) {
  var X1 = g.x, Y1 = g.y, Z1 = g.z, X2 = h.x, Y2 = h.y, Z2 = h.z;
  // http://www.hyperelliptic.org/EFD/g1p/auto-shortw-jacobian-0.html#addition-add-2007-bl
  // Z1Z1 = Z1^2
  var Z1Z1 = caml_bigint_modulo(Z1*Z1, p);
  // Z2Z2 = Z2^2
  var Z2Z2 = caml_bigint_modulo(Z2*Z2, p);
  // U1 = X1*Z2Z2
  var U1 = caml_bigint_modulo(X1*Z2Z2, p);
  // U2 = X2*Z1Z1
  var U2 = caml_bigint_modulo(X2*Z1Z1, p);
  // S1 = Y1*Z2*Z2Z2
  var S1 = caml_bigint_modulo(Y1*Z2*Z2Z2, p);
  // S2 = Y2*Z1*Z1Z1
  var S2 = caml_bigint_modulo(Y2*Z1*Z1Z1, p);
  // H = U2-U1
  var H = U2 - U1;
  // I = (2*H)^2
  var I = caml_bigint_modulo(BigInt_(4)*H*H, p);
  // J = H*I
  var J = caml_bigint_modulo(H*I, p);
  // r = 2*(S2-S1)
  var r = _2n*(S2 - S1);
  // V = U1*I
  var V = caml_bigint_modulo(U1*I, p);
  // X3 = r^2-J-2*V
  var X3 = caml_bigint_modulo(r*r - J - _2n*V, p);
  // Y3 = r*(V-X3)-2*S1*J
  var Y3 = caml_bigint_modulo(r*(V - X3) - _2n*S1*J, p);
  // Z3 = ((Z1+Z2)^2-Z1Z1-Z2Z2)*H
  var Z3 = caml_bigint_modulo((Z1 + Z2)*(Z1 + Z2) - Z1Z1 - Z2Z2, p);
  return new GroupProjective({ x: X3, y: Y3, z: Z3 });
}

// Provides: caml_group_projective_sub
// Requires: caml_group_projective_add, caml_group_projective_neg
function caml_group_projective_sub(g, h, p) {
  return caml_group_projective_add(g, caml_group_projective_neg(h, p), p);
}


//   if p.is_zero() { // z == 0
//     GroupAffine::zero()
// } else if p.z.is_one() {
//     // If Z is one, the point is already normalized.
//     GroupAffine::new(p.x, p.y, false)
// } else {
//     // Z is nonzero, so it must have an inverse in a field.
//     let zinv = p.z.inverse().unwrap();
//     let zinv_squared = zinv.square();

//     // X/Z^2
//     let x = p.x * &zinv_squared;

//     // Y/Z^3
//     let y = p.y * &(zinv_squared * &zinv);

//     GroupAffine::new(x, y, false)
// }

// Provides: caml_group_projective_to_affine
// Requires: caml_finite_field_inverse, caml_bigint_modulo, GroupAffine
function caml_group_projective_to_affine(g, p) {
  var z = g.z;
  if (z === _0n) { // infinity
    return new GroupAffine({ x: _1n, y: _1n, infinity: true });
  } else if (z === _1n) { // already normalized affine form
    return new GroupAffine({ x: g.x, y: g.y, infinity: false });
  } else {
    var zinv = caml_finite_field_inverse(z, p);
    var zinv_squared = caml_bigint_modulo(zinv * zinv, p);
    // x/z^2
    var x = caml_bigint_modulo(g.x * zinv_squared, p);
    // y/z^3
    var y = caml_bigint_modulo(g.x * zinv * zinv_squared, p);
    return new GroupAffine({ x: x, y: y, infinity: false });
  }
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
  if (a === _0n) throw Error("cannot invert 0");
  a = caml_bigint_modulo(a, p);
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
    if (t === _1n) return R;
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

var i = 0;

// Provides: plonk_wasm
// Requires: bigIntToBytes, bytesToBigInt, caml_bigint_modulo, caml_pasta_p_bigint, caml_pasta_q_bigint, BigInt_, Uint8Array, GroupProjective, caml_pallas_generator_projective, caml_vesta_generator_projective, caml_group_projective_sub, _0n, _1n, _2n, caml_finite_field_inverse, caml_finite_field_power, caml_finite_field_sqrt, caml_pallas_endo_base_const, caml_pallas_endo_scalar_const, caml_pasta_pm1_odd_factor, caml_pasta_qm1_odd_factor, caml_twoadic_root_fp, caml_twoadic_root_fq, caml_vesta_endo_base_const, caml_vesta_endo_scalar_const, caml_bindings_debug
var plonk_wasm = new Proxy({
  caml_bigint_256_num_limbs: function() {
    return 4;
  },
  caml_bigint_256_bytes_per_limb: function() {
    return 8;
  },
  caml_bigint_256_of_bytes: function(arr) {
    return bytesToBigInt(arr);
  },
  caml_bigint_256_of_decimal_string: function(s) {
    return BigInt_(s);
  },
  caml_bigint_256_to_string: function(b) {
    return b.toString();
  },
  caml_bigint_256_to_bytes: function(b) {
    return bigIntToBytes(b, 32);
  },
  caml_bigint_256_test_bit: function(arr, i) {
    return Number(!!(arr & (BigInt_(1) << BigInt_(i))))
  },
  caml_bigint_256_compare: function(x, y) {
    if (x < y) return -1;
    if (x === y) return 0;
    return 1;
  },
  caml_pasta_fp_size: function() {
    return caml_pasta_p_bigint;
  },
  caml_pasta_fq_size: function() {
    return caml_pasta_q_bigint;
  },
  caml_pasta_fp_add: function(x, y) {
    return caml_bigint_modulo(x + y, caml_pasta_p_bigint);
  },
  caml_pasta_fq_add: function(x, y) {
    return caml_bigint_modulo(x + y, caml_pasta_q_bigint);
  },
  caml_pasta_fp_negate: function(x) {
    return caml_pasta_p_bigint - x;
  },
  caml_pasta_fq_negate: function(x) {
    return caml_pasta_q_bigint - x;
  },
  caml_pasta_fp_sub: function(x, y) {
    return caml_bigint_modulo(x - y, caml_pasta_p_bigint);
  },
  caml_pasta_fq_sub: function(x, y) {
    return caml_bigint_modulo(x - y, caml_pasta_q_bigint);
  },
  caml_pasta_fp_mul: function(x, y) {
    return caml_bigint_modulo(x * y, caml_pasta_p_bigint);
  },
  caml_pasta_fq_mul: function(x, y) {
    return caml_bigint_modulo(x * y, caml_pasta_q_bigint);
  },
  caml_pasta_fp_square: function(x) {
    return plonk_wasm.caml_pasta_fp_mul(x, x);
  },
  caml_pasta_fq_square: function(x) {
    return plonk_wasm.caml_pasta_fq_mul(x, x);
  },
  caml_pasta_fp_is_square: function(x) {
    if (x === _0n) return 1;
    var sqrt_1 = caml_finite_field_power(x, (caml_pasta_p_bigint - _1n) / _2n, caml_pasta_p_bigint);
    return Number(sqrt_1 === _1n);
  },
  caml_pasta_fq_is_square: function(x) {
    if (x === _0n) return 1;
    var sqrt_1 = caml_finite_field_power(x, (caml_pasta_q_bigint - _1n) / _2n, caml_pasta_q_bigint);
    return Number(sqrt_1 === _1n);
  },
  caml_pasta_fp_sqrt: function(x) {
    return caml_finite_field_sqrt(x, caml_pasta_p_bigint, caml_pasta_pm1_odd_factor, caml_twoadic_root_fp)
  },
  caml_pasta_fq_sqrt: function(x) {
    return caml_finite_field_sqrt(x, caml_pasta_q_bigint, caml_pasta_qm1_odd_factor, caml_twoadic_root_fq)
  },
  caml_pasta_fp_inv: function(x) {
    return caml_finite_field_inverse(x, caml_pasta_p_bigint);
  },
  caml_pasta_fq_inv: function(x) {
    return caml_finite_field_inverse(x, caml_pasta_q_bigint);
  },
  caml_pasta_fp_div: function(x, y) {
    return caml_bigint_modulo(x * caml_finite_field_inverse(y, caml_pasta_p_bigint), caml_pasta_p_bigint);
  },
  caml_pasta_fq_div: function(x, y) {
    return caml_bigint_modulo(x * caml_finite_field_inverse(y, caml_pasta_q_bigint), caml_pasta_q_bigint);
  },
  caml_pasta_fp_equal: function(x, y) {
    return Number(plonk_wasm.caml_pasta_fp_sub(x, y) === BigInt_(0));
  },
  caml_pasta_fq_equal: function(x, y) {
    return Number(plonk_wasm.caml_pasta_fq_sub(x, y) === BigInt_(0));
  },
  caml_pasta_fp_size_in_bits: function() {
    return 255;
  },
  caml_pasta_fq_size_in_bits: function() {
    return 255;
  },
  caml_pasta_fp_of_int: function(i) {
    return BigInt_(i);
  },
  caml_pasta_fq_of_int: function(i) {
    return BigInt_(i);
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
  caml_vesta_one: function() {
    return new GroupProjective(caml_vesta_generator_projective);
  },
  caml_pallas_one: function() {
    return new GroupProjective(caml_pallas_generator_projective);
  },
  caml_vesta_sub: function(x, y) {
    return caml_group_projective_sub(x, y, caml_pasta_q_bigint);
  },
  caml_pallas_sub: function(x, y) {
    return caml_group_projective_sub(x, y, caml_pasta_p_bigint);
  },
  caml_vesta_endo_base: function() {
    return bytesToBigInt(caml_vesta_endo_base_const);
  },
  caml_pallas_endo_base: function() {
    return bytesToBigInt(caml_pallas_endo_base_const);
  },
  caml_vesta_endo_scalar: function() {
    return bytesToBigInt(caml_vesta_endo_scalar_const);
  },
  caml_pallas_endo_scalar: function() {
    return bytesToBigInt(caml_pallas_endo_scalar_const);
  },
  caml_pallas_to_affine: function(g) {
    return caml_group_projective_to_affine(g, caml_pasta_p_bigint);
  },
  caml_vesta_to_affine: function(g) {
    return caml_group_projective_to_affine(g, caml_pasta_q_bigint);
  },
  // TODO
  caml_pasta_fp_plonk_verifier_index_shifts: function() {
    return {free: function(){}, s0: _0n, s1: _0n, s2: _0n, s3: _0n, s4: _0n, s5: _0n, s6: _0n};
  },
  caml_pasta_fq_plonk_verifier_index_shifts: function() {
    return {free: function(){}, s0: _0n, s1: _0n, s2: _0n, s3: _0n, s4: _0n, s5: _0n, s6: _0n};
  },
  caml_pasta_fp_domain_generator: function() {
    return _1n;
  },
  caml_pasta_fq_domain_generator: function() {
    return _1n;
  },
  caml_pasta_fp_poseidon_block_cipher: function(x) {
    return x;
  },
  caml_pasta_fq_poseidon_block_cipher: function(x) {
    return x;
  }
}, {
  get: function(target, prop, receiver) {
    var fun = Reflect.get(target, prop, receiver);
    if (caml_bindings_debug && typeof fun === "function") {
      return function() {
        if (caml_bindings_debug) console.log('call', i++, prop, Array.from(arguments));
        return fun.apply(null, arguments);
      }
    } else {
      if (caml_bindings_debug) console.log('access', i++, prop);
      return fun;
    }
  }
});

// Provides: startWorkers
function startWorkers() {}

// TODO fix failing assertions
// Provides: _
// Requires: caml_pasta_p_bigint, caml_pasta_q_bigint, caml_pasta_pm1_odd_factor, caml_pasta_qm1_odd_factor, BigInt_, _1n, _32n, caml_twoadic_root_fp, caml_twoadic_root_fq, caml_finite_field_power, caml_bigint_from_hex_limbs
var _ = (function test() {
  console.assert(caml_pasta_pm1_odd_factor * (_1n << _32n) + _1n === caml_pasta_p_bigint);
  console.assert(caml_pasta_qm1_odd_factor * (_1n << _32n) + _1n === caml_pasta_q_bigint);
  console.assert(caml_bigint_from_hex_limbs(["0x992d30ed00000001","0x224698fc094cf91b","0x0","0x4000000000000000"]) === caml_pasta_p_bigint);

  console.log(caml_finite_field_power(caml_twoadic_root_fp, (_1n << _32n), caml_pasta_p_bigint));
  console.log(caml_pasta_p_bigint);
  console.assert(caml_finite_field_power(caml_twoadic_root_fp, (_1n << _32n), caml_pasta_p_bigint) === _1n);
  console.assert(caml_finite_field_power(caml_twoadic_root_fp, (_1n << BigInt_(31)), caml_pasta_p_bigint) === -_1n);

  console.log(caml_finite_field_power(caml_twoadic_root_fq, (_1n << _32n), caml_pasta_q_bigint));
  console.assert(caml_finite_field_power(caml_twoadic_root_fq, (_1n << _32n), caml_pasta_q_bigint) === _1n);
  console.assert(caml_finite_field_power(caml_twoadic_root_fq, (_1n << BigInt_(31)), caml_pasta_q_bigint) === -_1n);
})()
