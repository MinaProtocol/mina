/* global plonk_wasm, caml_jsstring_of_string, 
  tsBindings, tsRustConversion
*/

// Provides: tsSrs
// Requires: tsBindings, plonk_wasm
var tsSrs = tsBindings.srs(plonk_wasm);

// srs

// Provides: caml_fp_srs_create
// Requires: tsSrs
var caml_fp_srs_create = tsSrs.fp.create;

// Provides: caml_fp_srs_write
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_fp_srs_write = function (append, t, path) {
  console.log("native caml_fp_srs_write");
  if (append === 0) {
    append = undefined;
  } else {
    append = append[1];
  }
  return plonk_wasm.caml_fp_srs_write(append, t, caml_jsstring_of_string(path));
};

// Provides: caml_fp_srs_read
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_fp_srs_read = function (offset, path) {
  console.log("native caml_fp_srs_read");
  if (offset === 0) {
    offset = undefined;
  } else {
    offset = offset[1];
  }
  var res = plonk_wasm.caml_fp_srs_read(offset, caml_jsstring_of_string(path));
  if (res) {
    return [0, res]; // Some(res)
  } else {
    return 0; // None
  }
};

// Provides: caml_fp_srs_lagrange_commitments_whole_domain
// Requires: tsSrs
var caml_fp_srs_lagrange_commitments_whole_domain =
  tsSrs.fp.lagrangeCommitmentsWholeDomain;

// Provides: caml_fq_srs_lagrange_commitments_whole_domain
// Requires: tsSrs
var caml_fq_srs_lagrange_commitments_whole_domain =
  tsSrs.fq.lagrangeCommitmentsWholeDomain;

// Provides: caml_fp_srs_lagrange_commitment
// Requires: tsSrs
var caml_fp_srs_lagrange_commitment = tsSrs.fp.lagrangeCommitment;

// Provides: caml_fp_srs_commit_evaluations
// Requires: plonk_wasm, tsRustConversionNative
var caml_fp_srs_commit_evaluations = function (t, domain_size, fps) {
  console.log("native caml_fp_srs_commit_evaluations");
  var res = plonk_wasm.caml_fp_srs_commit_evaluations(
    t,
    domain_size,
    tsRustConversionNative.fp.vectorToRust(fps)
  );
  return tsRustConversionNative.fp.polyCommFromRust(res);
};

// Provides: caml_fp_srs_b_poly_commitment
// Requires: plonk_wasm, tsRustConversionNative
var caml_fp_srs_b_poly_commitment = function (srs, chals) {
  console.log("native caml_fp_srs_b_poly_commitment");
  var res = plonk_wasm.caml_fp_srs_b_poly_commitment(
    srs,
    tsRustConversionNative.fp.vectorToRust(chals)
  );
  return tsRustConversionNative.fp.polyCommFromRust(res);
};

// Provides: caml_fp_srs_batch_accumulator_check
// Requires: plonk_wasm, tsRustConversionNative
var caml_fp_srs_batch_accumulator_check = function (srs, comms, chals) {
  console.log("native caml_fp_srs_batch_accumulator_check");
  var rust_comms = tsRustConversionNative.fp.pointsToRust(comms);
  var rust_chals = tsRustConversionNative.fp.vectorToRust(chals);
  var ok = plonk_wasm.caml_fp_srs_batch_accumulator_check(
    srs,
    rust_comms,
    rust_chals
  );
  return ok;
};

// Provides: caml_fp_srs_batch_accumulator_generate
// Requires: plonk_wasm, tsRustConversionNative
var caml_fp_srs_batch_accumulator_generate = function (srs, n_comms, chals) {
  console.log("native caml_fp_srs_batch_accumulator_generate");
  var rust_chals = tsRustConversionNative.fp.vectorToRust(chals);
  var rust_comms = plonk_wasm.caml_fp_srs_batch_accumulator_generate(
    srs,
    n_comms,
    rust_chals
  );
  return tsRustConversionNative.fp.pointsFromRust(rust_comms);
};

// Provides: caml_fp_srs_h
// Requires: plonk_wasm, tsRustConversionNative
var caml_fp_srs_h = function (t) {
  console.log("native caml_fp_srs_h");
  return tsRustConversionNative.fp.pointFromRust(plonk_wasm.caml_fp_srs_h(t));
};

