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
// Requires: plonk_wasm, tsRustConversion
var caml_fp_srs_commit_evaluations = function (t, domain_size, fps) {
  var res = plonk_wasm.caml_fp_srs_commit_evaluations(
    t,
    domain_size,
    tsRustConversion.fp.vectorToRust(fps)
  );
  return tsRustConversion.fp.polyCommFromRust(res);
};

// Provides: caml_fp_srs_b_poly_commitment
// Requires: plonk_wasm, tsRustConversion
var caml_fp_srs_b_poly_commitment = function (srs, chals) {
  var res = plonk_wasm.caml_fp_srs_b_poly_commitment(
    srs,
    tsRustConversion.fieldsToRustFlat(chals)
  );
  return tsRustConversion.fp.polyCommFromRust(res);
};

// Provides: caml_fp_srs_batch_accumulator_check
// Requires: plonk_wasm, tsRustConversion
var caml_fp_srs_batch_accumulator_check = function (srs, comms, chals) {
  var rust_comms = tsRustConversion.fp.pointsToRust(comms);
  var rust_chals = tsRustConversion.fp.vectorToRust(chals);
  var ok = plonk_wasm.caml_fp_srs_batch_accumulator_check(
    srs,
    rust_comms,
    rust_chals
  );
  return ok;
};

// Provides: caml_fp_srs_batch_accumulator_generate
// Requires: plonk_wasm, tsRustConversion
var caml_fp_srs_batch_accumulator_generate = function (srs, n_comms, chals) {
  var rust_chals = tsRustConversion.fp.vectorToRust(chals);
  var rust_comms = plonk_wasm.caml_fp_srs_batch_accumulator_generate(
    srs,
    n_comms,
    rust_chals
  );
  return tsRustConversion.fp.pointsFromRust(rust_comms);
};

// Provides: caml_fp_srs_h
// Requires: plonk_wasm, tsRustConversion
var caml_fp_srs_h = function (t) {
  return tsRustConversion.fp.pointFromRust(plonk_wasm.caml_fp_srs_h(t));
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
// Requires: plonk_wasm, tsRustConversion
var caml_fq_srs_commit_evaluations = function (t, domain_size, fqs) {
  var res = plonk_wasm.caml_fq_srs_commit_evaluations(
    t,
    domain_size,
    tsRustConversion.fq.vectorToRust(fqs)
  );
  return tsRustConversion.fq.polyCommFromRust(res);
};

// Provides: caml_fq_srs_b_poly_commitment
// Requires: plonk_wasm, tsRustConversion
var caml_fq_srs_b_poly_commitment = function (srs, chals) {
  var res = plonk_wasm.caml_fq_srs_b_poly_commitment(
    srs,
    tsRustConversion.fieldsToRustFlat(chals)
  );
  return tsRustConversion.fq.polyCommFromRust(res);
};

// Provides: caml_fq_srs_batch_accumulator_check
// Requires: plonk_wasm, tsRustConversion
var caml_fq_srs_batch_accumulator_check = function (srs, comms, chals) {
  var rust_comms = tsRustConversion.fq.pointsToRust(comms);
  var rust_chals = tsRustConversion.fq.vectorToRust(chals);
  var ok = plonk_wasm.caml_fq_srs_batch_accumulator_check(
    srs,
    rust_comms,
    rust_chals
  );
  return ok;
};

// Provides: caml_fq_srs_batch_accumulator_generate
// Requires: plonk_wasm, tsRustConversion
var caml_fq_srs_batch_accumulator_generate = function (srs, comms, chals) {
  var rust_chals = tsRustConversion.fq.vectorToRust(chals);
  var rust_comms = plonk_wasm.caml_fq_srs_batch_accumulator_generate(
    srs,
    comms,
    rust_chals
  );
  return tsRustConversion.fq.pointsFromRust(rust_comms);
};

// Provides: caml_fq_srs_h
// Requires: plonk_wasm, tsRustConversion
var caml_fq_srs_h = function (t) {
  return tsRustConversion.fq.pointFromRust(plonk_wasm.caml_fq_srs_h(t));
};

// Provides: caml_fq_srs_add_lagrange_basis
// Requires: tsSrs
var caml_fq_srs_add_lagrange_basis = tsSrs.fq.addLagrangeBasis;
