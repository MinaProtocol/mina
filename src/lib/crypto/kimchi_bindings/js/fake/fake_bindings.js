/* global joo_global_object, plonk_wasm, caml_js_to_bool, caml_jsstring_of_string,
    caml_string_of_jsstring
    caml_create_bytes, caml_bytes_unsafe_set, caml_bytes_unsafe_get, caml_ml_bytes_length
*/

// Provides: caml_bytes_of_uint8array
// Requires: caml_create_bytes, caml_bytes_unsafe_set
var caml_bytes_of_uint8array = function(uint8array) {
    var length = uint8array.length;
    var ocaml_bytes = caml_create_bytes(length);
    for (var i = 0; i < length; i++) {
        // No need to convert here: OCaml Char.t is just an int under the hood.
        caml_bytes_unsafe_set(ocaml_bytes, i, uint8array[i]);
    }
    return ocaml_bytes;
};

// Provides: caml_bytes_to_uint8array
// Requires: caml_ml_bytes_length, caml_bytes_unsafe_get
var caml_bytes_to_uint8array = function(ocaml_bytes) {
    var length = caml_ml_bytes_length(ocaml_bytes);
    var bytes = new joo_global_object.Uint8Array(length);
    for (var i = 0; i < length; i++) {
        // No need to convert here: OCaml Char.t is just an int under the hood.
        bytes[i] = caml_bytes_unsafe_get(ocaml_bytes, i);
    }
    return bytes;
};

// Provides: caml_bigint_256_of_decimal_string
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_bigint_256_of_decimal_string = function (s) {
    return plonk_wasm.caml_bigint_256_of_decimal_string(caml_jsstring_of_string(s));
};

// Provides: caml_bigint_256_num_limbs
// Requires: plonk_wasm
var caml_bigint_256_num_limbs = plonk_wasm.caml_bigint_256_num_limbs

// Provides: caml_bigint_256_bytes_per_limb
// Requires: plonk_wasm
var caml_bigint_256_bytes_per_limb = plonk_wasm.caml_bigint_256_bytes_per_limb

// Provides: caml_bigint_256_div
// Requires: plonk_wasm
var caml_bigint_256_div = plonk_wasm.caml_bigint_256_div

// Provides: caml_bigint_256_compare
// Requires: plonk_wasm
var caml_bigint_256_compare = plonk_wasm.caml_bigint_256_compare

// Provides: caml_bigint_256_to_string
// Requires: plonk_wasm, caml_string_of_jsstring
var caml_bigint_256_to_string = function(x) {
    return caml_string_of_jsstring(plonk_wasm.caml_bigint_256_to_string(x));
};

// Provides: caml_bigint_256_test_bit
// Requires: plonk_wasm, caml_js_to_bool
var caml_bigint_256_test_bit = function(x, i) {
    return caml_js_to_bool(plonk_wasm.caml_bigint_256_test_bit(x, i));
};

// Provides: caml_bigint_256_to_bytes
// Requires: plonk_wasm, caml_bytes_of_uint8array
var caml_bigint_256_to_bytes = function(x) {
    return caml_bytes_of_uint8array(plonk_wasm.caml_bigint_256_to_bytes(x));
};

// Provides: caml_bigint_256_of_bytes
// Requires: plonk_wasm, caml_bytes_to_uint8array
var caml_bigint_256_of_bytes = function(ocaml_bytes) {
    return plonk_wasm.caml_bigint_256_of_bytes(caml_bytes_to_uint8array(ocaml_bytes));
};






// Provides: caml_pasta_fp_copy
var caml_pasta_fp_copy = function(x, y) {
    for (var i = 0, l = x.length; i < l; i++) {
        x[i] = y[i];
    }
};

// Provides: caml_pasta_fp_option
var caml_pasta_fp_option = function(x) {
    // We encode 'none' in JS as undefined
    if (x === undefined) return 0; // None
    return [0, x]; // Some(x)
};

// Provides: caml_pasta_fp_size_in_bits
// Requires: plonk_wasm
var caml_pasta_fp_size_in_bits = plonk_wasm.caml_pasta_fp_size_in_bits

// Provides: caml_pasta_fp_size
// Requires: plonk_wasm
var caml_pasta_fp_size = plonk_wasm.caml_pasta_fp_size

// Provides: caml_pasta_fp_add
// Requires: plonk_wasm
var caml_pasta_fp_add = plonk_wasm.caml_pasta_fp_add

