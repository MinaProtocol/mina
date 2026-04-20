/* global kimchi_ffi, tsRustConversion, caml_jsstring_of_string, kimchi_is_native, kimchi_is_wasm */

// FP

// Provides: caml_pasta_fp_plonk_index_serialize
// Requires: kimchi_ffi, kimchi_is_wasm
var caml_pasta_fp_plonk_index_serialize = function (index) {
    // Workaround for Napi issue where methods on External objects are not accessible
    return kimchi_is_wasm ? index.serialize() : kimchi_ffi.prover_index_fp_serialize(index);
};

// Provides: caml_pasta_fp_plonk_index_deserialize
// Requires: kimchi_ffi, kimchi_is_wasm
var caml_pasta_fp_plonk_index_deserialize = function (index) {
    // Workaround for Napi issue where methods on External objects are not accessible
    return kimchi_is_wasm ? index.deserialize() : kimchi_ffi.prover_index_fp_deserialize(index);
};

// Provides: caml_pasta_fp_plonk_index_create
// Requires: kimchi_ffi, tsRustConversion, free_on_finalize
var caml_pasta_fp_plonk_index_create = function (
    gates,
    public_inputs,
    caml_lookup_tables,
    caml_runtime_table_cfgs,
    prev_challenges,
    urs,
    lazy_mode
) {
    var rust_lookup_tables =
        tsRustConversion.fp.lookupTablesToRust(caml_lookup_tables);
    var rust_runtime_table_cfgs = tsRustConversion.fp.runtimeTableCfgsToRust(
        caml_runtime_table_cfgs
    );
    var t = kimchi_ffi.caml_pasta_fp_plonk_index_create(
        gates,
        public_inputs,
        rust_lookup_tables,
        rust_runtime_table_cfgs,
        prev_challenges,
        urs,
        lazy_mode
    );

    return free_on_finalize(t);
};

// Provides: caml_pasta_fp_plonk_index_create_bytecode
// Requires: caml_pasta_fp_plonk_index_create
var caml_pasta_fp_plonk_index_create_bytecode = function (
    gates,
    public_inputs,
    caml_lookup_tables,
    caml_runtime_table_cfgs,
    prev_challenges,
    urs,
    lazy_mode
) {
    return caml_pasta_fp_plonk_index_create(
        gates,
        public_inputs,
        caml_lookup_tables,
        caml_runtime_table_cfgs,
        prev_challenges,
        urs,
        lazy_mode
    );
};

// Provides: caml_pasta_fp_plonk_index_max_degree
// Requires: kimchi_ffi
function caml_pasta_fp_plonk_index_max_degree(index) {
    return kimchi_ffi.caml_pasta_fp_plonk_index_max_degree(index);
}

// Provides: caml_pasta_fp_plonk_index_public_inputs
// Requires: kimchi_ffi
function caml_pasta_fp_plonk_index_public_inputs(index) {
    return kimchi_ffi.caml_pasta_fp_plonk_index_public_inputs(index);
}

// Provides: caml_pasta_fp_plonk_index_domain_d1_size
// Requires: kimchi_ffi
function caml_pasta_fp_plonk_index_domain_d1_size(index) {
    return kimchi_ffi.caml_pasta_fp_plonk_index_domain_d1_size(index);
}

// Provides: caml_pasta_fp_plonk_index_domain_d4_size
// Requires: kimchi_ffi
function caml_pasta_fp_plonk_index_domain_d4_size(index) {
    return kimchi_ffi.caml_pasta_fp_plonk_index_domain_d4_size(index);
}

// Provides: caml_pasta_fp_plonk_index_domain_d8_size
// Requires: kimchi_ffi
function caml_pasta_fp_plonk_index_domain_d8_size(index) {
    return kimchi_ffi.caml_pasta_fp_plonk_index_domain_d8_size(index);
}

// Provides: caml_pasta_fp_plonk_index_read
// Requires: kimchi_ffi, caml_jsstring_of_string
var caml_pasta_fp_plonk_index_read = function (offset, urs, path) {
    if (offset === 0) {
        offset = undefined;
    } else {
        offset = offset[1];
    }
    return kimchi_ffi.caml_pasta_fp_plonk_index_read(
        offset,
        urs,
        caml_jsstring_of_string(path)
    );
};

// Provides: caml_pasta_fp_plonk_index_write
// Requires: kimchi_ffi, caml_jsstring_of_string
var caml_pasta_fp_plonk_index_write = function (append, t, path) {
    if (append === 0) {
        append = undefined;
    } else {
        append = append[1];
    }
    return kimchi_ffi.caml_pasta_fp_plonk_index_write(
        append,
        t,
        caml_jsstring_of_string(path)
    );
};

