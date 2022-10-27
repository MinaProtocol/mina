/* global Uint8Array_, BigInt_, caml_bigint_modulo, caml_bigint_of_bytes, 
   caml_finite_field_inverse, caml_pasta_p_bigint, caml_pasta_q_bigint, 
*/

// Provides: caml_pallas_generator_projective
// Requires: BigInt_
var caml_pallas_generator_projective = {
  x: BigInt_(1),
  y: BigInt_("12418654782883325593414442427049395787963493412651469444558597405572177144507"),
  z: BigInt_(1)
}
// Provides: caml_vesta_generator_projective
// Requires: BigInt_
var caml_vesta_generator_projective = {
  x: BigInt_(1),
  y: BigInt_("11426906929455361843568202299992114520848200991084027513389447476559454104162"),
  z: BigInt_(1)
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

// Provides: caml_group_projective_zero
// Requires: GroupProjective, BigInt_
function caml_group_projective_zero() {
  return new GroupProjective({ x: BigInt_(1), y: BigInt_(1), z: BigInt_(0) });
}

// Provides: caml_group_projective_neg
// Requires: GroupProjective
function caml_group_projective_neg(g, p) {
  return new GroupProjective({ x: g.x, y: p - g.y, z: g.z });
}

// Provides: caml_group_projective_add
// Requires: BigInt_, GroupProjective, caml_bigint_modulo
function caml_group_projective_add(g, h, p) {
  if (g.z === BigInt_(0)) return new GroupProjective(h);
  if (h.z === BigInt_(0)) return new GroupProjective(g);
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
  var I = caml_bigint_modulo((H*H) << BigInt_(2), p);
  // J = H*I
  var J = caml_bigint_modulo(H*I, p);
  // r = 2*(S2-S1)
  var r = BigInt_(2)*(S2 - S1);
  // V = U1*I
  var V = caml_bigint_modulo(U1*I, p);
  // X3 = r^2-J-2*V
  var X3 = caml_bigint_modulo(r*r - J - BigInt_(2)*V, p);
  // Y3 = r*(V-X3)-2*S1*J
  var Y3 = caml_bigint_modulo(r*(V - X3) - BigInt_(2)*S1*J, p);
  // Z3 = ((Z1+Z2)^2-Z1Z1-Z2Z2)*H
  var Z3 = caml_bigint_modulo(((Z1 + Z2)*(Z1 + Z2) - Z1Z1 - Z2Z2)*H, p);
  return new GroupProjective({ x: X3, y: Y3, z: Z3 });
}

// Provides: caml_group_projective_double
// Requires: BigInt_, GroupProjective, caml_bigint_modulo
function caml_group_projective_double(g, p) {
  if (g.z === BigInt_(0)) return new GroupProjective(g);
  var X1 = g.x, Y1 = g.y, Z1 = g.z;
  // http://www.hyperelliptic.org/EFD/g1p/auto-shortw-jacobian-0.html#doubling-dbl-2009-l
  // !!! formula depends on a === 0 in the curve equation y^2 = x^3 + ax + b !!!
  // A = X1^2
  var A = caml_bigint_modulo(X1*X1, p);
  // B = Y1^2
  var B = caml_bigint_modulo(Y1*Y1, p);
  // C = B^2
  var C = caml_bigint_modulo(B*B, p);
  // D = 2*((X1+B)^2-A-C)
  var D = caml_bigint_modulo(BigInt_(2)*((X1 + B)*(X1 + B) - A - C), p);
  // E = 3*A
  var E = BigInt_(3)*A;
  // F = E^2
  var F = caml_bigint_modulo(E*E, p);
  // X3 = F-2*D
  var X3 = caml_bigint_modulo(F - BigInt_(2)*D, p);
  // Y3 = E*(D-X3)-8*C
  var Y3 = caml_bigint_modulo(E*(D - X3) - BigInt_(8)*C, p);
  // Z3 = 2*Y1*Z1
  var Z3 = caml_bigint_modulo(BigInt_(2)*Y1*Z1, p);
  return new GroupProjective({ x: X3, y: Y3, z: Z3 });
}

// Provides: caml_group_projective_sub
// Requires: caml_group_projective_add, caml_group_projective_neg
function caml_group_projective_sub(g, h, p) {
  return caml_group_projective_add(g, caml_group_projective_neg(h, p), p);
}

// Provides: caml_group_projective_scale
// Requires: caml_group_projective_add, caml_group_projective_double, caml_group_projective_zero, BigInt_
function caml_group_projective_scale(g, x, p) {
  var h = caml_group_projective_zero();
  while (x > BigInt_(0)) {
    if (x & BigInt_(1)) h = caml_group_projective_add(h, g, p);
    g = caml_group_projective_double(g, p);
    x >>= BigInt_(1);
  }
  return h;
}

// Provides: caml_group_projective_to_affine
// Requires: caml_finite_field_inverse, caml_bigint_modulo, GroupAffine, BigInt_
function caml_group_projective_to_affine(g, p) {
  var z = g.z;
  if (z === BigInt_(0)) { // infinity
    return new GroupAffine({ x: BigInt_(1), y: BigInt_(1), infinity: true });
  } else if (z === BigInt_(1)) { // already normalized affine form
    return new GroupAffine({ x: g.x, y: g.y, infinity: false });
  } else {
    var zinv = caml_finite_field_inverse(z, p);
    var zinv_squared = caml_bigint_modulo(zinv * zinv, p);
    // x/z^2
    var x = caml_bigint_modulo(g.x * zinv_squared, p);
    // y/z^3
    var y = caml_bigint_modulo(g.y * zinv * zinv_squared, p);
    return new GroupAffine({ x: x, y: y, infinity: false });
  }
}

// Provides: caml_pallas_one
// Requires: GroupProjective, caml_pallas_generator_projective
function caml_pallas_one() {
  return new GroupProjective(caml_pallas_generator_projective);
}
// Provides: caml_vesta_one
// Requires: GroupProjective, caml_vesta_generator_projective
function caml_vesta_one() {
  return new GroupProjective(caml_vesta_generator_projective);
}

// Provides: caml_pallas_add
// Requires: caml_group_projective_add, caml_pasta_p_bigint
function caml_pallas_add(g, h) {
  return caml_group_projective_add(g, h, caml_pasta_p_bigint);
}
// Provides: caml_vesta_add
// Requires: caml_group_projective_add, caml_pasta_q_bigint
function caml_vesta_add(g, h) {
  return caml_group_projective_add(g, h, caml_pasta_q_bigint);
}

// Provides: caml_pallas_negate
// Requires: caml_group_projective_neg, caml_pasta_p_bigint
function caml_pallas_negate(g) {
  return caml_group_projective_neg(g, caml_pasta_p_bigint);
}
// Provides: caml_vesta_negate
// Requires: caml_group_projective_neg, caml_pasta_q_bigint
function caml_vesta_negate(g) {
  return caml_group_projective_neg(g, caml_pasta_q_bigint);
}

// Provides: caml_pallas_sub
// Requires: caml_group_projective_sub, caml_pasta_p_bigint
function caml_pallas_sub(x, y) {
  return caml_group_projective_sub(x, y, caml_pasta_p_bigint);
}
// Provides: caml_vesta_sub
// Requires: caml_group_projective_sub, caml_pasta_q_bigint
function caml_vesta_sub(x, y) {
  return caml_group_projective_sub(x, y, caml_pasta_q_bigint);
}

// Provides: caml_pallas_scale
// Requires: caml_group_projective_scale, caml_pasta_p_bigint
function caml_pallas_scale(g, x) {
  return caml_group_projective_scale(g, x[0], caml_pasta_p_bigint);
}
// Provides: caml_vesta_scale
// Requires: caml_group_projective_scale, caml_pasta_q_bigint
function caml_vesta_scale(g, x) {
  return caml_group_projective_scale(g, x[0], caml_pasta_q_bigint);
}

// Provides: caml_pallas_endo_base
// Requires: caml_bigint_of_bytes, caml_pallas_endo_base_const
function caml_pallas_endo_base() {
  return [caml_bigint_of_bytes(caml_pallas_endo_base_const)];
}
// Provides: caml_vesta_endo_base
// Requires: caml_bigint_of_bytes, caml_vesta_endo_base_const
function caml_vesta_endo_base() {
  return [caml_bigint_of_bytes(caml_vesta_endo_base_const)];
}

// Provides: caml_pallas_endo_scalar
// Requires: caml_bigint_of_bytes, caml_pallas_endo_scalar_const
function caml_pallas_endo_scalar() {
  return [caml_bigint_of_bytes(caml_pallas_endo_scalar_const)];
}
// Provides: caml_vesta_endo_scalar
// Requires: caml_bigint_of_bytes, caml_vesta_endo_scalar_const
function caml_vesta_endo_scalar() {
  return [caml_bigint_of_bytes(caml_vesta_endo_scalar_const)];
}

// Provides: caml_pallas_to_affine
// Requires: caml_group_projective_to_affine, caml_affine_of_js_affine, caml_pasta_p_bigint
function caml_pallas_to_affine(g) {
  var ga = caml_group_projective_to_affine(g, caml_pasta_p_bigint);
  return caml_affine_of_js_affine(ga);
}
// Provides: caml_vesta_to_affine
// Requires: caml_group_projective_to_affine, caml_affine_of_js_affine, caml_pasta_q_bigint
function caml_vesta_to_affine(g) {
  var ga = caml_group_projective_to_affine(g, caml_pasta_q_bigint);
  return caml_affine_of_js_affine(ga);
}

// Provides: caml_pallas_of_affine_coordinates
// Requires: GroupProjective, BigInt_
function caml_pallas_of_affine_coordinates(x, y) {
  return new GroupProjective({ x: x[0], y: y[0], z: BigInt_(1) });
}
// Provides: caml_vesta_of_affine_coordinates
// Requires: GroupProjective, BigInt_
function caml_vesta_of_affine_coordinates(x, y) {
  return new GroupProjective({ x: x[0], y: y[0], z: BigInt_(1) });
}

// Provides: caml_affine_of_js_affine
var caml_affine_of_js_affine = function(g) {
  if (g.infinity) return 0;
  return [0, [0, [g.x], [g.y]]];
};

// TODO check if these really should be hardcoded, otherwise compute them
// Provides: caml_vesta_endo_base_const
// Requires: Uint8Array_
var caml_vesta_endo_base_const = new Uint8Array_([
  79, 14, 170, 80, 224, 210, 169, 42,
175, 51, 192, 71, 125,  70, 237, 15,
  90, 15, 247, 28, 216, 180,  29, 81,
142, 82,  62, 40,  88, 154, 129,  6
]);
// Provides: caml_pallas_endo_base_const
// Requires: Uint8Array_
var caml_pallas_endo_base_const = new Uint8Array_([
  71, 181,   1,   2,  47, 210, 127, 123,
 210, 199, 159, 209,  41,  13,  39,   5,
  80,  78,  85, 168,  35,  42,  85, 211,
 142,  69,  50, 181, 124,  53,  51,  45
]);
// Provides: caml_vesta_endo_scalar_const
// Requires: Uint8Array_
var caml_vesta_endo_scalar_const = new Uint8Array_([
  185,  74, 254, 253, 189,  94, 173, 29,
   73,  49, 173,  55, 210, 139,  31, 29,
  176, 177, 170,  87, 220, 213, 170, 44,
  113, 186, 205,  74, 131, 202, 204, 18
]);
// Provides: caml_pallas_endo_scalar_const
// Requires: Uint8Array_
var caml_pallas_endo_scalar_const = new Uint8Array_([
  177, 241,  85, 175,  64,  24, 157,  97,
   46, 117, 212, 193, 126,  82,  89,  18,
  166, 240,   8, 227,  39,  75, 226, 174,
  113, 173, 193, 215, 167, 101, 126,  57
]);
