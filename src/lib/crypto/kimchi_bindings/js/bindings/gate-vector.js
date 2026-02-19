/* global kimchi_ffi, caml_string_of_jsstring */
/* eslint-disable no-unused-vars */
/* global kimchi_ffi, tsRustConversion, caml_bytes_of_uint8array, caml_string_of_jsstring */

// Provides: caml_pasta_fp_plonk_gate_vector_create
// Requires: kimchi_ffi, kimchi_is_wasm, free_on_finalize
var caml_pasta_fp_plonk_gate_vector_create = function () {
    var res = kimchi_ffi.caml_pasta_fp_plonk_gate_vector_create();
    return free_on_finalize(res);
};

// Provides: caml_pasta_fp_plonk_gate_vector_add
// Requires: kimchi_ffi, tsRustConversion
var caml_pasta_fp_plonk_gate_vector_add = function (vector, gate) {
    return kimchi_ffi.caml_pasta_fp_plonk_gate_vector_add(
        vector,
        tsRustConversion.fp.gateToRust(gate)
    );
};

// Provides: caml_pasta_fp_plonk_gate_vector_get
// Requires: kimchi_ffi, tsRustConversion
var caml_pasta_fp_plonk_gate_vector_get = function (vector, index) {
    return tsRustConversion.fp.gateFromRust(
        kimchi_ffi.caml_pasta_fp_plonk_gate_vector_get(vector, index)
    );
};

// Provides: caml_pasta_fp_plonk_gate_vector_len
// Requires: kimchi_ffi
var caml_pasta_fp_plonk_gate_vector_len = function (vector) {
    return kimchi_ffi.caml_pasta_fp_plonk_gate_vector_len(vector);
};

// Provides: caml_pasta_fp_plonk_gate_vector_wrap
// Requires: kimchi_ffi, tsRustConversion
var caml_pasta_fp_plonk_gate_vector_wrap = function (vector, target, head) {
    return kimchi_ffi.caml_pasta_fp_plonk_gate_vector_wrap(
        vector,
        tsRustConversion.wireToRust(target),
        tsRustConversion.wireToRust(head)
    );
};

// Provides: caml_pasta_fp_plonk_gate_vector_digest
// Requires: kimchi_ffi, caml_bytes_of_uint8array
var caml_pasta_fp_plonk_gate_vector_digest = function (public_input_size, gate_vector) {
    var bytes = kimchi_ffi.caml_pasta_fp_plonk_gate_vector_digest(
        public_input_size,
        gate_vector
    );
    return caml_bytes_of_uint8array(bytes);
};

// Provides: caml_pasta_fp_plonk_circuit_serialize
// Requires: kimchi_ffi, caml_string_of_jsstring
var caml_pasta_fp_plonk_circuit_serialize = function (public_input_size, gate_vector) {
    return caml_string_of_jsstring(
        kimchi_ffi.caml_pasta_fp_plonk_circuit_serialize(public_input_size, gate_vector)
    );
};

// --- Fq versions ---

// Provides: caml_pasta_fq_plonk_gate_vector_create
// Requires: kimchi_ffi, kimchi_is_wasm, free_on_finalize
var caml_pasta_fq_plonk_gate_vector_create = function () {
    var res = kimchi_ffi.caml_pasta_fq_plonk_gate_vector_create();
    return free_on_finalize(res);
};

// Provides: caml_pasta_fq_plonk_gate_vector_add
// Requires: kimchi_ffi, tsRustConversion
var caml_pasta_fq_plonk_gate_vector_add = function (vector, gate) {
    return kimchi_ffi.caml_pasta_fq_plonk_gate_vector_add(
        vector,
        tsRustConversion.fq.gateToRust(gate)
    );
};

// Provides: caml_pasta_fq_plonk_gate_vector_get
// Requires: kimchi_ffi, tsRustConversion
var caml_pasta_fq_plonk_gate_vector_get = function (vector, index) {
    return tsRustConversion.fq.gateFromRust(
        kimchi_ffi.caml_pasta_fq_plonk_gate_vector_get(vector, index)
    );
};


// Provides: caml_pasta_fq_plonk_gate_vector_len
// Requires: kimchi_ffi
var caml_pasta_fq_plonk_gate_vector_len = function (vector) {
    return kimchi_ffi.caml_pasta_fq_plonk_gate_vector_len(vector);
};

// Provides: caml_pasta_fq_plonk_gate_vector_wrap
// Requires: kimchi_ffi, tsRustConversion
var caml_pasta_fq_plonk_gate_vector_wrap = function (vector, target, head) {
    return kimchi_ffi.caml_pasta_fq_plonk_gate_vector_wrap(
        vector,
        tsRustConversion.wireToRust(target),
        tsRustConversion.wireToRust(head)
    );
};

// Provides: caml_pasta_fq_plonk_gate_vector_digest
// Requires: kimchi_ffi, caml_bytes_of_uint8array
var caml_pasta_fq_plonk_gate_vector_digest = function (public_input_size, gate_vector) {
    var bytes = kimchi_ffi.caml_pasta_fq_plonk_gate_vector_digest(
        public_input_size,
        gate_vector
    );
    return caml_bytes_of_uint8array(bytes);
};

// Provides: caml_pasta_fq_plonk_circuit_serialize
// Requires: kimchi_ffi, caml_string_of_jsstring
var caml_pasta_fq_plonk_circuit_serialize = function (public_input_size, gate_vector) {
    return caml_string_of_jsstring(
        kimchi_ffi.caml_pasta_fq_plonk_circuit_serialize(public_input_size, gate_vector)
    );
};