//////// FQ ////////

// Provides: caml_pasta_fq_plonk_index_serialize
// Requires: kimchi_ffi, kimchi_is_wasm
var caml_pasta_fq_plonk_index_serialize = function (index) {
    // Workaround for Napi issue where methods on External objects are not accessible
    return kimchi_is_wasm ? index.serialize() : kimchi_ffi.prover_index_fq_serialize(index);
};

// Provides: caml_pasta_fq_plonk_index_deserialize
// Requires: kimchi_ffi, kimchi_is_wasm
var caml_pasta_fq_plonk_index_deserialize = function (index) {
    // Workaround for Napi issue where methods on External objects are not accessible
    return kimchi_is_wasm ? index.deserialize() : kimchi_ffi.prover_index_fq_deserialize(index);
};

// Provides: caml_pasta_fq_plonk_index_create
// Requires: kimchi_ffi, tsRustConversion, free_on_finalize
var caml_pasta_fq_plonk_index_create = function (
    gates,
    public_inputs,
    caml_lookup_tables,
    caml_runtime_table_cfgs,
    prev_challenges,
    urs,
    lazy_mode
) {
    var rust_lookup_tables =
        tsRustConversion.fq.lookupTablesToRust(caml_lookup_tables);
    var rust_runtime_table_cfgs = tsRustConversion.fq.runtimeTableCfgsToRust(
        caml_runtime_table_cfgs
    );

    var t = kimchi_ffi.caml_pasta_fq_plonk_index_create(
        gates,
        public_inputs,
        rust_lookup_tables,
        rust_runtime_table_cfgs,
        prev_challenges,
        urs,
        lazy_mode
    );

    return free_on_finalize(t);
};

// Provides: caml_pasta_fq_plonk_index_create_bytecode
// Requires: caml_pasta_fq_plonk_index_create
var caml_pasta_fq_plonk_index_create_bytecode = function (
    gates,
    public_inputs,
    caml_lookup_tables,
    caml_runtime_table_cfgs,
    prev_challenges,
    urs,
    lazy_mode
) {
    return caml_pasta_fq_plonk_index_create(
        gates,
        public_inputs,
        caml_lookup_tables,
        caml_runtime_table_cfgs,
        prev_challenges,
        urs,
        lazy_mode
    );
};

// Provides: caml_pasta_fq_plonk_index_max_degree
// Requires: kimchi_ffi
function caml_pasta_fq_plonk_index_max_degree(index) {
    return kimchi_ffi.caml_pasta_fq_plonk_index_max_degree(index);
}

// Provides: caml_pasta_fq_plonk_index_public_inputs
// Requires: kimchi_ffi
function caml_pasta_fq_plonk_index_public_inputs(index) {
    return kimchi_ffi.caml_pasta_fq_plonk_index_public_inputs(index);
}

// Provides: caml_pasta_fq_plonk_index_domain_d1_size
// Requires: kimchi_ffi
function caml_pasta_fq_plonk_index_domain_d1_size(index) {
    return kimchi_ffi.caml_pasta_fq_plonk_index_domain_d1_size(index);
}

// Provides: caml_pasta_fq_plonk_index_domain_d4_size
// Requires: kimchi_ffi
function caml_pasta_fq_plonk_index_domain_d4_size(index) {
    return kimchi_ffi.caml_pasta_fq_plonk_index_domain_d4_size(index);
}

// Provides: caml_pasta_fq_plonk_index_domain_d8_size
// Requires: kimchi_ffi
function caml_pasta_fq_plonk_index_domain_d8_size(index) {
    return kimchi_ffi.caml_pasta_fq_plonk_index_domain_d8_size(index);
}

// Provides: caml_pasta_fq_plonk_index_read
// Requires: kimchi_ffi, caml_jsstring_of_string
var caml_pasta_fq_plonk_index_read = function (offset, urs, path) {
    if (offset === 0) {
        offset = undefined;
    } else {
        offset = offset[1];
    }
    return kimchi_ffi.caml_pasta_fq_plonk_index_read(
        offset,
        urs,
        caml_jsstring_of_string(path)
    );
};

// Provides: caml_pasta_fq_plonk_index_write
// Requires: kimchi_ffi, caml_jsstring_of_string
var caml_pasta_fq_plonk_index_write = function (append, t, path) {
    if (append === 0) {
        append = undefined;
    } else {
        append = append[1];
    }
    return kimchi_ffi.caml_pasta_fq_plonk_index_write(
        append,
        t,
        caml_jsstring_of_string(path)
    );
};
