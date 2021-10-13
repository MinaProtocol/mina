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

// Provides: caml_bigint_256_of_numeral
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_bigint_256_of_numeral = function (s, len, base) {
    return plonk_wasm.caml_bigint_256_of_numeral(caml_jsstring_of_string(s), len, base);
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

// Provides: caml_bigint_256_print
// Requires: plonk_wasm
var caml_bigint_256_print = plonk_wasm.caml_bigint_256_print

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

// Provides: caml_bigint_256_deep_copy
// Requires: plonk_wasm
var caml_bigint_256_deep_copy = plonk_wasm.caml_bigint_256_deep_copy





// Provides: caml_pasta_fp_copy
var caml_pasta_fp_copy = function(x, y) {
    for (var i = 0, l = x.length; i < l; i++) {
        x[i] = y[i];
    }
};

// Provides: caml_pasta_fp_option
var caml_pasta_fp_option = function(x) {
    // We encode 'none' in WASM as a biginteger formed from a series of
    // max-size u64s, which gets split into u8s. This value is never returned
    // as a valid field element, since it is larger than the field's modulus.
    for (var i = 0, l = x.length; i < l; i++) {
        if (x[i] != 255) {
            return [0, x]; // Some(x)
        }
    }
    return 0;
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

// Provides: caml_pasta_fp_print
// Requires: plonk_wasm
var caml_pasta_fp_print = plonk_wasm.caml_pasta_fp_print

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

// Provides: caml_pasta_fp_random
// Requires: plonk_wasm
var caml_pasta_fp_random = plonk_wasm.caml_pasta_fp_random

// Provides: caml_pasta_fp_rng
// Requires: plonk_wasm
var caml_pasta_fp_rng = plonk_wasm.caml_pasta_fp_rng

// Provides: caml_pasta_fp_to_bigint
// Requires: plonk_wasm
var caml_pasta_fp_to_bigint = plonk_wasm.caml_pasta_fp_to_bigint

// Provides: caml_pasta_fp_of_bigint
// Requires: plonk_wasm
var caml_pasta_fp_of_bigint = plonk_wasm.caml_pasta_fp_of_bigint

// Provides: caml_pasta_fp_two_adic_root_of_unity
// Requires: plonk_wasm
var caml_pasta_fp_two_adic_root_of_unity = plonk_wasm.caml_pasta_fp_two_adic_root_of_unity

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

// Provides: caml_pasta_fp_deep_copy
// Requires: plonk_wasm
var caml_pasta_fp_deep_copy = plonk_wasm.caml_pasta_fp_deep_copy





// Provides: caml_pasta_fq_copy
var caml_pasta_fq_copy = function(x, y) {
    for (var i = 0, l = x.length; i < l; i++) {
        x[i] = y[i];
    }
};

// Provides: caml_pasta_fq_option
var caml_pasta_fq_option = function(x) {
    // We encode 'none' in WASM as a biginteger formed from a series of
    // max-size u64s, which gets split into u8s. This value is never returned
    // as a valid field element, since it is larger than the field's modulus.
    for (var i = 0, l = x.length; i < l; i++) {
        if (x[i] != 255) {
            return [0, x]; // Some(x)
        }
    }
    return 0;
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

// Provides: caml_pasta_fq_print
// Requires: plonk_wasm
var caml_pasta_fq_print = plonk_wasm.caml_pasta_fq_print

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

// Provides: caml_pasta_fq_random
// Requires: plonk_wasm
var caml_pasta_fq_random = plonk_wasm.caml_pasta_fq_random

// Provides: caml_pasta_fq_rng
// Requires: plonk_wasm
var caml_pasta_fq_rng = plonk_wasm.caml_pasta_fq_rng

// Provides: caml_pasta_fq_to_bigint
// Requires: plonk_wasm
var caml_pasta_fq_to_bigint = plonk_wasm.caml_pasta_fq_to_bigint

// Provides: caml_pasta_fq_of_bigint
// Requires: plonk_wasm
var caml_pasta_fq_of_bigint = plonk_wasm.caml_pasta_fq_of_bigint

// Provides: caml_pasta_fq_two_adic_root_of_unity
// Requires: plonk_wasm
var caml_pasta_fq_two_adic_root_of_unity = plonk_wasm.caml_pasta_fq_two_adic_root_of_unity

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

// Provides: caml_pasta_fq_deep_copy
// Requires: plonk_wasm
var caml_pasta_fq_deep_copy = plonk_wasm.caml_pasta_fq_deep_copy





// Provides: caml_u8array_vector_to_rust_flat_vector
var caml_u8array_vector_to_rust_flat_vector = function (v) {
    var i = 1; // The first entry is the OCaml tag for arrays
    var len = v.length - i;
    if (len === 0) {
        return new joo_global_object.Uint8Array(0);
    }
    var inner_len = v[i].length;
    var res = new joo_global_object.Uint8Array(len * inner_len);
    for (var pos = 0; i <= len; i++) {
        for (var j = 0; j < inner_len; j++, pos++) {
            res[pos] = v[i][j];
        }
    }
    return res;
};

// Provides: caml_u8array_vector_of_rust_flat_vector
var caml_u8array_vector_of_rust_flat_vector = function (v, inner_len) {
    var len = v.length;
    var output_len = len / inner_len;
    var res = new Array(output_len + 1)
    res[0] = 0 // OCaml tag before array contents, so that we can use this with arrays or vectors
    for (var i = 1, pos = 0; i <= output_len; i++) {
        var inner_res = new joo_global_object.Uint8Array(inner_len);
        for (var j = 0; j < inner_len; j++, pos++) {
            inner_res[j] = v[pos];
        }
        res[i] = inner_res;
    }
    return res;
};





// Provides: js_class_vector_to_rust_vector
var js_class_vector_to_rust_vector = function (v) {
    var len = v.length;
    var res = new joo_global_object.Uint32Array(len);
    for (var i = 0; i < len; i++) {
        // Beware: caller may need to do finalizer things to avoid these
        // pointers disappearing out from under us.
        res[i] = v[i].ptr;
    }
    return res;
};

// Provides: js_class_vector_of_rust_vector
var js_class_vector_of_rust_vector = function (v, klass) {
    var len = v.length;
    var res = new Array(len);
    for (var i = 0, pos = 0; i < len; i++) {
        // Beware: the caller may need to add finalizers to these.
        res[i] = klass.__wrap(v[i]);
    }
    return res;
};





// Provides: caml_pasta_fp_vector_create
var caml_pasta_fp_vector_create = function() {
    return [0]; // OCaml tag for arrays, so that we can use the same utility fns on both
};

// Provides: caml_pasta_fp_vector_length
var caml_pasta_fp_vector_length = function (v) {
    return v.length - 1;
};

// Provides: caml_pasta_fp_vector_emplace_back
var caml_pasta_fp_vector_emplace_back = function (v, x) {
    v.push(x);
}

// Provides: caml_pasta_fp_vector_get
var caml_pasta_fp_vector_get = function (v, i) {
    return new joo_global_object.Uint8Array(v[i+1]);
}

// Provides: caml_pasta_fp_vector_to_rust
// Requires: caml_u8array_vector_to_rust_flat_vector
var caml_pasta_fp_vector_to_rust = function (v) {
    return caml_u8array_vector_to_rust_flat_vector(v);
}

// Provides: caml_pasta_fp_vector_of_rust
// Requires: caml_u8array_vector_of_rust_flat_vector
var caml_pasta_fp_vector_of_rust = function (v) {
    // TODO: Hardcoding this is a little brittle
    return caml_u8array_vector_of_rust_flat_vector(v, 32);
}





// Provides: caml_pasta_fq_vector_create
var caml_pasta_fq_vector_create = function() {
    return [0]; // OCaml tag for arrays, so that we can use the same utility fns on both
};

// Provides: caml_pasta_fq_vector_length
var caml_pasta_fq_vector_length = function (v) {
    return v.length - 1;
};

// Provides: caml_pasta_fq_vector_emplace_back
var caml_pasta_fq_vector_emplace_back = function (v, x) {
    v.push(x);
}

// Provides: caml_pasta_fq_vector_get
var caml_pasta_fq_vector_get = function (v, i) {
    return new joo_global_object.Uint8Array(v[i+1]);
}

// Provides: caml_pasta_fq_vector_to_rust
// Requires: caml_u8array_vector_to_rust_flat_vector
var caml_pasta_fq_vector_to_rust = function (v) {
    return caml_u8array_vector_to_rust_flat_vector(v);
}

// Provides: caml_pasta_fq_vector_of_rust
// Requires: caml_u8array_vector_of_rust_flat_vector
var caml_pasta_fq_vector_of_rust = function (v) {
    // TODO: Hardcoding this is a little brittle
    return caml_u8array_vector_of_rust_flat_vector(v, 32);
}





// Provides: free_finalization_registry
var free_finalization_registry =
    new joo_global_object.FinalizationRegistry(function (instance_representative) {
        instance_representative.free();
    });

// Provides: free_on_finalize
// Requires: free_finalization_registry
var free_on_finalize = function (x) {
    // This is an unfortunate hack: we're creating a second instance of the
    // class to be able to call free on it. We can't pass the value itself,
    // since the registry holds a strong reference to the representative value.
    //
    // However, the class is only really a wrapper around a pointer, with a
    // reference to the class' prototype as its __prototype__.
    //
    // It might seem cleaner to call the destructor here on the pointer
    // directly, but unfortunately the destructor name is some mangled internal
    // string generated by wasm_bindgen. For now, this is the best,
    // least-brittle way to free once the original class instance gets collected.
    var instance_representative = x.constructor.__wrap(x.ptr)
    free_finalization_registry.register(x, instance_representative, x);
    return x;
};





// Provides: rust_affine_to_caml_affine
var rust_affine_to_caml_affine = function(pt) {
    var infinity = pt.infinity;
    if (infinity) {
        pt.free();
        return 0;
    } else {
        var x = pt.x;
        var y = pt.y;
        pt.free();
        return [0, [0, x, y]];
    }
};

// Provides: rust_affine_of_caml_affine
var rust_affine_of_caml_affine = function(pt, klass) {
    var res = new klass();
    if (pt === 0) {
        res.infinity = true;
    } else {
        // Layout is [0, [0, x, y]]
        // First 0 is the tag (it's the 0th constructor that takes arguments)
        // Second 0 is the block marker for the anonymous tuple arguments
        res.x = pt[1][1];
        res.y = pt[1][2];
    }
    return res;
};





// Provides: caml_pasta_pallas_one
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_pallas_one = function() {
    var res = plonk_wasm.caml_pasta_pallas_one();
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_pallas_add
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_pallas_add = function(x, y) {
    var res = plonk_wasm.caml_pasta_pallas_add(x, y);
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_pallas_sub
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_pallas_sub = function(x, y) {
    var res = plonk_wasm.caml_pasta_pallas_sub(x, y);
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_pallas_negate
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_pallas_negate = function(x) {
    var res = plonk_wasm.caml_pasta_pallas_negate(x);
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_pallas_double
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_pallas_double = function(x) {
    var res = plonk_wasm.caml_pasta_pallas_double(x);
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_pallas_scale
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_pallas_scale = function(x, y) {
    var res = plonk_wasm.caml_pasta_pallas_scale(x, y);
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_pallas_random
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_pallas_random = function() {
    var res = plonk_wasm.caml_pasta_pallas_random();
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_pallas_rng
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_pallas_rng = function(i) {
    var res = plonk_wasm.caml_pasta_pallas_rng(i);
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_pallas_to_affine
// Requires: plonk_wasm, rust_affine_to_caml_affine
var caml_pasta_pallas_to_affine = function(pt) {
    var res = plonk_wasm.caml_pasta_pallas_to_affine(pt);
    return rust_affine_to_caml_affine(res);
};

// Provides: caml_pasta_pallas_of_affine
// Requires: plonk_wasm, rust_affine_of_caml_affine, free_on_finalize
var caml_pasta_pallas_of_affine = function(pt) {
    var res = plonk_wasm.caml_pasta_pallas_of_affine(rust_affine_of_caml_affine(pt, plonk_wasm.caml_pasta_pallas_affine_one));
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_pallas_of_affine_coordinates
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_pallas_of_affine_coordinates = function(x, y) {
    var res = plonk_wasm.caml_pasta_pallas_of_affine_coordinates(x, y);
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_pallas_endo_base
// Requires: plonk_wasm
var caml_pasta_pallas_endo_base = plonk_wasm.caml_pasta_pallas_endo_base;

// Provides: caml_pasta_pallas_endo_scalar
// Requires: plonk_wasm
var caml_pasta_pallas_endo_scalar = plonk_wasm.caml_pasta_pallas_endo_scalar;

// Provides: caml_pasta_pallas_affine_deep_copy
// Requires: plonk_wasm, rust_affine_of_caml_affine, rust_affine_to_caml_affine
var caml_pasta_pallas_affine_deep_copy = function(pt) {
    return rust_affine_to_caml_affine(plonk_wasm.caml_pasta_pallas_affine_deep_copy(rust_affine_of_caml_affine(pt, plonk_wasm.caml_pasta_pallas_affine_one)));
};





// Provides: caml_pasta_vesta_one
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_vesta_one = function() {
    var res = plonk_wasm.caml_pasta_vesta_one();
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_vesta_add
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_vesta_add = function(x, y) {
    var res = plonk_wasm.caml_pasta_vesta_add(x, y);
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_vesta_sub
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_vesta_sub = function(x, y) {
    var res = plonk_wasm.caml_pasta_vesta_sub(x, y);
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_vesta_negate
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_vesta_negate = function(x) {
    var res = plonk_wasm.caml_pasta_vesta_negate(x);
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_vesta_double
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_vesta_double = function(x) {
    var res = plonk_wasm.caml_pasta_vesta_double(x);
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_vesta_scale
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_vesta_scale = function(x, y) {
    var res = plonk_wasm.caml_pasta_vesta_scale(x, y);
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_vesta_random
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_vesta_random = function() {
    var res = plonk_wasm.caml_pasta_vesta_random();
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_vesta_rng
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_vesta_rng = function(i) {
    var res = plonk_wasm.caml_pasta_vesta_rng(i);
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_vesta_to_affine
// Requires: plonk_wasm, rust_affine_to_caml_affine
var caml_pasta_vesta_to_affine = function(pt) {
    var res = plonk_wasm.caml_pasta_vesta_to_affine(pt);
    return rust_affine_to_caml_affine(res);
};

// Provides: caml_pasta_vesta_of_affine
// Requires: plonk_wasm, rust_affine_of_caml_affine, free_on_finalize
var caml_pasta_vesta_of_affine = function(pt) {
    var res = plonk_wasm.caml_pasta_vesta_of_affine(rust_affine_of_caml_affine(pt, plonk_wasm.caml_pasta_vesta_affine_one));
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_vesta_of_affine_coordinates
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_vesta_of_affine_coordinates = function(x, y) {
    var res = plonk_wasm.caml_pasta_vesta_of_affine_coordinates(x, y);
    free_on_finalize(res);
    return res;
};

// Provides: caml_pasta_vesta_endo_base
// Requires: plonk_wasm
var caml_pasta_vesta_endo_base = plonk_wasm.caml_pasta_vesta_endo_base;

// Provides: caml_pasta_vesta_endo_scalar
// Requires: plonk_wasm
var caml_pasta_vesta_endo_scalar = plonk_wasm.caml_pasta_vesta_endo_scalar;

// Provides: caml_pasta_vesta_affine_deep_copy
// Requires: plonk_wasm, rust_affine_of_caml_affine, rust_affine_to_caml_affine
var caml_pasta_vesta_affine_deep_copy = function(pt) {
    return rust_affine_to_caml_affine(plonk_wasm.caml_pasta_vesta_affine_deep_copy(rust_affine_of_caml_affine(pt, plonk_wasm.caml_pasta_vesta_affine_one)));
};




// Provides: caml_array_of_rust_vector
// Requires: js_class_vector_of_rust_vector
var caml_array_of_rust_vector = function(v, klass, convert, should_free) {
    var v = js_class_vector_of_rust_vector(v, klass);
    var len = v.length;
    var res = new Array(len+1);
    res[0] = 0; // OCaml tag before array contents
    for (var i=0; i < len; i++) {
        var rust_val = v[i];
        res[i+1] = convert(rust_val);
        if (should_free) { rust_val.free(); }
    }
    return res;
};

// Provides: caml_array_to_rust_vector
// Requires: js_class_vector_to_rust_vector, free_finalization_registry
var caml_array_to_rust_vector = function(v, convert, mk_new) {
    var v = v.slice(1); // Copy, dropping OCaml tag
    for (var i=0, l=v.length; i < l; i++) {
        var class_val = convert(v[i], mk_new);
        v[i] = class_val;
        // Don't free when GC runs; rust will free on its end.
        free_finalization_registry.unregister(class_val);
    }
    return js_class_vector_to_rust_vector(v);
}





// Provides: caml_poly_comm_of_rust_poly_comm
// Requires: rust_affine_to_caml_affine, caml_array_of_rust_vector
var caml_poly_comm_of_rust_poly_comm = function(poly_comm, klass, should_free) {
    var rust_shifted = poly_comm.shifted;
    var rust_unshifted = poly_comm.unshifted;
    var caml_shifted;
    if (rust_shifted === undefined) {
        caml_shifted = 0;
    } else {
        caml_shifted = [0, rust_affine_to_caml_affine(rust_shifted)];
    }
    var caml_unshifted = caml_array_of_rust_vector(rust_unshifted, klass, rust_affine_to_caml_affine, should_free);
    return [0, caml_unshifted, caml_shifted];
};

// Provides: caml_poly_comm_to_rust_poly_comm
// Requires: rust_affine_of_caml_affine, caml_array_to_rust_vector
var caml_poly_comm_to_rust_poly_comm = function(poly_comm, poly_comm_class, mk_affine) {
    var caml_unshifted = poly_comm[1];
    var caml_shifted = poly_comm[2];
    var rust_shifted = undefined;
    if (caml_shifted !== 0) {
        rust_shifted = rust_affine_of_caml_affine(caml_shifted[1], mk_affine);
    }
    var rust_unshifted = caml_array_to_rust_vector(caml_unshifted, rust_affine_of_caml_affine, mk_affine);
    return new poly_comm_class(rust_unshifted, rust_shifted);
};





// Provides: caml_pasta_vesta_poly_comm_of_rust
// Requires: plonk_wasm, caml_poly_comm_of_rust_poly_comm
var caml_pasta_vesta_poly_comm_of_rust = function(x) {
    return caml_poly_comm_of_rust_poly_comm(x, plonk_wasm.WasmVestaGAffine, false);
}

// Provides: caml_pasta_vesta_poly_comm_to_rust
// Requires: plonk_wasm, caml_poly_comm_to_rust_poly_comm
var caml_pasta_vesta_poly_comm_to_rust = function(x) {
    return caml_poly_comm_to_rust_poly_comm(x, plonk_wasm.WasmPastaVestaPolyComm, plonk_wasm.caml_pasta_vesta_affine_one);
}





// Provides: caml_pasta_pallas_poly_comm_of_rust
// Requires: plonk_wasm, caml_poly_comm_of_rust_poly_comm
var caml_pasta_pallas_poly_comm_of_rust = function(x) {
    return caml_poly_comm_of_rust_poly_comm(x, plonk_wasm.WasmPallasGAffine, false);
}

// Provides: caml_pasta_pallas_poly_comm_to_rust
// Requires: plonk_wasm, caml_poly_comm_to_rust_poly_comm
var caml_pasta_pallas_poly_comm_to_rust = function(x) {
    return caml_poly_comm_to_rust_poly_comm(x, plonk_wasm.WasmPastaPallasPolyComm, plonk_wasm.caml_pasta_pallas_affine_one);
}





// Provides: caml_pasta_fp_urs_create
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_fp_urs_create = function(i) {
    return free_on_finalize(plonk_wasm.caml_pasta_fp_urs_create(i));
};

// Provides: caml_pasta_fp_urs_write
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fp_urs_write = function(append, t, path) {
    if (append === 0) {
        append = undefined;
    } else {
        append = append[1];
    }
    return plonk_wasm.caml_pasta_fp_urs_write(append, t, caml_jsstring_of_string(path));
};

// Provides: caml_pasta_fp_urs_read
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fp_urs_read = function (offset, path) {
    if (offset === 0) {
        offset = undefined;
    } else {
        offset = offset[1];
    }
    var res = plonk_wasm.caml_pasta_fp_urs_read(offset, caml_jsstring_of_string(path));
    if (res) {
        return [0, res]; // Some(res)
    } else {
        return 0; // None
    }
};

// Provides: caml_pasta_fp_urs_lagrange_commitment
// Requires: plonk_wasm, caml_pasta_vesta_poly_comm_of_rust
var caml_pasta_fp_urs_lagrange_commitment = function (t, domain_size, i) {
    var res = plonk_wasm.caml_pasta_fp_urs_lagrange_commitment(t, domain_size, i);
    return caml_pasta_vesta_poly_comm_of_rust(res);
};

// Provides: caml_pasta_fp_urs_commit_evaluations
// Requires: plonk_wasm, caml_pasta_vesta_poly_comm_of_rust, caml_pasta_fp_vector_to_rust
var caml_pasta_fp_urs_commit_evaluations = function (t, domain_size, fps) {
    var res = plonk_wasm.caml_pasta_fp_urs_commit_evaluations(t, domain_size, caml_pasta_fp_vector_to_rust(fps));
    return caml_pasta_vesta_poly_comm_of_rust(res);
};

// Provides: caml_pasta_fp_urs_b_poly_commitment
// Requires: plonk_wasm, caml_pasta_vesta_poly_comm_of_rust
var caml_pasta_fp_urs_b_poly_commitment = function (t, domain_size, i) {
    var res = plonk_wasm.caml_pasta_fp_urs_b_poly_commitment(t, domain_size, i);
    return caml_pasta_vesta_poly_comm_of_rust(res);
};

// Provides: caml_pasta_fp_urs_batch_accumulator_check
// Requires: plonk_wasm, rust_affine_of_caml_affine, caml_array_to_rust_vector, caml_pasta_fp_vector_to_rust
var caml_pasta_fp_urs_batch_accumulator_check = function (t, affines, fields) {
    var rust_affines =
      caml_array_to_rust_vector(affines, rust_affine_of_caml_affine, plonk_wasm.caml_pasta_pallas_affine_one);
    var rust_fields = caml_pasta_fp_vector_to_rust(fields);
    return plonk_wasm.caml_pasta_fp_urs_batch_accumulator_check(t, rust_affines, rust_fields);
};

// Provides: caml_pasta_fp_urs_h
// Requires: plonk_wasm, rust_affine_to_caml_affine
var caml_pasta_fp_urs_h = function (t) {
    return rust_affine_to_caml_affine(plonk_wasm.caml_pasta_fp_urs_h(t));
};





// Provides: caml_pasta_fq_urs_create
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_fq_urs_create = function(i) {
    return free_on_finalize(plonk_wasm.caml_pasta_fq_urs_create(i));
};

// Provides: caml_pasta_fq_urs_write
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fq_urs_write = function(append, t, path) {
    if (append === 0) {
        append = undefined;
    } else {
        append = append[1];
    }
    return plonk_wasm.caml_pasta_fq_urs_write(append, t,  caml_jsstring_of_string(path));
};

// Provides: caml_pasta_fq_urs_read
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fq_urs_read = function (offset, path) {
    if (offset === 0) {
        offset = undefined;
    } else {
        offset = offset[1];
    }
    var res = plonk_wasm.caml_pasta_fq_urs_read(offset, caml_jsstring_of_string(path));
    if (res) {
        return [0, res]; // Some(res)
    } else {
        return 0; // None
    }
};

// Provides: caml_pasta_fq_urs_lagrange_commitment
// Requires: plonk_wasm, caml_pasta_pallas_poly_comm_of_rust
var caml_pasta_fq_urs_lagrange_commitment = function (t, domain_size, i) {
    var res = plonk_wasm.caml_pasta_fq_urs_lagrange_commitment(t, domain_size, i);
    return caml_pasta_pallas_poly_comm_of_rust(res);
};

// Provides: caml_pasta_fq_urs_commit_evaluations
// Requires: plonk_wasm, caml_pasta_pallas_poly_comm_of_rust, caml_pasta_fq_vector_to_rust
var caml_pasta_fq_urs_commit_evaluations = function (t, domain_size, fqs) {
    var res = plonk_wasm.caml_pasta_fq_urs_commit_evaluations(t, domain_size, caml_pasta_fq_vector_to_rust(fqs));
    return caml_pasta_pallas_poly_comm_of_rust(res);
};

// Provides: caml_pasta_fq_urs_b_poly_commitment
// Requires: plonk_wasm, caml_pasta_pallas_poly_comm_of_rust
var caml_pasta_fq_urs_b_poly_commitment = function (t, domain_size, i) {
    var res = plonk_wasm.caml_pasta_fq_urs_b_poly_commitment(t, domain_size, i);
    return caml_pasta_pallas_poly_comm_of_rust(res);
};

// Provides: caml_pasta_fq_urs_batch_accumulator_check
// Requires: plonk_wasm, rust_affine_of_caml_affine, caml_array_to_rust_vector, caml_pasta_fq_vector_to_rust
var caml_pasta_fq_urs_batch_accumulator_check = function (t, affines, fields) {
    var rust_affines =
      caml_array_to_rust_vector(affines, rust_affine_of_caml_affine, plonk_wasm.caml_pasta_pallas_affine_one);
    var rust_fields = caml_pasta_fq_vector_to_rust(fields);
    return plonk_wasm.caml_pasta_fq_urs_batch_accumulator_check(t, rust_affines, rust_fields);
};

// Provides: caml_pasta_fq_urs_h
// Requires: plonk_wasm, rust_affine_to_caml_affine
var caml_pasta_fq_urs_h = function (t) {
    return rust_affine_to_caml_affine(plonk_wasm.caml_pasta_fq_urs_h(t));
};





// Provides: caml_plonk_wire_of_rust
var caml_plonk_wire_of_rust = function(wire) {
    var res = [0, wire.row, wire.col];
    wire.free();
    return res;
};

// Provides: caml_plonk_wire_to_rust
// Requires: plonk_wasm
var caml_plonk_wire_to_rust = function(wire) {
    return new plonk_wasm.WasmPlonkWire(wire[1], wire[2]);
};

// Provides: caml_plonk_wires_of_rust
// Requires: caml_plonk_wire_of_rust
var caml_plonk_wires_of_rust = function(wires) {
    var res = [0, wires.row, caml_plonk_wire_of_rust(wires.l), caml_plonk_wire_of_rust(wires.r), caml_plonk_wire_of_rust(wires.o)];
    wires.free();
    return res;
};

// Provides: caml_plonk_wires_to_rust
// Requires: plonk_wasm, caml_plonk_wire_to_rust
var caml_plonk_wires_to_rust = function(wires) {
    return new plonk_wasm.WasmPlonkWires(wires[1], caml_plonk_wire_to_rust(wires[2]), caml_plonk_wire_to_rust(wires[3]), caml_plonk_wire_to_rust(wires[4]));
};

// Provides: caml_plonk_gate_of_rust
// Requires: caml_plonk_wires_of_rust, caml_u8array_vector_of_rust_flat_vector
var caml_plonk_gate_of_rust = function(gate) {
    // TODO: Hardcoding 32 here is a little brittle
    var res = [0, gate.typ, caml_plonk_wires_of_rust(gate.wires), caml_u8array_vector_of_rust_flat_vector(gate.c, 32)];
    gate.free();
    return res;
};

// Provides: caml_fp_plonk_gate_to_rust
// Requires: plonk_wasm, caml_plonk_wires_to_rust, caml_u8array_vector_to_rust_flat_vector
var caml_fp_plonk_gate_to_rust = function(gate) {
    return new plonk_wasm.WasmPastaFpPlonkGate(gate[1], caml_plonk_wires_to_rust(gate[2]), caml_u8array_vector_to_rust_flat_vector(gate[3]));
};

// Provides: caml_fq_plonk_gate_to_rust
// Requires: plonk_wasm, caml_plonk_wires_to_rust, caml_u8array_vector_to_rust_flat_vector
var caml_fq_plonk_gate_to_rust = function(gate) {
    // TODO: Hardcoding 32 here is a little brittle
    return new plonk_wasm.WasmPastaFqPlonkGate(gate[1], caml_plonk_wires_to_rust(gate[2]), caml_u8array_vector_to_rust_flat_vector(gate[3]))
};





// Provides: caml_pasta_fp_plonk_gate_vector_create
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_fp_plonk_gate_vector_create = function() {
    return free_on_finalize(plonk_wasm.caml_pasta_fp_plonk_gate_vector_create());
};

// Provides: caml_pasta_fp_plonk_gate_vector_add
// Requires: plonk_wasm, caml_fp_plonk_gate_to_rust
var caml_pasta_fp_plonk_gate_vector_add = function(v, x) {
    return plonk_wasm.caml_pasta_fp_plonk_gate_vector_add(v, caml_fp_plonk_gate_to_rust(x));
};

// Provides: caml_pasta_fp_plonk_gate_vector_get
// Requires: plonk_wasm, caml_plonk_gate_of_rust
var caml_pasta_fp_plonk_gate_vector_get = function(v, i) {
    return caml_plonk_gate_of_rust(plonk_wasm.caml_pasta_fp_plonk_gate_vector_get(v, i));
};

// Provides: caml_pasta_fp_plonk_gate_vector_wrap
// Requires: plonk_wasm, caml_plonk_wire_to_rust
var caml_pasta_fp_plonk_gate_vector_wrap = function(v, x, y) {
    return plonk_wasm.caml_pasta_fp_plonk_gate_vector_wrap(v, caml_plonk_wire_to_rust(x), caml_plonk_wire_to_rust(y));
};





// Provides: caml_pasta_fq_plonk_gate_vector_create
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_fq_plonk_gate_vector_create = function() {
    return free_on_finalize(plonk_wasm.caml_pasta_fq_plonk_gate_vector_create());
};

// Provides: caml_pasta_fq_plonk_gate_vector_add
// Requires: plonk_wasm, caml_fq_plonk_gate_to_rust
var caml_pasta_fq_plonk_gate_vector_add = function(v, x) {
    return plonk_wasm.caml_pasta_fq_plonk_gate_vector_add(v, caml_fq_plonk_gate_to_rust(x));
};

// Provides: caml_pasta_fq_plonk_gate_vector_get
// Requires: plonk_wasm, caml_plonk_gate_of_rust
var caml_pasta_fq_plonk_gate_vector_get = function(v, i) {
    return caml_plonk_gate_of_rust(plonk_wasm.caml_pasta_fq_plonk_gate_vector_get(v, i));
};

// Provides: caml_pasta_fq_plonk_gate_vector_wrap
// Requires: plonk_wasm, caml_plonk_wire_to_rust
var caml_pasta_fq_plonk_gate_vector_wrap = function(v, x, y) {
    return plonk_wasm.caml_pasta_fq_plonk_gate_vector_wrap(v, caml_plonk_wire_to_rust(x), caml_plonk_wire_to_rust(y));
};





// Provides: caml_pasta_fp_plonk_index_create
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_fp_plonk_index_create = function(gates, public_inputs, urs) {
    return free_on_finalize(plonk_wasm.caml_pasta_fp_plonk_index_create(gates, public_inputs, urs));
};

// Provides: caml_pasta_fp_plonk_index_max_degree
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_max_degree = plonk_wasm.caml_pasta_fp_plonk_index_max_degree;

// Provides: caml_pasta_fp_plonk_index_public_inputs
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_public_inputs = plonk_wasm.caml_pasta_fp_plonk_index_public_inputs;

// Provides: caml_pasta_fp_plonk_index_domain_d1_size
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_domain_d1_size = plonk_wasm.caml_pasta_fp_plonk_index_domain_d1_size;

// Provides: caml_pasta_fp_plonk_index_domain_d4_size
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_domain_d4_size = plonk_wasm.caml_pasta_fp_plonk_index_domain_d4_size;

// Provides: caml_pasta_fp_plonk_index_domain_d8_size
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_domain_d8_size = plonk_wasm.caml_pasta_fp_plonk_index_domain_d8_size;

// Provides: caml_pasta_fp_plonk_index_read
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fp_plonk_index_read = function (offset, urs, path) {
    if (offset === 0) {
        offset = undefined;
    } else {
        offset = offset[1];
    }
    return plonk_wasm.caml_pasta_fp_plonk_index_read(offset, urs, caml_jsstring_of_string(path));
};

// Provides: caml_pasta_fp_plonk_index_write
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fp_plonk_index_write = function(append, t, path) {
    if (append === 0) {
        append = undefined;
    } else {
        append = append[1];
    }
    return plonk_wasm.caml_pasta_fp_plonk_index_write(append, t, caml_jsstring_of_string(path));
};





// Provides: caml_pasta_fq_plonk_index_create
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_fq_plonk_index_create = function(gates, public_inputs, urs) {
    return free_on_finalize(plonk_wasm.caml_pasta_fq_plonk_index_create(gates, public_inputs, urs));
}

// Provides: caml_pasta_fq_plonk_index_max_degree
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_max_degree = plonk_wasm.caml_pasta_fq_plonk_index_max_degree;

// Provides: caml_pasta_fq_plonk_index_public_inputs
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_public_inputs = plonk_wasm.caml_pasta_fq_plonk_index_public_inputs;

// Provides: caml_pasta_fq_plonk_index_domain_d1_size
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_domain_d1_size = plonk_wasm.caml_pasta_fq_plonk_index_domain_d1_size;

// Provides: caml_pasta_fq_plonk_index_domain_d4_size
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_domain_d4_size = plonk_wasm.caml_pasta_fq_plonk_index_domain_d4_size;

// Provides: caml_pasta_fq_plonk_index_domain_d8_size
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_domain_d8_size = plonk_wasm.caml_pasta_fq_plonk_index_domain_d8_size;

// Provides: caml_pasta_fq_plonk_index_read
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fq_plonk_index_read = function (offset, urs, path) {
    if (offset === 0) {
        offset = undefined;
    } else {
        offset = offset[1];
    }
    return plonk_wasm.caml_pasta_fq_plonk_index_read(offset, urs, caml_jsstring_of_string(path));
};

// Provides: caml_pasta_fq_plonk_index_write
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fq_plonk_index_write = function(append, t, path) {
    if (append === 0) {
        append = undefined;
    } else {
        append = append[1];
    }
    return plonk_wasm.caml_pasta_fq_plonk_index_write(append, t, caml_jsstring_of_string(path));
};





// Provides: caml_plonk_domain_of_rust
var caml_plonk_domain_of_rust = function(x) {
    var log_size_of_group = x.log_size_of_group;
    var group_gen = x.group_gen;
    x.free();
    return [0, log_size_of_group, group_gen];
};

// Provides: caml_plonk_domain_to_rust
// Requires: free_on_finalize
var caml_plonk_domain_to_rust = function(x, klass) {
    // TODO: Check if this gets finalized
    return new klass(x[1], x[2]);
};

// Provides: caml_plonk_verification_evals_of_rust
// Requires: caml_poly_comm_of_rust_poly_comm
var caml_plonk_verification_evals_of_rust = function(x, affine_klass) {
    var convert = function(poly_comm) {
        return caml_poly_comm_of_rust_poly_comm(poly_comm, affine_klass, false);
    };
    var sigma_comm_0 = convert(x.sigma_comm0);
    var sigma_comm_1 = convert(x.sigma_comm1);
    var sigma_comm_2 = convert(x.sigma_comm2);
    var ql_comm = convert(x.ql_comm);
    var qr_comm = convert(x.qr_comm);
    var qo_comm = convert(x.qo_comm);
    var qm_comm = convert(x.qm_comm);
    var qc_comm = convert(x.qc_comm);
    var rcm_comm_0 = convert(x.rcm_comm0);
    var rcm_comm_1 = convert(x.rcm_comm1);
    var rcm_comm_2 = convert(x.rcm_comm2);
    var psm_comm = convert(x.psm_comm);
    var add_comm = convert(x.add_comm);
    var mul1_comm = convert(x.mul1_comm);
    var mul2_comm = convert(x.mul2_comm);
    var emul1_comm = convert(x.emul1_comm);
    var emul2_comm = convert(x.emul2_comm);
    var emul3_comm = convert(x.emul3_comm);
    x.free();
    return [ 0
      , sigma_comm_0
      , sigma_comm_1
      , sigma_comm_2
      , ql_comm
      , qr_comm
      , qo_comm
      , qm_comm
      , qc_comm
      , rcm_comm_0
      , rcm_comm_1
      , rcm_comm_2
      , psm_comm
      , add_comm
      , mul1_comm
      , mul2_comm
      , emul1_comm
      , emul2_comm
      , emul3_comm ];
};

// Provides: caml_plonk_verification_evals_to_rust
// Requires: caml_poly_comm_to_rust_poly_comm
var caml_plonk_verification_evals_to_rust = function(x, klass, poly_comm_class, mk_affine) {
    var convert = function(poly_comm) {
        return caml_poly_comm_to_rust_poly_comm(poly_comm, poly_comm_class, mk_affine);
    };
    var sigma_comm_0 = convert(x[1]);
    var sigma_comm_1 = convert(x[2]);
    var sigma_comm_2 = convert(x[3]);
    var ql_comm = convert(x[4]);
    var qr_comm = convert(x[5]);
    var qo_comm = convert(x[6]);
    var qm_comm = convert(x[7]);
    var qc_comm = convert(x[8]);
    var rcm_comm_0 = convert(x[9]);
    var rcm_comm_1 = convert(x[10]);
    var rcm_comm_2 = convert(x[11]);
    var psm_comm = convert(x[12]);
    var add_comm = convert(x[13]);
    var mul1_comm = convert(x[14]);
    var mul2_comm = convert(x[15]);
    var emul1_comm = convert(x[16]);
    var emul2_comm = convert(x[17]);
    var emul3_comm = convert(x[18]);
    return new klass(
        sigma_comm_0
      , sigma_comm_1
      , sigma_comm_2
      , ql_comm
      , qr_comm
      , qo_comm
      , qm_comm
      , qc_comm
      , rcm_comm_0
      , rcm_comm_1
      , rcm_comm_2
      , psm_comm
      , add_comm
      , mul1_comm
      , mul2_comm
      , emul1_comm
      , emul2_comm
      , emul3_comm );
};

// Provides: caml_plonk_verification_shifts_of_rust
var caml_plonk_verification_shifts_of_rust = function(x) {
    var r = x.r;
    var o = x.o;
    x.free();
    return [0, r, o];
};

// Provides: caml_plonk_verification_shifts_to_rust
var caml_plonk_verification_shifts_to_rust = function(x, klass) {
    return new klass(x[1], x[2]);
};

// Provides: caml_plonk_verifier_index_of_rust
// Requires: caml_plonk_domain_of_rust, caml_plonk_verification_evals_of_rust, caml_plonk_verification_shifts_of_rust, free_on_finalize
var caml_plonk_verifier_index_of_rust = function(x, affine_class) {
  var domain = caml_plonk_domain_of_rust(x.domain);
  var max_poly_size = x.max_poly_size;
  var max_quot_size = x.max_quot_size;
  var urs = free_on_finalize(x.urs);
  var evals = caml_plonk_verification_evals_of_rust(x.evals, affine_class);
  var shifts = caml_plonk_verification_shifts_of_rust(x.shifts);
  x.free();
  return [0, domain, max_poly_size, max_quot_size, urs, evals, shifts];
};

// Provides: caml_plonk_verifier_index_to_rust
// Requires: caml_plonk_domain_to_rust, caml_plonk_verification_evals_to_rust, caml_plonk_verification_shifts_to_rust, free_finalization_registry
var caml_plonk_verifier_index_to_rust = function(x, klass, domain_class, verification_evals_class, poly_comm_class, mk_affine, verification_shifts_class) {
  var domain = caml_plonk_domain_to_rust(x[1], domain_class);
  var max_poly_size = x[2];
  var max_quot_size = x[3];
  var urs = x[4];
  var evals = caml_plonk_verification_evals_to_rust(x[5], verification_evals_class, poly_comm_class, mk_affine);
  var shifts = caml_plonk_verification_shifts_to_rust(x[6], verification_shifts_class);
  return new klass(domain, max_poly_size, max_quot_size, urs, evals, shifts);
};





// Provides: caml_pasta_fp_plonk_verifier_index_of_rust
// Requires: plonk_wasm, caml_plonk_verifier_index_of_rust
var caml_pasta_fp_plonk_verifier_index_of_rust = function(x) {
    return caml_plonk_verifier_index_of_rust(x, plonk_wasm.WasmVestaGAffine);
};

// Provides: caml_pasta_fp_plonk_verifier_index_to_rust
// Requires: plonk_wasm, caml_plonk_verifier_index_to_rust
var caml_pasta_fp_plonk_verifier_index_to_rust = function(x) {
    return caml_plonk_verifier_index_to_rust(x, plonk_wasm.WasmPastaFpPlonkVerifierIndex, plonk_wasm.WasmPastaFpPlonkDomain, plonk_wasm.WasmPastaFpPlonkVerificationEvals, plonk_wasm.WasmPastaVestaPolyComm, plonk_wasm.caml_pasta_vesta_affine_one, plonk_wasm.WasmPastaFpPlonkVerificationShifts);
};

// Provides: caml_pasta_fp_plonk_verifier_index_create
// Requires: plonk_wasm, caml_pasta_fp_plonk_verifier_index_of_rust
var caml_pasta_fp_plonk_verifier_index_create = function(x) {
    return caml_pasta_fp_plonk_verifier_index_of_rust(plonk_wasm.caml_pasta_fp_plonk_verifier_index_create(x));
};

// Provides: caml_pasta_fp_plonk_verifier_index_read
// Requires: plonk_wasm, caml_jsstring_of_string, caml_pasta_fp_plonk_verifier_index_of_rust
var caml_pasta_fp_plonk_verifier_index_read = function (offset, urs, path) {
    if (offset === 0) {
        offset = undefined;
    } else {
        offset = offset[1];
    }
    return caml_pasta_fp_plonk_verifier_index_of_rust(plonk_wasm.caml_pasta_fp_plonk_verifier_index_read(offset, urs, caml_jsstring_of_string(path)));
};

// Provides: caml_pasta_fp_plonk_verifier_index_write
// Requires: plonk_wasm, caml_jsstring_of_string, caml_pasta_fp_plonk_verifier_index_to_rust
var caml_pasta_fp_plonk_verifier_index_write = function (append, t, path) {
    if (append === 0) {
        append = undefined;
    } else {
        append = append[1];
    }
    return plonk_wasm.caml_pasta_fp_plonk_verifier_index_write(append, caml_pasta_fp_plonk_verifier_index_to_rust(t), caml_jsstring_of_string(path));
};

// Provides: caml_pasta_fp_plonk_verifier_index_shifts
// Requires: plonk_wasm, caml_plonk_verification_shifts_of_rust
var caml_pasta_fp_plonk_verifier_index_shifts = function(log2_size) {
    return caml_plonk_verification_shifts_of_rust(plonk_wasm.caml_pasta_fp_plonk_verifier_index_shifts(log2_size));
};

// Provides: caml_pasta_fp_plonk_verifier_index_dummy
// Requires: plonk_wasm, caml_pasta_fp_plonk_verifier_index_of_rust
var caml_pasta_fp_plonk_verifier_index_dummy = function() {
    var res = plonk_wasm.caml_pasta_fp_plonk_verifier_index_dummy();
    return caml_pasta_fp_plonk_verifier_index_of_rust(res);
    return caml_pasta_fp_plonk_verifier_index_of_rust(plonk_wasm.caml_pasta_fp_plonk_verifier_index_dummy());
};

// Provides: caml_pasta_fp_plonk_verifier_index_deep_copy
// Requires: plonk_wasm, caml_pasta_fp_plonk_verifier_index_of_rust, caml_pasta_fp_plonk_verifier_index_to_rust
var caml_pasta_fp_plonk_verifier_index_deep_copy = function(x) {
    return caml_pasta_fp_plonk_verifier_index_of_rust(plonk_wasm.caml_pasta_fp_plonk_verifier_index_deep_copy(caml_pasta_fp_plonk_verifier_index_to_rust(x)));
};





// Provides: caml_pasta_fq_plonk_verifier_index_of_rust
// Requires: plonk_wasm, caml_plonk_verifier_index_of_rust
var caml_pasta_fq_plonk_verifier_index_of_rust = function(x) {
    return caml_plonk_verifier_index_of_rust(x, plonk_wasm.WasmPallasGAffine);
};

// Provides: caml_pasta_fq_plonk_verifier_index_to_rust
// Requires: plonk_wasm, caml_plonk_verifier_index_to_rust
var caml_pasta_fq_plonk_verifier_index_to_rust = function(x) {
    return caml_plonk_verifier_index_to_rust(x, plonk_wasm.WasmPastaFqPlonkVerifierIndex, plonk_wasm.WasmPastaFqPlonkDomain, plonk_wasm.WasmPastaFqPlonkVerificationEvals, plonk_wasm.WasmPastaPallasPolyComm, plonk_wasm.caml_pasta_pallas_affine_one, plonk_wasm.WasmPastaFqPlonkVerificationShifts);
};

// Provides: caml_pasta_fq_plonk_verifier_index_create
// Requires: plonk_wasm, caml_pasta_fq_plonk_verifier_index_of_rust
var caml_pasta_fq_plonk_verifier_index_create = function(x) {
    return caml_pasta_fq_plonk_verifier_index_of_rust(plonk_wasm.caml_pasta_fq_plonk_verifier_index_create(x));
};

// Provides: caml_pasta_fq_plonk_verifier_index_read
// Requires: plonk_wasm, caml_jsstring_of_string, caml_pasta_fq_plonk_verifier_index_of_rust
var caml_pasta_fq_plonk_verifier_index_read = function (offset, urs, path) {
    if (offset === 0) {
        offset = undefined;
    } else {
        offset = offset[1];
    }
    return caml_pasta_fq_plonk_verifier_index_of_rust(plonk_wasm.caml_pasta_fq_plonk_verifier_index_read(offset, urs, caml_jsstring_of_string(path)));
};

// Provides: caml_pasta_fq_plonk_verifier_index_write
// Requires: plonk_wasm, caml_jsstring_of_string, caml_pasta_fq_plonk_verifier_index_to_rust
var caml_pasta_fq_plonk_verifier_index_write = function (append, t, path) {
    if (append === 0) {
        append = undefined;
    } else {
        append = append[1];
    }
    return plonk_wasm.caml_pasta_fq_plonk_verifier_index_write(append, caml_pasta_fq_plonk_verifier_index_to_rust(t), caml_jsstring_of_string(path));
};

// Provides: caml_pasta_fq_plonk_verifier_index_shifts
// Requires: plonk_wasm, caml_plonk_verification_shifts_of_rust
var caml_pasta_fq_plonk_verifier_index_shifts = function(log2_size) {
    return caml_plonk_verification_shifts_of_rust(plonk_wasm.caml_pasta_fq_plonk_verifier_index_shifts(log2_size));
};

// Provides: caml_pasta_fq_plonk_verifier_index_dummy
// Requires: plonk_wasm, caml_pasta_fq_plonk_verifier_index_of_rust
var caml_pasta_fq_plonk_verifier_index_dummy = function() {
    return caml_pasta_fq_plonk_verifier_index_of_rust(plonk_wasm.caml_pasta_fq_plonk_verifier_index_dummy());
};

// Provides: caml_pasta_fq_plonk_verifier_index_deep_copy
// Requires: plonk_wasm, caml_pasta_fq_plonk_verifier_index_of_rust, caml_pasta_fq_plonk_verifier_index_to_rust
var caml_pasta_fq_plonk_verifier_index_deep_copy = function(x) {
    return caml_pasta_fq_plonk_verifier_index_of_rust(plonk_wasm.caml_pasta_fq_plonk_verifier_index_deep_copy(caml_pasta_fq_plonk_verifier_index_to_rust(x)));
};





// Provides: caml_pasta_fp_proof_evaluations_to_rust
// Requires: plonk_wasm, caml_pasta_fp_vector_to_rust
var caml_pasta_fp_proof_evaluations_to_rust = function(x) {
    var l = caml_pasta_fp_vector_to_rust(x[1]);
    var r = caml_pasta_fp_vector_to_rust(x[2]);
    var o = caml_pasta_fp_vector_to_rust(x[3]);
    var z = caml_pasta_fp_vector_to_rust(x[4]);
    var t = caml_pasta_fp_vector_to_rust(x[5]);
    var f = caml_pasta_fp_vector_to_rust(x[6]);
    var sigma1 = caml_pasta_fp_vector_to_rust(x[7]);
    var sigma2 = caml_pasta_fp_vector_to_rust(x[8]);
    return new plonk_wasm.WasmPastaFpProofEvaluations(l, r, o, z, t, f, sigma1, sigma2);
};

// Provides: caml_pasta_fp_proof_evaluations_of_rust
// Requires: plonk_wasm, caml_pasta_fp_vector_of_rust
var caml_pasta_fp_proof_evaluations_of_rust = function(x) {
    var l = caml_pasta_fp_vector_of_rust(x.l);
    var r = caml_pasta_fp_vector_of_rust(x.r);
    var o = caml_pasta_fp_vector_of_rust(x.o);
    var z = caml_pasta_fp_vector_of_rust(x.z);
    var t = caml_pasta_fp_vector_of_rust(x.t);
    var f = caml_pasta_fp_vector_of_rust(x.f);
    var sigma1 = caml_pasta_fp_vector_of_rust(x.sigma1);
    var sigma2 = caml_pasta_fp_vector_of_rust(x.sigma2);
    x.free();
    return [0, l, r, o, z, t, f, sigma1, sigma2];
};

// Provides: caml_pasta_fp_opening_proof_to_rust
// Requires: plonk_wasm, caml_array_to_rust_vector, rust_affine_of_caml_affine
var caml_pasta_fp_opening_proof_to_rust = function(x) {
    var convert_affines = function(affines) {
        return caml_array_to_rust_vector(affines, rust_affine_of_caml_affine, plonk_wasm.caml_pasta_vesta_affine_one);
    }
    var lr = x[1];
    var delta = rust_affine_of_caml_affine(x[2], plonk_wasm.caml_pasta_vesta_affine_one);
    var z1 = x[3];
    var z2 = x[4];
    var sg = rust_affine_of_caml_affine(x[5], plonk_wasm.caml_pasta_vesta_affine_one);
    var len = lr.length;
    // We pass l and r as separate vectors over the FFI
    var l_ocaml = new Array(len);
    var r_ocaml = new Array(len);
    for (var i = 1; i < len; i++) {
        l_ocaml[i] = lr[i][1];
        r_ocaml[i] = lr[i][2];
    }
    var l = convert_affines(l_ocaml);
    var r = convert_affines(r_ocaml);
    return new plonk_wasm.WasmPastaFpOpeningProof(l, r, delta, z1, z2, sg);
};

// Provides: caml_pasta_fp_opening_proof_of_rust
// Requires: plonk_wasm, caml_array_of_rust_vector, rust_affine_to_caml_affine
var caml_pasta_fp_opening_proof_of_rust = function(x) {
    var convert_affines = function(affines) {
        return caml_array_of_rust_vector(affines, plonk_wasm.WasmVestaGAffine, rust_affine_to_caml_affine, false);
    }
    var l = convert_affines(x.lr_0);
    var r = convert_affines(x.lr_1);
    var delta = rust_affine_to_caml_affine(x.delta);
    var z1 = x.z1;
    var z2 = x.z2;
    var sg = rust_affine_to_caml_affine(x.sg);
    x.free();
    var len = l.length;
    if (len !== r.length) { throw new Error("l and r lengths don't match"); }
    var lr = new Array(len);
    lr[0] = 0;
    for (var i = 1; i < len; i++) {
        var tuple = new Array(3);
        tuple[0] = 0;
        tuple[1] = l[i];
        tuple[2] = r[i];
        lr[i] = tuple;
    }
    return [0, lr, delta, z1, z2, sg];
};

// Provides: caml_pasta_fp_messages_to_rust
// Requires: plonk_wasm, caml_pasta_vesta_poly_comm_to_rust
var caml_pasta_fp_messages_to_rust = function(x) {
    var l_comm = caml_pasta_vesta_poly_comm_to_rust(x[1]);
    var r_comm = caml_pasta_vesta_poly_comm_to_rust(x[2]);
    var o_comm = caml_pasta_vesta_poly_comm_to_rust(x[3]);
    var z_comm = caml_pasta_vesta_poly_comm_to_rust(x[4]);
    var t_comm = caml_pasta_vesta_poly_comm_to_rust(x[5]);
    return new plonk_wasm.WasmPastaFpProverCommitments(l_comm, r_comm, o_comm, z_comm, t_comm);
};

// Provides: caml_pasta_fp_messages_of_rust
// Requires: caml_pasta_vesta_poly_comm_of_rust
var caml_pasta_fp_messages_of_rust = function(x) {
    var l_comm = caml_pasta_vesta_poly_comm_of_rust(x.l_comm);
    var r_comm = caml_pasta_vesta_poly_comm_of_rust(x.r_comm);
    var o_comm = caml_pasta_vesta_poly_comm_of_rust(x.o_comm);
    var z_comm = caml_pasta_vesta_poly_comm_of_rust(x.z_comm);
    var t_comm = caml_pasta_vesta_poly_comm_of_rust(x.t_comm);
    x.free();
    return [0, l_comm, r_comm, o_comm, z_comm, t_comm];
};

// Provides: caml_pasta_fp_proof_to_rust
// Requires: plonk_wasm, caml_pasta_fp_messages_to_rust, caml_pasta_fp_opening_proof_to_rust, caml_pasta_fp_proof_evaluations_to_rust, caml_pasta_fp_vector_to_rust, caml_pasta_vesta_poly_comm_to_rust, js_class_vector_to_rust_vector
var caml_pasta_fp_proof_to_rust = function(x) {
    var messages = caml_pasta_fp_messages_to_rust(x[1]);
    var proof = caml_pasta_fp_opening_proof_to_rust(x[2]);
    var evals0 = caml_pasta_fp_proof_evaluations_to_rust(x[3][1]);
    var evals1 = caml_pasta_fp_proof_evaluations_to_rust(x[3][2]);
    var public_ = caml_pasta_fp_vector_to_rust(x[4]);
    var prev_challenges = x[5];
    var chals_len = prev_challenges.length;
    var prev_challenges_scalars = new plonk_wasm.WasmVecVecPastaFp(chals_len - 1);
    var prev_challenges_comms = new Array(chals_len-1);
    for (var i = 1; i < chals_len; i++) {
        prev_challenges_scalars.push(caml_pasta_fp_vector_to_rust(prev_challenges[i][1]));
        prev_challenges_comms[i-1] = caml_pasta_vesta_poly_comm_to_rust(prev_challenges[i][2]);
    }
    prev_challenges_comms = js_class_vector_to_rust_vector(prev_challenges_comms);
    return new plonk_wasm.WasmPastaFpProverProof(messages, proof, evals0, evals1, public_, prev_challenges_scalars, prev_challenges_comms);
};

// Provides: caml_pasta_fp_proof_of_rust
// Requires: plonk_wasm, caml_pasta_fp_messages_of_rust, caml_pasta_fp_opening_proof_of_rust, caml_pasta_fp_proof_evaluations_of_rust, caml_pasta_fp_vector_of_rust, js_class_vector_of_rust_vector, caml_pasta_vesta_poly_comm_of_rust
var caml_pasta_fp_proof_of_rust = function(x) {
    var messages = caml_pasta_fp_messages_of_rust(x.commitments);
    var proof = caml_pasta_fp_opening_proof_of_rust(x.proof);
    var evals0 = caml_pasta_fp_proof_evaluations_of_rust(x.evals0);
    var evals1 = caml_pasta_fp_proof_evaluations_of_rust(x.evals1);
    var public_ = caml_pasta_fp_vector_of_rust(x.public_);
    var prev_challenges_scalars = x.prev_challenges_scalars;
    var prev_challenges_comms = js_class_vector_of_rust_vector(x.prev_challenges_comms, plonk_wasm.WasmPastaVestaPolyComm);
    var chals_len = prev_challenges_comms.length;
    var prev_challenges = new Array(chals_len);
    prev_challenges[0] = 0;
    for (var i = 1; i < chals_len; i++) {
        var res = new Array(3);
        res[0] = 0;
        res[1] = caml_pasta_fp_vector_of_rust(prev_challenges_scalars.get(i-1));
        res[2] = caml_pasta_vesta_poly_comm_of_rust(prev_challenges_comms[i]);
        prev_challenges[i] = res;
    }
    return [0, messages, proof, [0, evals0, evals1], public_, prev_challenges];
};

// Provides: caml_pasta_fp_plonk_proof_create
// Requires: plonk_wasm, caml_pasta_fp_vector_to_rust, caml_array_to_rust_vector, rust_affine_of_caml_affine, caml_pasta_fp_proof_of_rust
var caml_pasta_fp_plonk_proof_create = function(index, primary_input, auxiliary_input, prev_challenges, prev_sgs) {
    primary_input = caml_pasta_fp_vector_to_rust(primary_input);
    auxiliary_input = caml_pasta_fp_vector_to_rust(auxiliary_input);
    prev_challenges = caml_pasta_fp_vector_to_rust(prev_challenges);
    prev_sgs = caml_array_to_rust_vector(prev_sgs, rust_affine_of_caml_affine, plonk_wasm.caml_pasta_vesta_affine_one);
    var res = plonk_wasm.caml_pasta_fp_plonk_proof_create(index, primary_input, auxiliary_input, prev_challenges, prev_sgs);
    return caml_pasta_fp_proof_of_rust(res);
};

// Provides: caml_pasta_fp_plonk_proof_verify
// Requires: plonk_wasm, caml_array_to_rust_vector, caml_pasta_vesta_poly_comm_to_rust, caml_pasta_fp_plonk_verifier_index_to_rust, caml_pasta_fp_proof_to_rust
var caml_pasta_fp_plonk_proof_verify = function(lgr_comm, index, proof) {
    lgr_comm = caml_array_to_rust_vector(lgr_comm, caml_pasta_vesta_poly_comm_to_rust);
    index = caml_pasta_fp_plonk_verifier_index_to_rust(index);
    proof = caml_pasta_fp_proof_to_rust(proof);
    return plonk_wasm.caml_pasta_fp_plonk_proof_verify(lgr_comm, index, proof);
};

// Provides: caml_pasta_fp_plonk_proof_batch_verify
// Requires: plonk_wasm, caml_array_to_rust_vector, caml_pasta_vesta_poly_comm_to_rust, caml_pasta_fp_plonk_verifier_index_to_rust, caml_pasta_fp_proof_to_rust
var caml_pasta_fp_plonk_proof_batch_verify = function(lgr_comm, indexes, proofs) {
    var lgr_len = lgr_comm.length;
    var rust_lgr_comm = new plonk_wasm.WasmVecVecVestaPolyComm(lgr_len-1);
    for (var i = 1; i < lgr_len; i++) {
        rust_lgr_comm.push(caml_array_to_rust_vector(lgr_comm[i], caml_pasta_vesta_poly_comm_to_rust));
    }
    indexes = caml_array_to_rust_vector(indexes, caml_pasta_fp_plonk_verifier_index_to_rust);
    proofs = caml_array_to_rust_vector(proofs, caml_pasta_fp_proof_to_rust);
    return plonk_wasm.caml_pasta_fp_plonk_proof_batch_verify(rust_lgr_comm, indexes, proofs);
};

// Provides: caml_pasta_fp_plonk_proof_dummy
// Requires: plonk_wasm, caml_pasta_fp_proof_of_rust
var caml_pasta_fp_plonk_proof_dummy = function() {
    return caml_pasta_fp_proof_of_rust(plonk_wasm.caml_pasta_fp_plonk_proof_dummy());
};

// Provides: caml_pasta_fp_plonk_proof_deep_copy
// Requires: plonk_wasm, caml_pasta_fp_proof_to_rust, caml_pasta_fp_proof_of_rust
var caml_pasta_fp_plonk_proof_deep_copy = function(proof) {
    return caml_pasta_fp_proof_of_rust(plonk_wasm.caml_pasta_fp_plonk_proof_deep_copy(caml_pasta_fp_proof_to_rust(proof)));
};





// Provides: caml_pasta_fq_proof_evaluations_to_rust
// Requires: plonk_wasm, caml_pasta_fq_vector_to_rust
var caml_pasta_fq_proof_evaluations_to_rust = function(x) {
    var l = caml_pasta_fq_vector_to_rust(x[1]);
    var r = caml_pasta_fq_vector_to_rust(x[2]);
    var o = caml_pasta_fq_vector_to_rust(x[3]);
    var z = caml_pasta_fq_vector_to_rust(x[4]);
    var t = caml_pasta_fq_vector_to_rust(x[5]);
    var f = caml_pasta_fq_vector_to_rust(x[6]);
    var sigma1 = caml_pasta_fq_vector_to_rust(x[7]);
    var sigma2 = caml_pasta_fq_vector_to_rust(x[8]);
    return new plonk_wasm.WasmPastaFqProofEvaluations(l, r, o, z, t, f, sigma1, sigma2);
};

// Provides: caml_pasta_fq_proof_evaluations_of_rust
// Requires: plonk_wasm, caml_pasta_fq_vector_of_rust
var caml_pasta_fq_proof_evaluations_of_rust = function(x) {
    var l = caml_pasta_fq_vector_of_rust(x.l);
    var r = caml_pasta_fq_vector_of_rust(x.r);
    var o = caml_pasta_fq_vector_of_rust(x.o);
    var z = caml_pasta_fq_vector_of_rust(x.z);
    var t = caml_pasta_fq_vector_of_rust(x.t);
    var f = caml_pasta_fq_vector_of_rust(x.f);
    var sigma1 = caml_pasta_fq_vector_of_rust(x.sigma1);
    var sigma2 = caml_pasta_fq_vector_of_rust(x.sigma2);
    x.free();
    return [0, l, r, o, z, t, f, sigma1, sigma2];
};

// Provides: caml_pasta_fq_opening_proof_to_rust
// Requires: plonk_wasm, caml_array_to_rust_vector, rust_affine_of_caml_affine
var caml_pasta_fq_opening_proof_to_rust = function(x) {
    var convert_affines = function(affines) {
        return caml_array_to_rust_vector(affines, rust_affine_of_caml_affine, plonk_wasm.caml_pasta_pallas_affine_one);
    }
    var lr = x[1];
    var delta = rust_affine_of_caml_affine(x[2], plonk_wasm.caml_pasta_pallas_affine_one);
    var z1 = x[3];
    var z2 = x[4];
    var sg = rust_affine_of_caml_affine(x[5], plonk_wasm.caml_pasta_pallas_affine_one);
    var len = lr.length;
    // We pass l and r as separate vectors over the FFI
    var l_ocaml = new Array(len);
    var r_ocaml = new Array(len);
    for (var i = 1; i < len; i++) {
        l_ocaml[i] = lr[i][1];
        r_ocaml[i] = lr[i][2];
    }
    var l = convert_affines(l_ocaml);
    var r = convert_affines(r_ocaml);
    return new plonk_wasm.WasmPastaFqOpeningProof(l, r, delta, z1, z2, sg);
};

// Provides: caml_pasta_fq_opening_proof_of_rust
// Requires: plonk_wasm, caml_array_of_rust_vector, rust_affine_to_caml_affine
var caml_pasta_fq_opening_proof_of_rust = function(x) {
    var convert_affines = function(affines) {
        return caml_array_of_rust_vector(affines, plonk_wasm.WasmPallasGAffine, rust_affine_to_caml_affine, false);
    }
    var l = convert_affines(x.lr_0);
    var r = convert_affines(x.lr_1);
    var delta = rust_affine_to_caml_affine(x.delta);
    var z1 = x.z1;
    var z2 = x.z2;
    var sg = rust_affine_to_caml_affine(x.sg);
    x.free();
    var len = l.length;
    if (len !== r.length) { throw new Error("l and r lengths don't match"); }
    var lr = new Array(len);
    lr[0] = 0;
    for (var i = 1; i < len; i++) {
        var tuple = new Array(3);
        tuple[0] = 0;
        tuple[1] = l[i];
        tuple[2] = r[i];
        lr[i] = tuple;
    }
    return [0, lr, delta, z1, z2, sg];
};

// Provides: caml_pasta_fq_messages_to_rust
// Requires: plonk_wasm, caml_pasta_pallas_poly_comm_to_rust
var caml_pasta_fq_messages_to_rust = function(x) {
    var l_comm = caml_pasta_pallas_poly_comm_to_rust(x[1]);
    var r_comm = caml_pasta_pallas_poly_comm_to_rust(x[2]);
    var o_comm = caml_pasta_pallas_poly_comm_to_rust(x[3]);
    var z_comm = caml_pasta_pallas_poly_comm_to_rust(x[4]);
    var t_comm = caml_pasta_pallas_poly_comm_to_rust(x[5]);
    return new plonk_wasm.WasmPastaFqProverCommitments(l_comm, r_comm, o_comm, z_comm, t_comm);
};

// Provides: caml_pasta_fq_messages_of_rust
// Requires: caml_pasta_pallas_poly_comm_of_rust
var caml_pasta_fq_messages_of_rust = function(x) {
    var l_comm = caml_pasta_pallas_poly_comm_of_rust(x.l_comm);
    var r_comm = caml_pasta_pallas_poly_comm_of_rust(x.r_comm);
    var o_comm = caml_pasta_pallas_poly_comm_of_rust(x.o_comm);
    var z_comm = caml_pasta_pallas_poly_comm_of_rust(x.z_comm);
    var t_comm = caml_pasta_pallas_poly_comm_of_rust(x.t_comm);
    x.free();
    return [0, l_comm, r_comm, o_comm, z_comm, t_comm];
};

// Provides: caml_pasta_fq_proof_to_rust
// Requires: plonk_wasm, caml_pasta_fq_messages_to_rust, caml_pasta_fq_opening_proof_to_rust, caml_pasta_fq_proof_evaluations_to_rust, caml_pasta_fq_vector_to_rust, caml_pasta_pallas_poly_comm_to_rust, js_class_vector_to_rust_vector
var caml_pasta_fq_proof_to_rust = function(x) {
    var messages = caml_pasta_fq_messages_to_rust(x[1]);
    var proof = caml_pasta_fq_opening_proof_to_rust(x[2]);
    var evals0 = caml_pasta_fq_proof_evaluations_to_rust(x[3][1]);
    var evals1 = caml_pasta_fq_proof_evaluations_to_rust(x[3][2]);
    var public_ = caml_pasta_fq_vector_to_rust(x[4]);
    var prev_challenges = x[5];
    var chals_len = prev_challenges.length;
    var prev_challenges_scalars = new plonk_wasm.WasmVecVecPastaFq(chals_len - 1);
    var prev_challenges_comms = new Array(chals_len-1);
    for (var i = 1; i < chals_len; i++) {
        prev_challenges_scalars.push(caml_pasta_fq_vector_to_rust(prev_challenges[i][1]));
        prev_challenges_comms[i-1] = caml_pasta_pallas_poly_comm_to_rust(prev_challenges[i][2]);
    }
    prev_challenges_comms = js_class_vector_to_rust_vector(prev_challenges_comms);
    return new plonk_wasm.WasmPastaFqProverProof(messages, proof, evals0, evals1, public_, prev_challenges_scalars, prev_challenges_comms);
};

// Provides: caml_pasta_fq_proof_of_rust
// Requires: plonk_wasm, caml_pasta_fq_messages_of_rust, caml_pasta_fq_opening_proof_of_rust, caml_pasta_fq_proof_evaluations_of_rust, caml_pasta_fq_vector_of_rust, js_class_vector_of_rust_vector, caml_pasta_pallas_poly_comm_of_rust
var caml_pasta_fq_proof_of_rust = function(x) {
    var messages = caml_pasta_fq_messages_of_rust(x.commitments);
    var proof = caml_pasta_fq_opening_proof_of_rust(x.proof);
    var evals0 = caml_pasta_fq_proof_evaluations_of_rust(x.evals0);
    var evals1 = caml_pasta_fq_proof_evaluations_of_rust(x.evals1);
    var public_ = caml_pasta_fq_vector_of_rust(x.public_);
    var prev_challenges_scalars = x.prev_challenges_scalars;
    var prev_challenges_comms = js_class_vector_of_rust_vector(x.prev_challenges_comms, plonk_wasm.WasmPastaPallasPolyComm);
    var chals_len = prev_challenges_comms.length;
    var prev_challenges = new Array(chals_len);
    prev_challenges[0] = 0;
    for (var i = 1; i < chals_len; i++) {
        var res = new Array(3);
        res[0] = 0;
        res[1] = caml_pasta_fq_vector_of_rust(prev_challenges_scalars.get(i-1));
        res[2] = caml_pasta_pallas_poly_comm_of_rust(prev_challenges_comms[i]);
        prev_challenges[i] = res;
    }
    return [0, messages, proof, [0, evals0, evals1], public_, prev_challenges];
};

// Provides: caml_pasta_fq_plonk_proof_create
// Requires: plonk_wasm, caml_pasta_fq_vector_to_rust, caml_array_to_rust_vector, rust_affine_of_caml_affine, caml_pasta_fq_proof_of_rust
var caml_pasta_fq_plonk_proof_create = function(index, primary_input, auxiliary_input, prev_challenges, prev_sgs) {
    primary_input = caml_pasta_fq_vector_to_rust(primary_input);
    auxiliary_input = caml_pasta_fq_vector_to_rust(auxiliary_input);
    prev_challenges = caml_pasta_fq_vector_to_rust(prev_challenges);
    prev_sgs = caml_array_to_rust_vector(prev_sgs, rust_affine_of_caml_affine, plonk_wasm.caml_pasta_pallas_affine_one);
    var res = plonk_wasm.caml_pasta_fq_plonk_proof_create(index, primary_input, auxiliary_input, prev_challenges, prev_sgs);
    return caml_pasta_fq_proof_of_rust(res);
};

// Provides: caml_pasta_fq_plonk_proof_verify
// Requires: plonk_wasm, caml_array_to_rust_vector, caml_pasta_pallas_poly_comm_to_rust, caml_pasta_fq_plonk_verifier_index_to_rust, caml_pasta_fq_proof_to_rust
var caml_pasta_fq_plonk_proof_verify = function(lgr_comm, index, proof) {
    lgr_comm = caml_array_to_rust_vector(lgr_comm, caml_pasta_pallas_poly_comm_to_rust);
    index = caml_pasta_fq_plonk_verifier_index_to_rust(index);
    proof = caml_pasta_fq_proof_to_rust(proof);
    return plonk_wasm.caml_pasta_fq_plonk_proof_verify(lgr_comm, index, proof);
};

// Provides: caml_pasta_fq_plonk_proof_batch_verify
// Requires: plonk_wasm, caml_array_to_rust_vector, caml_pasta_pallas_poly_comm_to_rust, caml_pasta_fq_plonk_verifier_index_to_rust, caml_pasta_fq_proof_to_rust
var caml_pasta_fq_plonk_proof_batch_verify = function(lgr_comm, indexes, proofs) {
    var lgr_len = lgr_comm.length;
    var rust_lgr_comm = new plonk_wasm.WasmVecVecPallasPolyComm(lgr_len-1);
    for (var i = 1; i < lgr_len; i++) {
        rust_lgr_comm.push(caml_array_to_rust_vector(lgr_comm[i], caml_pasta_pallas_poly_comm_to_rust));
    }
    indexes = caml_array_to_rust_vector(indexes, caml_pasta_fq_plonk_verifier_index_to_rust);
    proofs = caml_array_to_rust_vector(proofs, caml_pasta_fq_proof_to_rust);
    return plonk_wasm.caml_pasta_fq_plonk_proof_batch_verify(rust_lgr_comm, indexes, proofs);
};

// Provides: caml_pasta_fq_plonk_proof_dummy
// Requires: plonk_wasm, caml_pasta_fq_proof_of_rust
var caml_pasta_fq_plonk_proof_dummy = function() {
    return caml_pasta_fq_proof_of_rust(plonk_wasm.caml_pasta_fq_plonk_proof_dummy());
};

// Provides: caml_pasta_fq_plonk_proof_deep_copy
// Requires: plonk_wasm, caml_pasta_fq_proof_to_rust, caml_pasta_fq_proof_of_rust
var caml_pasta_fq_plonk_proof_deep_copy = function(proof) {
    return caml_pasta_fq_proof_of_rust(plonk_wasm.caml_pasta_fq_plonk_proof_deep_copy(caml_pasta_fq_proof_to_rust(proof)));
};





// Provides: caml_random_oracles_of_rust
// Requires: caml_u8array_vector_of_rust_flat_vector
var caml_random_oracles_of_rust = function(x) {
    // TODO: Hardcoding this is a little brittle
    x = caml_u8array_vector_of_rust_flat_vector(x, 32);
    return [0, x[1], x[2], [0, x[3]], x[4], x[5], x[6], x[7], [0, x[8]], [0, x[9]], [0, x[10]]];
};

// Provides: caml_random_oracles_to_rust
// Requires: caml_u8array_vector_to_rust_flat_vector
var caml_random_oracles_to_rust = function(x) {
    var caml_vector = [0, x[1], x[2], x[3][1], x[4], x[5], x[6], x[7], x[8][1], x[9][1], x[10][1]];
    return caml_u8array_vector_to_rust_flat_vector(caml_vector);
};

// Provides: caml_oracles_of_rust
// Requires: caml_u8array_vector_of_rust_flat_vector, caml_random_oracles_of_rust
var caml_oracles_of_rust = function(x) {
    return [0, caml_random_oracles_of_rust(x.o), [0, x.p_eval0, x.p_eval1], caml_u8array_vector_of_rust_flat_vector(x.opening_prechallenges, 32 /* TODO: Don't hardcode */), x.digest_before_evaluations];
};

// Provides: caml_oracles_to_rust
// Requires: caml_u8array_vector_to_rust_flat_vector, caml_random_oracles_to_rust
var caml_oracles_to_rust = function(x, klass) {
    return new klass(
        caml_random_oracles_to_rust(x[1]),
        x[2][1],
        x[2][2],
        caml_u8array_vector_to_rust_flat_vector(x[3]),
        x[4]
    );
};





// Provides: caml_pasta_fp_plonk_oracles_create
// Requires: plonk_wasm, caml_oracles_of_rust, caml_array_to_rust_vector, caml_pasta_vesta_poly_comm_to_rust, caml_pasta_fp_plonk_verifier_index_to_rust, caml_pasta_fp_proof_to_rust
var caml_pasta_fp_plonk_oracles_create = function(lgr_comm, verifier_index, proof) {
    return caml_oracles_of_rust(plonk_wasm.caml_pasta_fp_plonk_oracles_create(
        caml_array_to_rust_vector(lgr_comm, caml_pasta_vesta_poly_comm_to_rust),
        caml_pasta_fp_plonk_verifier_index_to_rust(verifier_index),
        caml_pasta_fp_proof_to_rust(proof)
    ));
};

// Provides: caml_pasta_fp_plonk_oracles_dummy
// Requires: plonk_wasm, caml_oracles_of_rust
var caml_pasta_fp_plonk_oracles_dummy = function() {
    return caml_oracles_of_rust(plonk_wasm.caml_pasta_fp_plonk_oracles_dummy());
};

// Provides: caml_pasta_fp_plonk_oracles_deep_copy
// Requires: plonk_wasm, caml_oracles_of_rust, caml_oracles_to_rust
var caml_pasta_fp_plonk_oracles_deep_copy = function(x) {
    return caml_oracles_of_rust(plonk_wasm.caml_pasta_fp_plonk_oracles_deep_copy(caml_oracles_to_rust(x, plonk_wasm.WasmPastaFpPlonkOracles)));
};





// Provides: caml_pasta_fq_plonk_oracles_create
// Requires: plonk_wasm, caml_oracles_of_rust, caml_array_to_rust_vector, caml_pasta_pallas_poly_comm_to_rust, caml_pasta_fq_plonk_verifier_index_to_rust, caml_pasta_fq_proof_to_rust
var caml_pasta_fq_plonk_oracles_create = function(lgr_comm, verifier_index, proof) {
    return caml_oracles_of_rust(plonk_wasm.caml_pasta_fq_plonk_oracles_create(
        caml_array_to_rust_vector(lgr_comm, caml_pasta_pallas_poly_comm_to_rust),
        caml_pasta_fq_plonk_verifier_index_to_rust(verifier_index),
        caml_pasta_fq_proof_to_rust(proof)
    ));
};

// Provides: caml_pasta_fq_plonk_oracles_dummy
// Requires: plonk_wasm, caml_oracles_of_rust
var caml_pasta_fq_plonk_oracles_dummy = function() {
    return caml_oracles_of_rust(plonk_wasm.caml_pasta_fq_plonk_oracles_dummy());
};

// Provides: caml_pasta_fq_plonk_oracles_deep_copy
// Requires: plonk_wasm, caml_oracles_of_rust, caml_oracles_to_rust
var caml_pasta_fq_plonk_oracles_deep_copy = function(x) {
    return caml_oracles_of_rust(plonk_wasm.caml_pasta_fq_plonk_oracles_deep_copy(caml_oracles_to_rust(x, plonk_wasm.WasmPastaFqPlonkOracles)));
};