// Provides: caml_pasta_fp_sub
// Requires: plonk_wasm
var caml_pasta_fp_sub = plonk_wasm.caml_pasta_fp_sub

// Provides: caml_pasta_fp_negate
// Requires: plonk_wasm
var caml_pasta_fp_negate = plonk_wasm.caml_pasta_fp_negate

// Provides: caml_pasta_fp_mul
// Requires: plonk_wasm
var caml_pasta_fp_mul = plonk_wasm.caml_pasta_fp_mul

// Provides: caml_pasta_fp_div
// Requires: plonk_wasm
var caml_pasta_fp_div = plonk_wasm.caml_pasta_fp_div

// Provides: caml_pasta_fp_inv
// Requires: plonk_wasm, caml_pasta_fp_option
var caml_pasta_fp_inv = function(x) {
    return caml_pasta_fp_option(plonk_wasm.caml_pasta_fp_inv(x));
};

// Provides: caml_pasta_fp_square
// Requires: plonk_wasm
var caml_pasta_fp_square = plonk_wasm.caml_pasta_fp_square

// Provides: caml_pasta_fp_is_square
// Requires: plonk_wasm, caml_js_to_bool
var caml_pasta_fp_is_square = function(x) {
    return caml_js_to_bool(plonk_wasm.caml_pasta_fp_is_square(x));
};

// Provides: caml_pasta_fp_sqrt
// Requires: plonk_wasm, caml_pasta_fp_option
var caml_pasta_fp_sqrt = function(x) {
    return caml_pasta_fp_option(plonk_wasm.caml_pasta_fp_sqrt(x));
};

// Provides: caml_pasta_fp_of_int
// Requires: plonk_wasm
var caml_pasta_fp_of_int = plonk_wasm.caml_pasta_fp_of_int

// Provides: caml_pasta_fp_to_string
// Requires: plonk_wasm, caml_string_of_jsstring
var caml_pasta_fp_to_string = function(x) {
    return caml_string_of_jsstring(plonk_wasm.caml_pasta_fp_to_string(x));
};

// Provides: caml_pasta_fp_of_string
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fp_of_string = function (x) {
    return plonk_wasm.caml_pasta_fp_of_string(caml_jsstring_of_string(x));
};


// Provides: caml_pasta_fp_mut_add
// Requires: caml_pasta_fp_copy, caml_pasta_fp_add
var caml_pasta_fp_mut_add = function(x, y) {
    caml_pasta_fp_copy(x, caml_pasta_fp_add(x, y));
};

// Provides: caml_pasta_fp_mut_sub
// Requires: caml_pasta_fp_copy, caml_pasta_fp_sub
var caml_pasta_fp_mut_sub = function(x, y) {
    caml_pasta_fp_copy(x, caml_pasta_fp_sub(x, y));
};

// Provides: caml_pasta_fp_mut_mul
// Requires: caml_pasta_fp_copy, caml_pasta_fp_mul
var caml_pasta_fp_mut_mul = function(x, y) {
    caml_pasta_fp_copy(x, caml_pasta_fp_mul(x, y));
};

// Provides: caml_pasta_fp_mut_square
// Requires: caml_pasta_fp_copy, caml_pasta_fp_square
var caml_pasta_fp_mut_square = function(x) {
    caml_pasta_fp_copy(x, caml_pasta_fp_square(x));
};

// Provides: caml_pasta_fp_compare
// Requires: plonk_wasm
var caml_pasta_fp_compare = plonk_wasm.caml_pasta_fp_compare

// Provides: caml_pasta_fp_equal
// Requires: plonk_wasm
var caml_pasta_fp_equal = plonk_wasm.caml_pasta_fp_equal

// Provides: caml_pasta_fp_to_bigint
// Requires: plonk_wasm
var caml_pasta_fp_to_bigint = plonk_wasm.caml_pasta_fp_to_bigint

// Provides: caml_pasta_fp_of_bigint
// Requires: plonk_wasm
var caml_pasta_fp_of_bigint = plonk_wasm.caml_pasta_fp_of_bigint

// Provides: caml_pasta_fp_domain_generator
// Requires: plonk_wasm
var caml_pasta_fp_domain_generator = plonk_wasm.caml_pasta_fp_domain_generator

// Provides: caml_pasta_fp_to_bytes
// Requires: plonk_wasm, caml_bytes_of_uint8array
var caml_pasta_fp_to_bytes = function(x) {
    var res = plonk_wasm.caml_pasta_fp_to_bytes(x);
    return caml_bytes_of_uint8array(plonk_wasm.caml_pasta_fp_to_bytes(x));
};

