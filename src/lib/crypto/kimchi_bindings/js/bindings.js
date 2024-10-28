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

// verifier index

// Provides: caml_opt_of_rust
var caml_opt_of_rust = function (value, value_of_rust) {
  if (value === undefined) {
    return 0;
  } else {
    return [0, value_of_rust(value)];
  }
};

// Provides: caml_opt_to_rust
var caml_opt_to_rust = function (caml_optional_value, to_rust) {
  // to_rust expects the parameters of the variant. A `Some vx` is represented
  // as [0, vx]
  if (caml_optional_value === 0) {
    return undefined;
  } else {
    return to_rust(caml_optional_value[1]);
  }
};

// Provides: caml_pasta_fp_plonk_verifier_index_create
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fp_plonk_verifier_index_create = function (x) {
  var vk = plonk_wasm.caml_pasta_fp_plonk_verifier_index_create(x);
  return tsRustConversion.fp.verifierIndexFromRust(vk);
};

// Provides: caml_pasta_fp_plonk_verifier_index_read
// Requires: plonk_wasm, caml_jsstring_of_string, tsRustConversion
var caml_pasta_fp_plonk_verifier_index_read = function (offset, urs, path) {
  if (offset === 0) {
    offset = undefined;
  } else {
    offset = offset[1];
  }
  return tsRustConversion.fp.verifierIndexFromRust(
    plonk_wasm.caml_pasta_fp_plonk_verifier_index_read(
      offset,
      urs,
      caml_jsstring_of_string(path)
    )
  );
};

// Provides: caml_pasta_fp_plonk_verifier_index_write
// Requires: plonk_wasm, caml_jsstring_of_string, tsRustConversion
var caml_pasta_fp_plonk_verifier_index_write = function (append, t, path) {
  if (append === 0) {
    append = undefined;
  } else {
    append = append[1];
  }
  return plonk_wasm.caml_pasta_fp_plonk_verifier_index_write(
    append,
    tsRustConversion.fp.verifierIndexToRust(t),
    caml_jsstring_of_string(path)
  );
};

// Provides: caml_pasta_fp_plonk_verifier_index_shifts
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fp_plonk_verifier_index_shifts = function (log2_size) {
  return tsRustConversion.fp.shiftsFromRust(
    plonk_wasm.caml_pasta_fp_plonk_verifier_index_shifts(log2_size)
  );
};

// Provides: caml_pasta_fp_plonk_verifier_index_dummy
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fp_plonk_verifier_index_dummy = function () {
  var res = plonk_wasm.caml_pasta_fp_plonk_verifier_index_dummy();
  return tsRustConversion.fp.verifierIndexFromRust(res);
};

// Provides: caml_pasta_fp_plonk_verifier_index_deep_copy
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fp_plonk_verifier_index_deep_copy = function (x) {
  return tsRustConversion.fp.verifierIndexFromRust(
    plonk_wasm.caml_pasta_fp_plonk_verifier_index_deep_copy(
      tsRustConversion.fp.verifierIndexToRust(x)
    )
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_create
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fq_plonk_verifier_index_create = function (x) {
  return tsRustConversion.fq.verifierIndexFromRust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_create(x)
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_read
// Requires: plonk_wasm, caml_jsstring_of_string, tsRustConversion
var caml_pasta_fq_plonk_verifier_index_read = function (offset, urs, path) {
  if (offset === 0) {
    offset = undefined;
  } else {
    offset = offset[1];
  }
  return tsRustConversion.fq.verifierIndexFromRust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_read(
      offset,
      urs,
      caml_jsstring_of_string(path)
    )
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_write
// Requires: plonk_wasm, caml_jsstring_of_string, tsRustConversion
var caml_pasta_fq_plonk_verifier_index_write = function (append, t, path) {
  if (append === 0) {
    append = undefined;
  } else {
    append = append[1];
  }
  return plonk_wasm.caml_pasta_fq_plonk_verifier_index_write(
    append,
    tsRustConversion.fq.verifierIndexToRust(t),
    caml_jsstring_of_string(path)
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_shifts
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fq_plonk_verifier_index_shifts = function (log2_size) {
  return tsRustConversion.fq.shiftsFromRust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_shifts(log2_size)
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_dummy
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fq_plonk_verifier_index_dummy = function () {
  return tsRustConversion.fq.verifierIndexFromRust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_dummy()
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_deep_copy
// Requires: plonk_wasm, tsRustConversion, tsRustConversion
var caml_pasta_fq_plonk_verifier_index_deep_copy = function (x) {
  return tsRustConversion.fq.verifierIndexFromRust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_deep_copy(
      tsRustConversion.fq.verifierIndexToRust(x)
    )
  );
};
