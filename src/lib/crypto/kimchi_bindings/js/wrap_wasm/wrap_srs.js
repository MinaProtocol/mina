// Provides: wrap_wasm_srs
function wrap_wasm_srs(plonk_wasm,plonk_intf,tsRustConversion){

  plonk_intf.caml_fp_srs_commit_evaluations = function (t, domain_size, fps) {
    var res = plonk_wasm.caml_fp_srs_commit_evaluations(
      t,
      domain_size,
      tsRustConversion.fp.vectorToRust(fps)
    );
    return tsRustConversion.fp.polyCommFromRust(res);
  };

  plonk_intf.caml_fp_srs_b_poly_commitment = function (srs, chals) {
    var res = plonk_wasm.caml_fp_srs_b_poly_commitment(
      srs,
      tsRustConversion.fieldsToRustFlat(chals)
    );
    return tsRustConversion.fp.polyCommFromRust(res);
  };

  plonk_intf.caml_fp_srs_batch_accumulator_check = function (srs, comms, chals) {
    var rust_comms = tsRustConversion.fp.pointsToRust(comms);
    var rust_chals = tsRustConversion.fp.vectorToRust(chals);
    var ok = plonk_wasm.caml_fp_srs_batch_accumulator_check(
      srs,
      rust_comms,
      rust_chals
    );
    return ok;
  };

  plonk_intf.caml_fp_srs_batch_accumulator_generate = function (srs, n_comms, chals) {
    var rust_chals = tsRustConversion.fp.vectorToRust(chals);
    var rust_comms = plonk_wasm.caml_fp_srs_batch_accumulator_generate(
      srs,
      n_comms,
      rust_chals
    );
    return tsRustConversion.fp.pointsFromRust(rust_comms);
  };

  plonk_intf.caml_fp_srs_h = function (t) {
    return tsRustConversion.fp.pointFromRust(plonk_wasm.caml_fp_srs_h(t));
  };

  plonk_intf.caml_fq_srs_commit_evaluations = function (t, domain_size, fqs) {
    var res = plonk_wasm.caml_fq_srs_commit_evaluations(
      t,
      domain_size,
      tsRustConversion.fq.vectorToRust(fqs)
    );
    return tsRustConversion.fq.polyCommFromRust(res);
  };

  plonk_intf.caml_fq_srs_b_poly_commitment = function (srs, chals) {
    var res = plonk_wasm.caml_fq_srs_b_poly_commitment(
      srs,
      tsRustConversion.fieldsToRustFlat(chals)
    );
    return tsRustConversion.fq.polyCommFromRust(res);
  };

  plonk_intf.caml_fq_srs_b_poly_commitment = function (srs, chals) {
    var res = plonk_wasm.caml_fq_srs_b_poly_commitment(
      srs,
      tsRustConversion.fieldsToRustFlat(chals)
    );
    return tsRustConversion.fq.polyCommFromRust(res);
  };

  plonk_intf.caml_fq_srs_batch_accumulator_check = function (srs, comms, chals) {
    var rust_comms = tsRustConversion.fq.pointsToRust(comms);
    var rust_chals = tsRustConversion.fq.vectorToRust(chals);
    var ok = plonk_wasm.caml_fq_srs_batch_accumulator_check(
      srs,
      rust_comms,
      rust_chals
    );
    return ok;
  };

  plonk_intf.caml_fq_srs_batch_accumulator_generate = function (srs, comms, chals) {
    var rust_chals = tsRustConversion.fq.vectorToRust(chals);
    var rust_comms = plonk_wasm.caml_fq_srs_batch_accumulator_generate(
      srs,
      comms,
      rust_chals
    );
    return tsRustConversion.fq.pointsFromRust(rust_comms);
  };

  plonk_intf.caml_fq_srs_h = function (t) {
    return tsRustConversion.fq.pointFromRust(plonk_wasm.caml_fq_srs_h(t));
  };

}