// Provides: caml_pasta_fp_of_bytes
// Requires: plonk_wasm, caml_bytes_to_uint8array
var caml_pasta_fp_of_bytes = function(ocaml_bytes) {
    return plonk_wasm.caml_pasta_fp_of_bytes(caml_bytes_to_uint8array(ocaml_bytes));
};




// Provides: caml_pasta_fq_copy
var caml_pasta_fq_copy = function(x, y) {
    for (var i = 0, l = x.length; i < l; i++) {
        x[i] = y[i];
    }
};

// Provides: caml_pasta_fq_option
var caml_pasta_fq_option = function(x) {
    // We encode 'none' in JS as undefined
    if (x === undefined) return 0; // None
    return [0, x]; // Some(x)
};

// Provides: caml_pasta_fq_size_in_bits
// Requires: plonk_wasm
var caml_pasta_fq_size_in_bits = plonk_wasm.caml_pasta_fq_size_in_bits

// Provides: caml_pasta_fq_size
// Requires: plonk_wasm
var caml_pasta_fq_size = plonk_wasm.caml_pasta_fq_size

// Provides: caml_pasta_fq_add
// Requires: plonk_wasm
var caml_pasta_fq_add = plonk_wasm.caml_pasta_fq_add

// Provides: caml_pasta_fq_sub
// Requires: plonk_wasm
var caml_pasta_fq_sub = plonk_wasm.caml_pasta_fq_sub

// Provides: caml_pasta_fq_negate
// Requires: plonk_wasm
var caml_pasta_fq_negate = plonk_wasm.caml_pasta_fq_negate

// Provides: caml_pasta_fq_mul
// Requires: plonk_wasm
var caml_pasta_fq_mul = plonk_wasm.caml_pasta_fq_mul

// Provides: caml_pasta_fq_div
// Requires: plonk_wasm
var caml_pasta_fq_div = plonk_wasm.caml_pasta_fq_div

// Provides: caml_pasta_fq_inv
// Requires: plonk_wasm, caml_pasta_fq_option
var caml_pasta_fq_inv = function(x) {
    return caml_pasta_fq_option(plonk_wasm.caml_pasta_fq_inv(x));
};

// Provides: caml_pasta_fq_square
// Requires: plonk_wasm
var caml_pasta_fq_square = plonk_wasm.caml_pasta_fq_square

// Provides: caml_pasta_fq_is_square
// Requires: plonk_wasm, caml_js_to_bool
var caml_pasta_fq_is_square = function(x) {
    return caml_js_to_bool(plonk_wasm.caml_pasta_fq_is_square(x));
};

// Provides: caml_pasta_fq_sqrt
// Requires: plonk_wasm, caml_pasta_fq_option
var caml_pasta_fq_sqrt = function(x) {
    return caml_pasta_fq_option(plonk_wasm.caml_pasta_fq_sqrt(x));
};

// Provides: caml_pasta_fq_of_int
// Requires: plonk_wasm
var caml_pasta_fq_of_int = plonk_wasm.caml_pasta_fq_of_int

// Provides: caml_pasta_fq_to_string
// Requires: plonk_wasm, caml_string_of_jsstring
var caml_pasta_fq_to_string = function(x) {
    return caml_string_of_jsstring(plonk_wasm.caml_pasta_fq_to_string(x));
};

// Provides: caml_pasta_fq_of_string
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fq_of_string = function (x) {
    return plonk_wasm.caml_pasta_fq_of_string(caml_jsstring_of_string(x));
};

// Provides: caml_pasta_fq_mut_add
// Requires: caml_pasta_fq_copy, caml_pasta_fq_add
var caml_pasta_fq_mut_add = function(x, y) {
    caml_pasta_fq_copy(x, caml_pasta_fq_add(x, y));
};

// Provides: caml_pasta_fq_mut_sub
// Requires: caml_pasta_fq_copy, caml_pasta_fq_sub
var caml_pasta_fq_mut_sub = function(x, y) {
    caml_pasta_fq_copy(x, caml_pasta_fq_sub(x, y));
};

// Provides: caml_pasta_fq_mut_mul
// Requires: caml_pasta_fq_copy, caml_pasta_fq_mul
var caml_pasta_fq_mut_mul = function(x, y) {
    caml_pasta_fq_copy(x, caml_pasta_fq_mul(x, y));
};

// Provides: caml_pasta_fq_mut_square
// Requires: caml_pasta_fq_copy, caml_pasta_fq_square
var caml_pasta_fq_mut_square = function(x) {
    caml_pasta_fq_copy(x, caml_pasta_fq_square(x));
};

