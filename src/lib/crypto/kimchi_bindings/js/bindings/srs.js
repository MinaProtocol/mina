/* global plonk_intf, caml_jsstring_of_string,
  tsBindings
*/

// Provides: tsSrs
// Requires: tsBindings, plonk_intf
var tsSrs = tsBindings.srs(plonk_intf);

// srs

// Provides: caml_fp_srs_create
// Requires: tsSrs
var caml_fp_srs_create = tsSrs.fp.create;

// Provides: caml_fp_srs_write
// Requires: plonk_intf, caml_jsstring_of_string
var caml_fp_srs_write = function (append, t, path) {
  if (append === 0) {
    append = undefined;
  } else {
    append = append[1];
  }
  return plonk_intf.caml_fp_srs_write(append, t, caml_jsstring_of_string(path));
};

// Provides: caml_fp_srs_read
// Requires: plonk_intf, caml_jsstring_of_string
var caml_fp_srs_read = function (offset, path) {
  if (offset === 0) {
    offset = undefined;
  } else {
    offset = offset[1];
  }
  var res = plonk_intf.caml_fp_srs_read(offset, caml_jsstring_of_string(path));
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
// Requires: plonk_intf
var caml_fp_srs_commit_evaluations = plonk_intf.caml_fp_srs_commit_evaluations;

// Provides: caml_fp_srs_b_poly_commitment
// Requires: plonk_intf
var caml_fp_srs_b_poly_commitment = plonk_intf.caml_fp_srs_b_poly_commitment;

// Provides: caml_fp_srs_batch_accumulator_check
// Requires: plonk_intf
var caml_fp_srs_batch_accumulator_check = plonk_intf.caml_fp_srs_batch_accumulator_check;

// Provides: caml_fp_srs_batch_accumulator_generate
// Requires: plonk_intf
var caml_fp_srs_batch_accumulator_generate = plonk_intf.caml_fp_srs_batch_accumulator_generate;

// Provides: caml_fp_srs_h
// Requires: plonk_intf
var caml_fp_srs_h = plonk_intf.caml_fp_srs_h;

// Provides: caml_fp_srs_add_lagrange_basis
// Requires: tsSrs
var caml_fp_srs_add_lagrange_basis = tsSrs.fp.addLagrangeBasis;

// Provides: caml_fq_srs_create
// Requires: tsSrs
var caml_fq_srs_create = tsSrs.fq.create;

// Provides: caml_fq_srs_write
// Requires: plonk_intf, caml_jsstring_of_string
var caml_fq_srs_write = function (append, t, path) {
  if (append === 0) {
    append = undefined;
  } else {
    append = append[1];
  }
  return plonk_intf.caml_fq_srs_write(append, t, caml_jsstring_of_string(path));
};

// Provides: caml_fq_srs_read
// Requires: plonk_intf, caml_jsstring_of_string
var caml_fq_srs_read = function (offset, path) {
  if (offset === 0) {
    offset = undefined;
  } else {
    offset = offset[1];
  }
  var res = plonk_intf.caml_fq_srs_read(offset, caml_jsstring_of_string(path));
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
// Requires: plonk_intf
var caml_fq_srs_commit_evaluations = plonk_intf.caml_fq_srs_commit_evaluations;

// Provides: caml_fq_srs_b_poly_commitment
// Requires: plonk_intf
var caml_fq_srs_b_poly_commitment = plonk_intf.caml_fq_srs_b_poly_commitment;

// Provides: caml_fq_srs_batch_accumulator_check
// Requires: plonk_intf
var caml_fq_srs_batch_accumulator_check = plonk_intf.caml_fq_srs_batch_accumulator_check;

// Provides: caml_fq_srs_batch_accumulator_generate
// Requires: plonk_intf
var caml_fq_srs_batch_accumulator_generate = plonk_intf.caml_fq_srs_batch_accumulator_generate;

// Provides: caml_fq_srs_h
// Requires: plonk_intf
var caml_fq_srs_h = plonk_intf.caml_fq_srs_h;

// Provides: caml_fq_srs_add_lagrange_basis
// Requires: tsSrs
var caml_fq_srs_add_lagrange_basis = tsSrs.fq.addLagrangeBasis;
