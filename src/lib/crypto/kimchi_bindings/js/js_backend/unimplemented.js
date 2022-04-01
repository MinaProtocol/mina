/* global _0n */

// TODO verification shifts

// Provides: caml_pasta_fp_plonk_verifier_index_shifts
// Requires: caml_plonk_verification_shifts_of_rust, _0n
function caml_pasta_fp_plonk_verifier_index_shifts(_log2_size) {
  var shifts = {s0: [_0n], s1: [_0n], s2: [_0n], s3: [_0n], s4: [_0n], s5: [_0n], s6: [_0n]};
  return caml_plonk_verification_shifts_of_rust(shifts);
}

// Provides: caml_pasta_fq_plonk_verifier_index_shifts
// Requires: caml_plonk_verification_shifts_of_rust, _0n
function caml_pasta_fq_plonk_verifier_index_shifts(_log2_size) {
  var shifts = {s0: [_0n], s1: [_0n], s2: [_0n], s3: [_0n], s4: [_0n], s5: [_0n], s6: [_0n]};
  return caml_plonk_verification_shifts_of_rust(shifts);
}

// Provides: caml_plonk_verification_shifts_of_rust
var caml_plonk_verification_shifts_of_rust = function(x) {
  return [0, x.s0, x.s1, x.s2, x.s3, x.s4, x.s5, x.s6];
};