// Provides: caml_fp_srs_add_lagrange_basis
// Requires: tsSrs
var caml_fp_srs_add_lagrange_basis = tsSrs.fp.addLagrangeBasis;

// Provides: caml_fq_srs_create
// Requires: tsSrs
var caml_fq_srs_create = tsSrs.fq.create;

// Provides: caml_fq_srs_write
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_fq_srs_write = function (append, t, path) {
  console.log("native caml_fq_srs_write");
  if (append === 0) {
    append = undefined;
  } else {
    append = append[1];
  }
  return plonk_wasm.caml_fq_srs_write(append, t, caml_jsstring_of_string(path));
};

// Provides: caml_fq_srs_read
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_fq_srs_read = function (offset, path) {
  console.log("native caml_fq_srs_read");
  if (offset === 0) {
    offset = undefined;
  } else {
    offset = offset[1];
  }
  var res = plonk_wasm.caml_fq_srs_read(offset, caml_jsstring_of_string(path));
  if (res) {
    return [0, res]; // Some(res)
  } else {
    return 0; // None
  }
};

// Provides: caml_fq_srs_lagrange_commitment
// Requires: tsSrs
var caml_fq_srs_lagrange_commitment = tsSrs.fq.lagrangeCommitment;

// Provides: caml_fq_srs_commit_evaluations
// Requires: plonk_wasm, tsRustConversionNative
var caml_fq_srs_commit_evaluations = function (t, domain_size, fqs) {
  console.log("native caml_fq_srs_commit_evaluations");
  var res = plonk_wasm.caml_fq_srs_commit_evaluations(
    t,
    domain_size,
    tsRustConversionNative.fq.vectorToRust(fqs)
  );
  return tsRustConversionNative.fq.polyCommFromRust(res);
};

// Provides: caml_fq_srs_b_poly_commitment
// Requires: plonk_wasm, tsRustConversionNative
var caml_fq_srs_b_poly_commitment = function (srs, chals) {
  console.log("native caml_fq_srs_b_poly_commitment");
  console.log("srs", srs);
  console.log("chals", chals);
  console.log("conv", tsRustConversionNative.fq.vectorToRust(chals))
  var res = plonk_wasm.caml_fq_srs_b_poly_commitment(
    srs,
    tsRustConversionNative.fq.vectorToRust(chals)
  );
  console.log("res", res);
  return tsRustConversionNative.fq.polyCommFromRust(res);
};

// Provides: caml_fq_srs_batch_accumulator_check
// Requires: plonk_wasm, tsRustConversion
var caml_fq_srs_batch_accumulator_check = function (srs, comms, chals) {
  console.log("native caml_fq_srs_batch_accumulator_check");
  var rust_comms = tsRustConversionNative.fq.pointsToRust(comms);
  var rust_chals = tsRustConversionNative.fq.vectorToRust(chals);
  var ok = plonk_wasm.caml_fq_srs_batch_accumulator_check(
    srs,
    rust_comms,
    rust_chals
  );
  return ok;
};

// Provides: caml_fq_srs_batch_accumulator_generate
// Requires: plonk_wasm, tsRustConversionNative
var caml_fq_srs_batch_accumulator_generate = function (srs, comms, chals) {
  console.log("native caml_fq_srs_batch_accumulator_generate");
  var rust_chals = tsRustConversionNative.fq.vectorToRust(chals);
  var rust_comms = plonk_wasm.caml_fq_srs_batch_accumulator_generate(
    srs,
    comms,
    rust_chals
  );
  return tsRustConversionNative.fq.pointsFromRust(rust_comms);
};

// Provides: caml_fq_srs_h
// Requires: plonk_wasm, tsRustConversionNative
var caml_fq_srs_h = function (t) {
  console.log("native caml_fq_srs_h");
  return tsRustConversionNative.fq.pointFromRust(plonk_wasm.caml_fq_srs_h(t));
};

// Provides: caml_fq_srs_add_lagrange_basis
// Requires: tsSrs
var caml_fq_srs_add_lagrange_basis = tsSrs.fq.addLagrangeBasis;