// Provides: caml_pasta_fq_compare
// Requires: plonk_wasm
var caml_pasta_fq_compare = plonk_wasm.caml_pasta_fq_compare

// Provides: caml_pasta_fq_equal
// Requires: plonk_wasm
var caml_pasta_fq_equal = plonk_wasm.caml_pasta_fq_equal

// Provides: caml_pasta_fq_to_bigint
// Requires: plonk_wasm
var caml_pasta_fq_to_bigint = plonk_wasm.caml_pasta_fq_to_bigint

// Provides: caml_pasta_fq_of_bigint
// Requires: plonk_wasm
var caml_pasta_fq_of_bigint = plonk_wasm.caml_pasta_fq_of_bigint

// Provides: caml_pasta_fq_domain_generator
// Requires: plonk_wasm
var caml_pasta_fq_domain_generator = plonk_wasm.caml_pasta_fq_domain_generator

// Provides: caml_pasta_fq_to_bytes
// Requires: plonk_wasm, caml_bytes_of_uint8array
var caml_pasta_fq_to_bytes = function(x) {
    var res = plonk_wasm.caml_pasta_fq_to_bytes(x);
    return caml_bytes_of_uint8array(plonk_wasm.caml_pasta_fq_to_bytes(x));
};

// Provides: caml_pasta_fq_of_bytes
// Requires: plonk_wasm, caml_bytes_to_uint8array
var caml_pasta_fq_of_bytes = function(ocaml_bytes) {
    return plonk_wasm.caml_pasta_fq_of_bytes(caml_bytes_to_uint8array(ocaml_bytes));
};





// Provides: caml_fp_vector_create
var caml_fp_vector_create = function() { return []; };
// Provides: caml_fp_vector_length
var caml_fp_vector_length = function (v) { return v.length; };
// Provides: caml_fp_vector_emplace_back
var caml_fp_vector_emplace_back = function (v, x) { v.push(x); }
// Provides: caml_fp_vector_get
var caml_fp_vector_get = function (v, i) { return v[i]; }
// Provides: caml_fp_vector_to_rust
var caml_fp_vector_to_rust = function (v) { return v; }
// Provides: caml_fp_vector_of_rust
var caml_fp_vector_of_rust = function (v) { return v; }

// Provides: caml_fq_vector_create
var caml_fq_vector_create = function() { return []; };
// Provides: caml_fq_vector_length
var caml_fq_vector_length = function (v) { return v.length; };
// Provides: caml_fq_vector_emplace_back
var caml_fq_vector_emplace_back = function (v, x) { v.push(x); }
// Provides: caml_fq_vector_get
var caml_fq_vector_get = function (v, i) { return v[i]; }
// Provides: caml_fq_vector_to_rust
var caml_fq_vector_to_rust = function (v) { return v; }
// Provides: caml_fq_vector_of_rust
var caml_fq_vector_of_rust = function (v) { return v; }






// Provides: rust_affine_to_caml_affine
var rust_affine_to_caml_affine = function(g) {
    if (g.infinity) return 0;
    return [0, [0, g.x, g.y]];
};

// Provides: caml_pallas_one
// Requires: plonk_wasm
var caml_pallas_one = plonk_wasm.caml_pallas_one
// Provides: caml_pallas_negate
// Requires: plonk_wasm
var caml_pallas_negate = plonk_wasm.caml_pallas_negate;
// Provides: caml_pallas_add
// Requires: plonk_wasm
var caml_pallas_add = plonk_wasm.caml_pallas_add;
// Provides: caml_pallas_sub
// Requires: plonk_wasm
var caml_pallas_sub = plonk_wasm.caml_pallas_sub
// Provides: caml_pallas_scale
// Requires: plonk_wasm
var caml_pallas_scale = plonk_wasm.caml_pallas_scale

// Provides: caml_pallas_to_affine
// Requires: plonk_wasm, rust_affine_to_caml_affine
var caml_pallas_to_affine = function(pt) {
    var res = plonk_wasm.caml_pallas_to_affine(pt);
    return rust_affine_to_caml_affine(res);
};
// Provides: caml_pallas_of_affine_coordinates
// Requires: plonk_wasm
var caml_pallas_of_affine_coordinates = plonk_wasm.caml_pallas_of_affine_coordinates

