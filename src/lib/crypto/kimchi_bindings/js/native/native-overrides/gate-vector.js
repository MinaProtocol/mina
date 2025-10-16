/* eslint-disable no-unused-vars */
/* global plonk_wasm, tsRustConversionNative, caml_bytes_of_uint8array, caml_string_of_jsstring */

// Provides: caml_pasta_fp_plonk_gate_vector_create
// Requires: plonk_wasm
var caml_pasta_fp_plonk_gate_vector_create = function () {
    return plonk_wasm.caml_pasta_fp_plonk_gate_vector_create();
};

// Provides: caml_pasta_fp_plonk_gate_vector_add
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fp_plonk_gate_vector_add = function (vector, gate) {
    return plonk_wasm.caml_pasta_fp_plonk_gate_vector_add(
        vector,
        tsRustConversionNative.fp.gateToRust(gate)
    );
};

// Provides: caml_pasta_fp_plonk_gate_vector_get
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fp_plonk_gate_vector_get = function (vector, index) {
    if (typeof console !== 'undefined') { 
        console.log('Using native fp gate_vector get');
    }
    return tsRustConversionNative.fp.gateFromRust(
        plonk_wasm.caml_pasta_fp_plonk_gate_vector_get(vector, index)
    );
};

// Provides: caml_pasta_fp_plonk_gate_vector_len
// Requires: plonk_wasm
var caml_pasta_fp_plonk_gate_vector_len = function (vector) {
    if (typeof console !== 'undefined') {
        console.log('Using native fp gate_vector len');
    }
    return plonk_wasm.caml_pasta_fp_plonk_gate_vector_len(vector);
};

// Provides: caml_pasta_fp_plonk_gate_vector_wrap
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fp_plonk_gate_vector_wrap = function (vector, target, head) {
    if (typeof console !== 'undefined') {
        console.log('Using native fp gate_vector wrap');
    }
    return plonk_wasm.caml_pasta_fp_plonk_gate_vector_wrap(
        vector,
        tsRustConversionNative.wireToRust(target),
        tsRustConversionNative.wireToRust(head)
    );
};

// Provides: caml_pasta_fp_plonk_gate_vector_digest
// Requires: plonk_wasm, caml_bytes_of_uint8array
var caml_pasta_fp_plonk_gate_vector_digest = function (public_input_size, gate_vector) {
    var bytes = plonk_wasm.caml_pasta_fp_plonk_gate_vector_digest(
        public_input_size,
        gate_vector
    );
    if (!(bytes instanceof Uint8Array)) {
        bytes = Uint8Array.from(bytes);
    }
    return caml_bytes_of_uint8array(bytes);
};


// Provides: caml_pasta_fp_plonk_circuit_serialize
// Requires: plonk_wasm, caml_string_of_jsstring
var caml_pasta_fp_plonk_circuit_serialize = function (public_input_size, gate_vector) {
    return caml_string_of_jsstring(
        plonk_wasm.caml_pasta_fp_plonk_circuit_serialize(public_input_size, gate_vector)
    );
};

// --- Fq versions ---

// Provides: caml_pasta_fq_plonk_gate_vector_create
// Requires: plonk_wasm
var caml_pasta_fq_plonk_gate_vector_create = function () {
    return plonk_wasm.caml_pasta_fq_plonk_gate_vector_create();
};

// Provides: caml_pasta_fq_plonk_gate_vector_add
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fq_plonk_gate_vector_add = function (vector, gate) {
    return plonk_wasm.caml_pasta_fq_plonk_gate_vector_add(
        vector,
        tsRustConversionNative.fq.gateToRust(gate)
    );
};

// Provides: caml_pasta_fq_plonk_gate_vector_get
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fq_plonk_gate_vector_get = function (vector, index) {
    if (typeof console !== 'undefined') { 
        console.log('Using native fq gate_vector get');
    }
    return tsRustConversionNative.fq.gateFromRust(
        plonk_wasm.caml_pasta_fq_plonk_gate_vector_get(vector, index)
    );
};


// Provides: caml_pasta_fq_plonk_gate_vector_len
// Requires: plonk_wasm
var caml_pasta_fq_plonk_gate_vector_len = function (vector) {
    if (typeof console !== 'undefined') {
        console.log('Using native fq gate_vector len');
    }
    return plonk_wasm.caml_pasta_fq_plonk_gate_vector_len(vector);
};

// Provides: caml_pasta_fq_plonk_gate_vector_wrap
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fq_plonk_gate_vector_wrap = function (vector, target, head) {
    if (typeof console !== 'undefined') {
        console.log('Using native fq gate_vector wrap');
    }
    return plonk_wasm.caml_pasta_fq_plonk_gate_vector_wrap(
        vector,
        tsRustConversionNative.wireToRust(target),
        tsRustConversionNative.wireToRust(head)
    );
};

// Provides: caml_pasta_fq_plonk_gate_vector_digest
// Requires: plonk_wasm, caml_bytes_of_uint8array
var caml_pasta_fq_plonk_gate_vector_digest = function (public_input_size, gate_vector) {
    var bytes = plonk_wasm.caml_pasta_fq_plonk_gate_vector_digest(
        public_input_size,
        gate_vector
    );
    if (!(bytes instanceof Uint8Array)) {
        bytes = Uint8Array.from(bytes);
    }
    return caml_bytes_of_uint8array(bytes);
};

// Provides: caml_pasta_fq_plonk_circuit_serialize
// Requires: plonk_wasm, caml_string_of_jsstring
var caml_pasta_fq_plonk_circuit_serialize = function (public_input_size, gate_vector) {
    return caml_string_of_jsstring(
        plonk_wasm.caml_pasta_fq_plonk_circuit_serialize(public_input_size, gate_vector)
    );
};
