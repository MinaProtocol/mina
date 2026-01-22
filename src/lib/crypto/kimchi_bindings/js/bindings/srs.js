/* global plonk_wasm, caml_jsstring_of_string, 
  tsBindings, tsRustConversion
*/

// Provides: tsSrs
// Requires: tsBindings, plonk_wasm
var tsSrs = tsBindings.srs(plonk_wasm);

// srs

// Provides: caml_fp_srs_create
// Requires: tsSrs
var caml_fp_srs_create = function (log_size) {
    return tsSrs.fp.create(log_size);
}

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
        var points = plonk_wasm.caml_fp_srs_get(res);
        if (points == null || points.length <= 1) return 0; // None
        return [0, res]; // Some(res)
    } else {
        return 0; // None
    }
};

// Provides: caml_fp_srs_lagrange_commitments_whole_domain
// Requires: tsSrs
var caml_fp_srs_lagrange_commitments_whole_domain = function (srs, domain_size) {
    return tsSrs.fp.lagrangeCommitmentsWholeDomain(srs, domain_size);
}

// Provides: caml_fq_srs_lagrange_commitments_whole_domain
// Requires: tsSrs
var caml_fq_srs_lagrange_commitments_whole_domain = function (srs, domain_size) {
    return tsSrs.fq.lagrangeCommitmentsWholeDomain(srs, domain_size);
}

// Provides: caml_fp_srs_lagrange_commitment
// Requires: tsSrs
var caml_fp_srs_lagrange_commitment = tsSrs.fp.lagrangeCommitment;

// Provides: caml_fp_srs_from_bytes_external
// Requires: plonk_wasm
var caml_fp_srs_from_bytes_external = function (bytes) {
    if (plonk_wasm.native == true) {
        return plonk_wasm.caml_fp_srs_from_bytes_external(bytes);
    }
    return plonk_wasm.WasmFpSrs.deserialize(bytes);
};

// Provides: caml_fp_srs_maybe_lagrange_commitment
// Requires: plonk_wasm, tsRustConversion
var caml_fp_srs_maybe_lagrange_commitment = function (srs, domain_size, i) {
    var result = plonk_wasm.caml_fp_srs_maybe_lagrange_commitment(srs, domain_size, i);
    if (result == null) return 0; // None
    var polyComm = tsRustConversion.fp.polyCommFromRust(result);
    if (polyComm == undefined) return 0; // None
    return [0, polyComm]; // Some(...)
};

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
        tsRustConversion.fp.vectorToRust(chals)
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
var caml_fp_srs_add_lagrange_basis = function (srs, domain_size) {
    return tsSrs.fp.addLagrangeBasis(srs, domain_size);
};

// Provides: caml_fq_srs_create
// Requires: tsSrs
var caml_fq_srs_create = function (log_size) {
    return tsSrs.fq.create(log_size);
}

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
        var points = plonk_wasm.caml_fq_srs_get(res);
        if (points == null || points.length <= 1) return 0; // None
        return [0, res]; // Some(res)
    } else {
        return 0; // None
    }
};

// Provides: caml_fq_srs_lagrange_commitment
// Requires: tsSrs
var caml_fq_srs_lagrange_commitment = tsSrs.fq.lagrangeCommitment;


// Provides: caml_fq_srs_maybe_lagrange_commitment
// Requires: plonk_wasm, tsRustConversion
var caml_fq_srs_maybe_lagrange_commitment = function (srs, domain_size, i) {
    var result = plonk_wasm.caml_fq_srs_maybe_lagrange_commitment(srs, domain_size, i);
    if (result == null) return 0; // None
    var polyComm = tsRustConversion.fq.polyCommFromRust(result);
    if (polyComm == undefined) return 0; // None
    return [0, polyComm]; // Some(...)
};

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
        tsRustConversion.fq.vectorToRust(chals)
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
var caml_fq_srs_add_lagrange_basis = function (srs, domain_size) {
    return tsSrs.fq.addLagrangeBasis(srs, domain_size);
};