// Provides: caml_pallas_endo_base
// Requires: plonk_wasm
var caml_pallas_endo_base = plonk_wasm.caml_pallas_endo_base;
// Provides: caml_pallas_endo_scalar
// Requires: plonk_wasm
var caml_pallas_endo_scalar = plonk_wasm.caml_pallas_endo_scalar;


// Provides: caml_vesta_one
// Requires: plonk_wasm
var caml_vesta_one = plonk_wasm.caml_vesta_one;
// Provides: caml_vesta_negate
// Requires: plonk_wasm
var caml_vesta_negate = plonk_wasm.caml_vesta_negate;
// Provides: caml_vesta_add
// Requires: plonk_wasm
var caml_vesta_add = plonk_wasm.caml_vesta_add;
// Provides: caml_vesta_sub
// Requires: plonk_wasm
var caml_vesta_sub = plonk_wasm.caml_vesta_sub;
// Provides: caml_vesta_scale
// Requires: plonk_wasm
var caml_vesta_scale = plonk_wasm.caml_vesta_scale;

// Provides: caml_vesta_to_affine
// Requires: plonk_wasm, rust_affine_to_caml_affine
var caml_vesta_to_affine = function(pt) {
    var res = plonk_wasm.caml_vesta_to_affine(pt);
    return rust_affine_to_caml_affine(res);
};

// Provides: caml_vesta_of_affine_coordinates
// Requires: plonk_wasm
var caml_vesta_of_affine_coordinates = plonk_wasm.caml_vesta_of_affine_coordinates

// Provides: caml_vesta_endo_base
// Requires: plonk_wasm
var caml_vesta_endo_base = plonk_wasm.caml_vesta_endo_base;
// Provides: caml_vesta_endo_scalar
// Requires: plonk_wasm
var caml_vesta_endo_scalar = plonk_wasm.caml_vesta_endo_scalar;



// Provides: caml_plonk_verification_shifts_of_rust
var caml_plonk_verification_shifts_of_rust = function(x) {
    return [0, x.s0, x.s1, x.s2, x.s3, x.s4, x.s5, x.s6];
};

// Provides: caml_pasta_fp_plonk_verifier_index_shifts
// Requires: plonk_wasm, caml_plonk_verification_shifts_of_rust
var caml_pasta_fp_plonk_verifier_index_shifts = function(log2_size) {
    return caml_plonk_verification_shifts_of_rust(plonk_wasm.caml_pasta_fp_plonk_verifier_index_shifts(log2_size));
};

// Provides: caml_pasta_fq_plonk_verifier_index_shifts
// Requires: plonk_wasm, caml_plonk_verification_shifts_of_rust
var caml_pasta_fq_plonk_verifier_index_shifts = function(log2_size) {
    return caml_plonk_verification_shifts_of_rust(plonk_wasm.caml_pasta_fq_plonk_verifier_index_shifts(log2_size));
};


// This is fake -- parameters are only needed on the Rust side, so no need to return something meaningful
// Provides: caml_pasta_fp_poseidon_params_create
function caml_pasta_fp_poseidon_params_create() {
    return [0];
}
// Provides: caml_pasta_fq_poseidon_params_create
function caml_pasta_fq_poseidon_params_create() {
    return [0];
}

// Provides: caml_pasta_fp_poseidon_block_cipher
// Requires: plonk_wasm, caml_fp_vector_to_rust, caml_fp_vector_of_rust
function caml_pasta_fp_poseidon_block_cipher(_fake_params, fp_vector) {
    // 1. get permuted field vector from rust
    var wasm_flat_vector = plonk_wasm.caml_pasta_fp_poseidon_block_cipher(caml_fp_vector_to_rust(fp_vector));
    var new_fp_vector = caml_fp_vector_of_rust(wasm_flat_vector);
    // 2. write back modified field vector to original one
    new_fp_vector.forEach(function (a, i) {
        fp_vector[i] = a;
    });
}
// Provides: caml_pasta_fq_poseidon_block_cipher
// Requires: plonk_wasm, caml_fq_vector_to_rust, caml_fq_vector_of_rust
function caml_pasta_fq_poseidon_block_cipher(_fake_params, fq_vector) {
    // 1. get permuted field vector from rust
    var wasm_flat_vector = plonk_wasm.caml_pasta_fq_poseidon_block_cipher(caml_fq_vector_to_rust(fq_vector));
    var new_fq_vector = caml_fq_vector_of_rust(wasm_flat_vector);
    // 2. write back modified field vector to original one
    new_fq_vector.forEach(function (a, i) {
        fq_vector[i] = a;
    });
}
