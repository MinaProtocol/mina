/* global joo_global_object, plonk_wasm, caml_js_to_bool, caml_jsstring_of_string,
    caml_string_of_jsstring
    caml_create_bytes, caml_bytes_unsafe_set, caml_bytes_unsafe_get, caml_ml_bytes_length,
    UInt64, caml_int64_of_int32
*/

// Provides: caml_bytes_of_uint8array
// Requires: caml_create_bytes, caml_bytes_unsafe_set
var caml_bytes_of_uint8array = function (uint8array) {
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
var caml_bytes_to_uint8array = function (ocaml_bytes) {
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
  return plonk_wasm.caml_bigint_256_of_numeral(
    caml_jsstring_of_string(s),
    len,
    base
  );
};

// Provides: caml_bigint_256_of_decimal_string
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_bigint_256_of_decimal_string = function (s) {
  return plonk_wasm.caml_bigint_256_of_decimal_string(
    caml_jsstring_of_string(s)
  );
};

// Provides: caml_bigint_256_num_limbs
// Requires: plonk_wasm
var caml_bigint_256_num_limbs = plonk_wasm.caml_bigint_256_num_limbs;

// Provides: caml_bigint_256_bytes_per_limb
// Requires: plonk_wasm
var caml_bigint_256_bytes_per_limb = plonk_wasm.caml_bigint_256_bytes_per_limb;

// Provides: caml_bigint_256_div
// Requires: plonk_wasm
var caml_bigint_256_div = plonk_wasm.caml_bigint_256_div;

// Provides: caml_bigint_256_compare
// Requires: plonk_wasm
var caml_bigint_256_compare = plonk_wasm.caml_bigint_256_compare;

// Provides: caml_bigint_256_print
// Requires: plonk_wasm
var caml_bigint_256_print = plonk_wasm.caml_bigint_256_print;

// Provides: caml_bigint_256_to_string
// Requires: plonk_wasm, caml_string_of_jsstring
var caml_bigint_256_to_string = function (x) {
  return caml_string_of_jsstring(plonk_wasm.caml_bigint_256_to_string(x));
};

// Provides: caml_bigint_256_test_bit
// Requires: plonk_wasm, caml_js_to_bool
var caml_bigint_256_test_bit = function (x, i) {
  return caml_js_to_bool(plonk_wasm.caml_bigint_256_test_bit(x, i));
};

// Provides: caml_bigint_256_to_bytes
// Requires: plonk_wasm, caml_bytes_of_uint8array
var caml_bigint_256_to_bytes = function (x) {
  return caml_bytes_of_uint8array(plonk_wasm.caml_bigint_256_to_bytes(x));
};

// Provides: caml_bigint_256_of_bytes
// Requires: plonk_wasm, caml_bytes_to_uint8array
var caml_bigint_256_of_bytes = function (ocaml_bytes) {
  return plonk_wasm.caml_bigint_256_of_bytes(
    caml_bytes_to_uint8array(ocaml_bytes)
  );
};

// Provides: caml_bigint_256_deep_copy
// Requires: plonk_wasm
var caml_bigint_256_deep_copy = plonk_wasm.caml_bigint_256_deep_copy;

// Provides: caml_pasta_fp_copy
var caml_pasta_fp_copy = function (x, y) {
  for (var i = 0, l = x.length; i < l; i++) {
    x[i] = y[i];
  }
};

// Provides: caml_option_of_maybe_undefined
var caml_option_of_maybe_undefined = function (x) {
  if (x === undefined) {
    return 0; // None
  } else {
    return [0, x]; // Some(x)
  }
};

// Provides: caml_option_to_maybe_undefined
var caml_option_to_maybe_undefined = function (x) {
  if (x === 0) {
    // None
    return undefined;
  } else {
    return x[1];
  }
};

// Provides: caml_pasta_fp_size_in_bits
// Requires: plonk_wasm
var caml_pasta_fp_size_in_bits = plonk_wasm.caml_pasta_fp_size_in_bits;

// Provides: caml_pasta_fp_size
// Requires: plonk_wasm
var caml_pasta_fp_size = plonk_wasm.caml_pasta_fp_size;

// Provides: caml_pasta_fp_add
// Requires: plonk_wasm
var caml_pasta_fp_add = plonk_wasm.caml_pasta_fp_add;

// Provides: caml_pasta_fp_sub
// Requires: plonk_wasm
var caml_pasta_fp_sub = plonk_wasm.caml_pasta_fp_sub;

// Provides: caml_pasta_fp_negate
// Requires: plonk_wasm
var caml_pasta_fp_negate = plonk_wasm.caml_pasta_fp_negate;

// Provides: caml_pasta_fp_mul
// Requires: plonk_wasm
var caml_pasta_fp_mul = plonk_wasm.caml_pasta_fp_mul;

// Provides: caml_pasta_fp_div
// Requires: plonk_wasm
var caml_pasta_fp_div = plonk_wasm.caml_pasta_fp_div;

// Provides: caml_pasta_fp_inv
// Requires: plonk_wasm, caml_option_of_maybe_undefined
var caml_pasta_fp_inv = function (x) {
  return caml_option_of_maybe_undefined(plonk_wasm.caml_pasta_fp_inv(x));
};

// Provides: caml_pasta_fp_square
// Requires: plonk_wasm
var caml_pasta_fp_square = plonk_wasm.caml_pasta_fp_square;

// Provides: caml_pasta_fp_is_square
// Requires: plonk_wasm, caml_js_to_bool
var caml_pasta_fp_is_square = function (x) {
  return caml_js_to_bool(plonk_wasm.caml_pasta_fp_is_square(x));
};

// Provides: caml_pasta_fp_sqrt
// Requires: plonk_wasm, caml_option_of_maybe_undefined
var caml_pasta_fp_sqrt = function (x) {
  return caml_option_of_maybe_undefined(plonk_wasm.caml_pasta_fp_sqrt(x));
};

// Provides: caml_pasta_fp_of_int
// Requires: plonk_wasm
var caml_pasta_fp_of_int = plonk_wasm.caml_pasta_fp_of_int;

// Provides: caml_pasta_fp_to_string
// Requires: plonk_wasm, caml_string_of_jsstring
var caml_pasta_fp_to_string = function (x) {
  return caml_string_of_jsstring(plonk_wasm.caml_pasta_fp_to_string(x));
};

// Provides: caml_pasta_fp_of_string
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fp_of_string = function (x) {
  return plonk_wasm.caml_pasta_fp_of_string(caml_jsstring_of_string(x));
};

// Provides: caml_pasta_fp_print
// Requires: plonk_wasm
var caml_pasta_fp_print = plonk_wasm.caml_pasta_fp_print;

// Provides: caml_pasta_fp_mut_add
// Requires: caml_pasta_fp_copy, caml_pasta_fp_add
var caml_pasta_fp_mut_add = function (x, y) {
  caml_pasta_fp_copy(x, caml_pasta_fp_add(x, y));
};

// Provides: caml_pasta_fp_mut_sub
// Requires: caml_pasta_fp_copy, caml_pasta_fp_sub
var caml_pasta_fp_mut_sub = function (x, y) {
  caml_pasta_fp_copy(x, caml_pasta_fp_sub(x, y));
};

// Provides: caml_pasta_fp_mut_mul
// Requires: caml_pasta_fp_copy, caml_pasta_fp_mul
var caml_pasta_fp_mut_mul = function (x, y) {
  caml_pasta_fp_copy(x, caml_pasta_fp_mul(x, y));
};

// Provides: caml_pasta_fp_mut_square
// Requires: caml_pasta_fp_copy, caml_pasta_fp_square
var caml_pasta_fp_mut_square = function (x) {
  caml_pasta_fp_copy(x, caml_pasta_fp_square(x));
};

// Provides: caml_pasta_fp_compare
// Requires: plonk_wasm
var caml_pasta_fp_compare = plonk_wasm.caml_pasta_fp_compare;

// Provides: caml_pasta_fp_equal
// Requires: plonk_wasm
var caml_pasta_fp_equal = plonk_wasm.caml_pasta_fp_equal;

// Provides: caml_pasta_fp_random
// Requires: plonk_wasm
var caml_pasta_fp_random = plonk_wasm.caml_pasta_fp_random;

// Provides: caml_pasta_fp_rng
// Requires: plonk_wasm
var caml_pasta_fp_rng = plonk_wasm.caml_pasta_fp_rng;

// Provides: caml_pasta_fp_to_bigint
// Requires: plonk_wasm
var caml_pasta_fp_to_bigint = plonk_wasm.caml_pasta_fp_to_bigint;

// Provides: caml_pasta_fp_of_bigint
// Requires: plonk_wasm
var caml_pasta_fp_of_bigint = plonk_wasm.caml_pasta_fp_of_bigint;

// Provides: caml_pasta_fp_two_adic_root_of_unity
// Requires: plonk_wasm
var caml_pasta_fp_two_adic_root_of_unity =
  plonk_wasm.caml_pasta_fp_two_adic_root_of_unity;

// Provides: caml_pasta_fp_domain_generator
// Requires: plonk_wasm
var caml_pasta_fp_domain_generator = plonk_wasm.caml_pasta_fp_domain_generator;

// Provides: caml_pasta_fp_to_bytes
// Requires: plonk_wasm, caml_bytes_of_uint8array
var caml_pasta_fp_to_bytes = function (x) {
  var res = plonk_wasm.caml_pasta_fp_to_bytes(x);
  return caml_bytes_of_uint8array(plonk_wasm.caml_pasta_fp_to_bytes(x));
};

// Provides: caml_pasta_fp_of_bytes
// Requires: plonk_wasm, caml_bytes_to_uint8array
var caml_pasta_fp_of_bytes = function (ocaml_bytes) {
  return plonk_wasm.caml_pasta_fp_of_bytes(
    caml_bytes_to_uint8array(ocaml_bytes)
  );
};

// Provides: caml_pasta_fp_deep_copy
// Requires: plonk_wasm
var caml_pasta_fp_deep_copy = plonk_wasm.caml_pasta_fp_deep_copy;

// Provides: caml_pasta_fq_copy
var caml_pasta_fq_copy = function (x, y) {
  for (var i = 0, l = x.length; i < l; i++) {
    x[i] = y[i];
  }
};

// Provides: caml_pasta_fq_size_in_bits
// Requires: plonk_wasm
var caml_pasta_fq_size_in_bits = plonk_wasm.caml_pasta_fq_size_in_bits;

// Provides: caml_pasta_fq_size
// Requires: plonk_wasm
var caml_pasta_fq_size = plonk_wasm.caml_pasta_fq_size;

// Provides: caml_pasta_fq_add
// Requires: plonk_wasm
var caml_pasta_fq_add = plonk_wasm.caml_pasta_fq_add;

// Provides: caml_pasta_fq_sub
// Requires: plonk_wasm
var caml_pasta_fq_sub = plonk_wasm.caml_pasta_fq_sub;

// Provides: caml_pasta_fq_negate
// Requires: plonk_wasm
var caml_pasta_fq_negate = plonk_wasm.caml_pasta_fq_negate;

// Provides: caml_pasta_fq_mul
// Requires: plonk_wasm
var caml_pasta_fq_mul = plonk_wasm.caml_pasta_fq_mul;

// Provides: caml_pasta_fq_div
// Requires: plonk_wasm
var caml_pasta_fq_div = plonk_wasm.caml_pasta_fq_div;

// Provides: caml_pasta_fq_inv
// Requires: plonk_wasm, caml_option_of_maybe_undefined
var caml_pasta_fq_inv = function (x) {
  return caml_option_of_maybe_undefined(plonk_wasm.caml_pasta_fq_inv(x));
};

// Provides: caml_pasta_fq_square
// Requires: plonk_wasm
var caml_pasta_fq_square = plonk_wasm.caml_pasta_fq_square;

// Provides: caml_pasta_fq_is_square
// Requires: plonk_wasm, caml_js_to_bool
var caml_pasta_fq_is_square = function (x) {
  return caml_js_to_bool(plonk_wasm.caml_pasta_fq_is_square(x));
};

// Provides: caml_pasta_fq_sqrt
// Requires: plonk_wasm, caml_option_of_maybe_undefined
var caml_pasta_fq_sqrt = function (x) {
  return caml_option_of_maybe_undefined(plonk_wasm.caml_pasta_fq_sqrt(x));
};

// Provides: caml_pasta_fq_of_int
// Requires: plonk_wasm
var caml_pasta_fq_of_int = plonk_wasm.caml_pasta_fq_of_int;

// Provides: caml_pasta_fq_to_string
// Requires: plonk_wasm, caml_string_of_jsstring
var caml_pasta_fq_to_string = function (x) {
  return caml_string_of_jsstring(plonk_wasm.caml_pasta_fq_to_string(x));
};

// Provides: caml_pasta_fq_of_string
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fq_of_string = function (x) {
  return plonk_wasm.caml_pasta_fq_of_string(caml_jsstring_of_string(x));
};

// Provides: caml_pasta_fq_print
// Requires: plonk_wasm
var caml_pasta_fq_print = plonk_wasm.caml_pasta_fq_print;

// Provides: caml_pasta_fq_mut_add
// Requires: caml_pasta_fq_copy, caml_pasta_fq_add
var caml_pasta_fq_mut_add = function (x, y) {
  caml_pasta_fq_copy(x, caml_pasta_fq_add(x, y));
};

// Provides: caml_pasta_fq_mut_sub
// Requires: caml_pasta_fq_copy, caml_pasta_fq_sub
var caml_pasta_fq_mut_sub = function (x, y) {
  caml_pasta_fq_copy(x, caml_pasta_fq_sub(x, y));
};

// Provides: caml_pasta_fq_mut_mul
// Requires: caml_pasta_fq_copy, caml_pasta_fq_mul
var caml_pasta_fq_mut_mul = function (x, y) {
  caml_pasta_fq_copy(x, caml_pasta_fq_mul(x, y));
};

// Provides: caml_pasta_fq_mut_square
// Requires: caml_pasta_fq_copy, caml_pasta_fq_square
var caml_pasta_fq_mut_square = function (x) {
  caml_pasta_fq_copy(x, caml_pasta_fq_square(x));
};

// Provides: caml_pasta_fq_compare
// Requires: plonk_wasm
var caml_pasta_fq_compare = plonk_wasm.caml_pasta_fq_compare;

// Provides: caml_pasta_fq_equal
// Requires: plonk_wasm
var caml_pasta_fq_equal = plonk_wasm.caml_pasta_fq_equal;

// Provides: caml_pasta_fq_random
// Requires: plonk_wasm
var caml_pasta_fq_random = plonk_wasm.caml_pasta_fq_random;

// Provides: caml_pasta_fq_rng
// Requires: plonk_wasm
var caml_pasta_fq_rng = plonk_wasm.caml_pasta_fq_rng;

// Provides: caml_pasta_fq_to_bigint
// Requires: plonk_wasm
var caml_pasta_fq_to_bigint = plonk_wasm.caml_pasta_fq_to_bigint;

// Provides: caml_pasta_fq_of_bigint
// Requires: plonk_wasm
var caml_pasta_fq_of_bigint = plonk_wasm.caml_pasta_fq_of_bigint;

// Provides: caml_pasta_fq_two_adic_root_of_unity
// Requires: plonk_wasm
var caml_pasta_fq_two_adic_root_of_unity =
  plonk_wasm.caml_pasta_fq_two_adic_root_of_unity;

// Provides: caml_pasta_fq_domain_generator
// Requires: plonk_wasm
var caml_pasta_fq_domain_generator = plonk_wasm.caml_pasta_fq_domain_generator;

// Provides: caml_pasta_fq_to_bytes
// Requires: plonk_wasm, caml_bytes_of_uint8array
var caml_pasta_fq_to_bytes = function (x) {
  var res = plonk_wasm.caml_pasta_fq_to_bytes(x);
  return caml_bytes_of_uint8array(plonk_wasm.caml_pasta_fq_to_bytes(x));
};

// Provides: caml_pasta_fq_of_bytes
// Requires: plonk_wasm, caml_bytes_to_uint8array
var caml_pasta_fq_of_bytes = function (ocaml_bytes) {
  return plonk_wasm.caml_pasta_fq_of_bytes(
    caml_bytes_to_uint8array(ocaml_bytes)
  );
};

// Provides: caml_pasta_fq_deep_copy
// Requires: plonk_wasm
var caml_pasta_fq_deep_copy = plonk_wasm.caml_pasta_fq_deep_copy;

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
  var res = new Array(output_len + 1);
  res[0] = 0; // OCaml tag before array contents, so that we can use this with arrays or vectors
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
  // return v.map(klass.__wrap)
  var len = v.length;
  var res = new Array(len);
  for (var i = 0; i < len; i++) {
    // Beware: the caller may need to add finalizers to these.
    res[i] = klass.__wrap(v[i]);
  }
  return res;
};

// Provides: caml_fp_vector_create
var caml_fp_vector_create = function () {
  return [0]; // OCaml tag for arrays, so that we can use the same utility fns on both
};

// Provides: caml_fp_vector_length
var caml_fp_vector_length = function (v) {
  return v.length - 1;
};

// Provides: caml_fp_vector_emplace_back
var caml_fp_vector_emplace_back = function (v, x) {
  v.push(x);
};

// Provides: caml_fp_vector_get
var caml_fp_vector_get = function (v, i) {
  var value = v[i + 1];
  if (value === undefined) {
    throw Error(
      'caml_fp_vector_get: Index out of bounds, got ' + i + '/' + (v.length - 1)
    );
  }
  return new joo_global_object.Uint8Array(value);
};

// Provides: caml_fp_vector_to_rust
// Requires: caml_u8array_vector_to_rust_flat_vector
var caml_fp_vector_to_rust = function (v) {
  return caml_u8array_vector_to_rust_flat_vector(v);
};

// Provides: caml_fp_vector_of_rust
// Requires: caml_u8array_vector_of_rust_flat_vector
var caml_fp_vector_of_rust = function (v) {
  // TODO: Hardcoding this is a little brittle
  return caml_u8array_vector_of_rust_flat_vector(v, 32);
};

// Provides: caml_fq_vector_create
var caml_fq_vector_create = function () {
  return [0]; // OCaml tag for arrays, so that we can use the same utility fns on both
};

// Provides: caml_fq_vector_length
var caml_fq_vector_length = function (v) {
  return v.length - 1;
};

// Provides: caml_fq_vector_emplace_back
var caml_fq_vector_emplace_back = function (v, x) {
  v.push(x);
};

// Provides: caml_fq_vector_get
var caml_fq_vector_get = function (v, i) {
  var value = v[i + 1];
  if (value === undefined) {
    throw Error(
      'caml_fq_vector_get: Index out of bounds, got ' + i + '/' + (v.length - 1)
    );
  }
  return new joo_global_object.Uint8Array(value);
};

// Provides: caml_fq_vector_to_rust
// Requires: caml_u8array_vector_to_rust_flat_vector
var caml_fq_vector_to_rust = function (v) {
  return caml_u8array_vector_to_rust_flat_vector(v);
};

// Provides: caml_fq_vector_of_rust
// Requires: caml_u8array_vector_of_rust_flat_vector
var caml_fq_vector_of_rust = function (v) {
  // TODO: Hardcoding this is a little brittle
  return caml_u8array_vector_of_rust_flat_vector(v, 32);
};

// Provides: free_finalization_registry
var free_finalization_registry = new joo_global_object.FinalizationRegistry(
  function (instance_representative) {
    instance_representative.free();
  }
);

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
  var instance_representative = x.constructor.__wrap(x.ptr);
  free_finalization_registry.register(x, instance_representative, x);
  return x;
};

// Provides: rust_affine_to_caml_affine
var rust_affine_to_caml_affine = function (pt) {
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
var rust_affine_of_caml_affine = function (pt, klass) {
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

// Provides: caml_pallas_one
// Requires: plonk_wasm, free_on_finalize
var caml_pallas_one = function () {
  var res = plonk_wasm.caml_pallas_one();
  free_on_finalize(res);
  return res;
};

// Provides: caml_pallas_add
// Requires: plonk_wasm, free_on_finalize
var caml_pallas_add = function (x, y) {
  var res = plonk_wasm.caml_pallas_add(x, y);
  free_on_finalize(res);
  return res;
};

// Provides: caml_pallas_sub
// Requires: plonk_wasm, free_on_finalize
var caml_pallas_sub = function (x, y) {
  var res = plonk_wasm.caml_pallas_sub(x, y);
  free_on_finalize(res);
  return res;
};

// Provides: caml_pallas_negate
// Requires: plonk_wasm, free_on_finalize
var caml_pallas_negate = function (x) {
  var res = plonk_wasm.caml_pallas_negate(x);
  free_on_finalize(res);
  return res;
};

// Provides: caml_pallas_double
// Requires: plonk_wasm, free_on_finalize
var caml_pallas_double = function (x) {
  var res = plonk_wasm.caml_pallas_double(x);
  free_on_finalize(res);
  return res;
};

// Provides: caml_pallas_scale
// Requires: plonk_wasm, free_on_finalize
var caml_pallas_scale = function (x, y) {
  var res = plonk_wasm.caml_pallas_scale(x, y);
  free_on_finalize(res);
  return res;
};

// Provides: caml_pallas_random
// Requires: plonk_wasm, free_on_finalize
var caml_pallas_random = function () {
  var res = plonk_wasm.caml_pallas_random();
  free_on_finalize(res);
  return res;
};

// Provides: caml_pallas_rng
// Requires: plonk_wasm, free_on_finalize
var caml_pallas_rng = function (i) {
  var res = plonk_wasm.caml_pallas_rng(i);
  free_on_finalize(res);
  return res;
};

// Provides: caml_pallas_to_affine
// Requires: plonk_wasm, rust_affine_to_caml_affine
var caml_pallas_to_affine = function (pt) {
  var res = plonk_wasm.caml_pallas_to_affine(pt);
  return rust_affine_to_caml_affine(res);
};

// Provides: caml_pallas_of_affine
// Requires: plonk_wasm, rust_affine_of_caml_affine, free_on_finalize
var caml_pallas_of_affine = function (pt) {
  var res = plonk_wasm.caml_pallas_of_affine(
    rust_affine_of_caml_affine(pt, plonk_wasm.caml_pallas_affine_one)
  );
  free_on_finalize(res);
  return res;
};

// Provides: caml_pallas_of_affine_coordinates
// Requires: plonk_wasm, free_on_finalize
var caml_pallas_of_affine_coordinates = function (x, y) {
  var res = plonk_wasm.caml_pallas_of_affine_coordinates(x, y);
  free_on_finalize(res);
  return res;
};

// Provides: caml_pallas_endo_base
// Requires: plonk_wasm
var caml_pallas_endo_base = plonk_wasm.caml_pallas_endo_base;

// Provides: caml_pallas_endo_scalar
// Requires: plonk_wasm
var caml_pallas_endo_scalar = plonk_wasm.caml_pallas_endo_scalar;

// Provides: caml_pallas_affine_deep_copy
// Requires: plonk_wasm, rust_affine_of_caml_affine, rust_affine_to_caml_affine
var caml_pallas_affine_deep_copy = function (pt) {
  return rust_affine_to_caml_affine(
    plonk_wasm.caml_pallas_affine_deep_copy(
      rust_affine_of_caml_affine(pt, plonk_wasm.caml_pallas_affine_one)
    )
  );
};

// Provides: caml_vesta_one
// Requires: plonk_wasm, free_on_finalize
var caml_vesta_one = function () {
  var res = plonk_wasm.caml_vesta_one();
  free_on_finalize(res);
  return res;
};

// Provides: caml_vesta_add
// Requires: plonk_wasm, free_on_finalize
var caml_vesta_add = function (x, y) {
  var res = plonk_wasm.caml_vesta_add(x, y);
  free_on_finalize(res);
  return res;
};

// Provides: caml_vesta_sub
// Requires: plonk_wasm, free_on_finalize
var caml_vesta_sub = function (x, y) {
  var res = plonk_wasm.caml_vesta_sub(x, y);
  free_on_finalize(res);
  return res;
};

// Provides: caml_vesta_negate
// Requires: plonk_wasm, free_on_finalize
var caml_vesta_negate = function (x) {
  var res = plonk_wasm.caml_vesta_negate(x);
  free_on_finalize(res);
  return res;
};

// Provides: caml_vesta_double
// Requires: plonk_wasm, free_on_finalize
var caml_vesta_double = function (x) {
  var res = plonk_wasm.caml_vesta_double(x);
  free_on_finalize(res);
  return res;
};

// Provides: caml_vesta_scale
// Requires: plonk_wasm, free_on_finalize
var caml_vesta_scale = function (x, y) {
  var res = plonk_wasm.caml_vesta_scale(x, y);
  free_on_finalize(res);
  return res;
};

// Provides: caml_vesta_random
// Requires: plonk_wasm, free_on_finalize
var caml_vesta_random = function () {
  var res = plonk_wasm.caml_vesta_random();
  free_on_finalize(res);
  return res;
};

// Provides: caml_vesta_rng
// Requires: plonk_wasm, free_on_finalize
var caml_vesta_rng = function (i) {
  var res = plonk_wasm.caml_vesta_rng(i);
  free_on_finalize(res);
  return res;
};

// Provides: caml_vesta_to_affine
// Requires: plonk_wasm, rust_affine_to_caml_affine
var caml_vesta_to_affine = function (pt) {
  var res = plonk_wasm.caml_vesta_to_affine(pt);
  return rust_affine_to_caml_affine(res);
};

// Provides: caml_vesta_of_affine
// Requires: plonk_wasm, rust_affine_of_caml_affine, free_on_finalize
var caml_vesta_of_affine = function (pt) {
  var res = plonk_wasm.caml_vesta_of_affine(
    rust_affine_of_caml_affine(pt, plonk_wasm.caml_vesta_affine_one)
  );
  free_on_finalize(res);
  return res;
};

// Provides: caml_vesta_of_affine_coordinates
// Requires: plonk_wasm, free_on_finalize
var caml_vesta_of_affine_coordinates = function (x, y) {
  var res = plonk_wasm.caml_vesta_of_affine_coordinates(x, y);
  free_on_finalize(res);
  return res;
};

// Provides: caml_vesta_endo_base
// Requires: plonk_wasm
var caml_vesta_endo_base = plonk_wasm.caml_vesta_endo_base;

// Provides: caml_vesta_endo_scalar
// Requires: plonk_wasm
var caml_vesta_endo_scalar = plonk_wasm.caml_vesta_endo_scalar;

// Provides: caml_vesta_affine_deep_copy
// Requires: plonk_wasm, rust_affine_of_caml_affine, rust_affine_to_caml_affine
var caml_vesta_affine_deep_copy = function (pt) {
  return rust_affine_to_caml_affine(
    plonk_wasm.caml_vesta_affine_deep_copy(
      rust_affine_of_caml_affine(pt, plonk_wasm.caml_vesta_affine_one)
    )
  );
};

// Provides: caml_array_of_rust_vector
// Requires: js_class_vector_of_rust_vector
var caml_array_of_rust_vector = function (v, klass, convert, should_free) {
  v = js_class_vector_of_rust_vector(v, klass);
  var len = v.length;
  var res = new Array(len + 1);
  res[0] = 0; // OCaml tag before array contents
  for (var i = 0; i < len; i++) {
    var rust_val = v[i];
    res[i + 1] = convert(rust_val);
    if (should_free) {
      rust_val.free();
    }
  }
  return res;
};

// Provides: caml_array_to_rust_vector
// Requires: js_class_vector_to_rust_vector, free_finalization_registry
var caml_array_to_rust_vector = function (v, convert, mk_new) {
  v = v.slice(1); // Copy, dropping OCaml tag
  for (var i = 0, l = v.length; i < l; i++) {
    var class_val = convert(v[i], mk_new);
    v[i] = class_val;
    // Don't free when GC runs; rust will free on its end.
    free_finalization_registry.unregister(class_val);
  }
  return js_class_vector_to_rust_vector(v);
};

// Provides: caml_poly_comm_of_rust_poly_comm
// Requires: rust_affine_to_caml_affine, caml_array_of_rust_vector
var caml_poly_comm_of_rust_poly_comm = function (
  poly_comm,
  klass,
  should_free
) {
  var rust_shifted = poly_comm.shifted;
  var rust_unshifted = poly_comm.unshifted;
  var caml_shifted;
  if (rust_shifted === undefined) {
    caml_shifted = 0;
  } else {
    caml_shifted = [0, rust_affine_to_caml_affine(rust_shifted)];
  }
  var caml_unshifted = caml_array_of_rust_vector(
    rust_unshifted,
    klass,
    rust_affine_to_caml_affine,
    should_free
  );
  return [0, caml_unshifted, caml_shifted];
};

// Provides: caml_poly_comm_to_rust_poly_comm
// Requires: rust_affine_of_caml_affine, caml_array_to_rust_vector
var caml_poly_comm_to_rust_poly_comm = function (
  poly_comm,
  poly_comm_class,
  mk_affine
) {
  var caml_unshifted = poly_comm[1];
  var caml_shifted = poly_comm[2];
  var rust_shifted = undefined;
  if (caml_shifted !== 0) {
    rust_shifted = rust_affine_of_caml_affine(caml_shifted[1], mk_affine);
  }
  var rust_unshifted = caml_array_to_rust_vector(
    caml_unshifted,
    rust_affine_of_caml_affine,
    mk_affine
  );
  return new poly_comm_class(rust_unshifted, rust_shifted);
};

// Provides: caml_vesta_poly_comm_of_rust
// Requires: plonk_wasm, caml_poly_comm_of_rust_poly_comm
var caml_vesta_poly_comm_of_rust = function (x) {
  return caml_poly_comm_of_rust_poly_comm(x, plonk_wasm.WasmGVesta, false);
};

// Provides: caml_vesta_poly_comm_to_rust
// Requires: plonk_wasm, caml_poly_comm_to_rust_poly_comm
var caml_vesta_poly_comm_to_rust = function (x) {
  return caml_poly_comm_to_rust_poly_comm(
    x,
    plonk_wasm.WasmFpPolyComm,
    plonk_wasm.caml_vesta_affine_one
  );
};

// Provides: caml_pallas_poly_comm_of_rust
// Requires: plonk_wasm, caml_poly_comm_of_rust_poly_comm
var caml_pallas_poly_comm_of_rust = function (x) {
  return caml_poly_comm_of_rust_poly_comm(x, plonk_wasm.WasmGPallas, false);
};

// Provides: caml_pallas_poly_comm_to_rust
// Requires: plonk_wasm, caml_poly_comm_to_rust_poly_comm
var caml_pallas_poly_comm_to_rust = function (x) {
  return caml_poly_comm_to_rust_poly_comm(
    x,
    plonk_wasm.WasmFqPolyComm,
    plonk_wasm.caml_pallas_affine_one
  );
};

// Provides: caml_fp_srs_create
// Requires: plonk_wasm, free_on_finalize
var caml_fp_srs_create = function (i) {
  return free_on_finalize(plonk_wasm.caml_fp_srs_create(i));
};

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
// Requires: plonk_wasm, caml_vesta_poly_comm_of_rust
var caml_fp_srs_lagrange_commitment = function (t, domain_size, i) {
  var res = plonk_wasm.caml_fp_srs_lagrange_commitment(t, domain_size, i);
  return caml_vesta_poly_comm_of_rust(res);
};

// Provides: caml_fp_srs_commit_evaluations
// Requires: plonk_wasm, caml_vesta_poly_comm_of_rust, caml_fp_vector_to_rust
var caml_fp_srs_commit_evaluations = function (t, domain_size, fps) {
  var res = plonk_wasm.caml_fp_srs_commit_evaluations(
    t,
    domain_size,
    caml_fp_vector_to_rust(fps)
  );
  return caml_vesta_poly_comm_of_rust(res);
};

// Provides: caml_fp_srs_b_poly_commitment
// Requires: plonk_wasm, caml_vesta_poly_comm_of_rust, caml_u8array_vector_to_rust_flat_vector
var caml_fp_srs_b_poly_commitment = function (srs, chals) {
  var res = plonk_wasm.caml_fp_srs_b_poly_commitment(
    srs,
    caml_u8array_vector_to_rust_flat_vector(chals)
  );
  return caml_vesta_poly_comm_of_rust(res);
};

// Provides: caml_fp_srs_batch_accumulator_check
// Requires: plonk_wasm, rust_affine_of_caml_affine, caml_array_to_rust_vector, caml_fp_vector_to_rust
var caml_fp_srs_batch_accumulator_check = function (srs, comms, chals) {
  var rust_comms = caml_array_to_rust_vector(
    comms,
    rust_affine_of_caml_affine,
    plonk_wasm.caml_vesta_affine_one
  );
  var rust_chals = caml_fp_vector_to_rust(chals);
  var ok = plonk_wasm.caml_fp_srs_batch_accumulator_check(
    srs,
    rust_comms,
    rust_chals
  );
  return ok;
};

// Provides: caml_fp_srs_batch_accumulator_generate
// Requires: plonk_wasm, rust_affine_to_caml_affine, caml_array_of_rust_vector, caml_fp_vector_to_rust
var caml_fp_srs_batch_accumulator_generate = function (srs, comms, chals) {
  var rust_chals = caml_fp_vector_to_rust(chals);
  var rust_comms = plonk_wasm.caml_fp_srs_batch_accumulator_generate(
    srs,
    comms,
    rust_chals
  );
  return caml_array_of_rust_vector(
    rust_comms,
    plonk_wasm.WasmGVesta,
    rust_affine_to_caml_affine,
    false
  );
};

// Provides: caml_fp_srs_h
// Requires: plonk_wasm, rust_affine_to_caml_affine
var caml_fp_srs_h = function (t) {
  return rust_affine_to_caml_affine(plonk_wasm.caml_fp_srs_h(t));
};

// Provides: caml_fq_srs_create
// Requires: plonk_wasm, free_on_finalize
var caml_fq_srs_create = function (i) {
  return free_on_finalize(plonk_wasm.caml_fq_srs_create(i));
};

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
// Requires: plonk_wasm, caml_pallas_poly_comm_of_rust
var caml_fq_srs_lagrange_commitment = function (t, domain_size, i) {
  var res = plonk_wasm.caml_fq_srs_lagrange_commitment(t, domain_size, i);
  return caml_pallas_poly_comm_of_rust(res);
};

// Provides: caml_fq_srs_commit_evaluations
// Requires: plonk_wasm, caml_pallas_poly_comm_of_rust, caml_fq_vector_to_rust
var caml_fq_srs_commit_evaluations = function (t, domain_size, fqs) {
  var res = plonk_wasm.caml_fq_srs_commit_evaluations(
    t,
    domain_size,
    caml_fq_vector_to_rust(fqs)
  );
  return caml_pallas_poly_comm_of_rust(res);
};

// Provides: caml_fq_srs_b_poly_commitment
// Requires: plonk_wasm, caml_pallas_poly_comm_of_rust, caml_u8array_vector_to_rust_flat_vector
var caml_fq_srs_b_poly_commitment = function (srs, chals) {
  var res = plonk_wasm.caml_fq_srs_b_poly_commitment(
    srs,
    caml_u8array_vector_to_rust_flat_vector(chals)
  );
  return caml_pallas_poly_comm_of_rust(res);
};

// Provides: caml_fq_srs_batch_accumulator_check
// Requires: plonk_wasm, rust_affine_of_caml_affine, caml_array_to_rust_vector, caml_fq_vector_to_rust
var caml_fq_srs_batch_accumulator_check = function (srs, comms, chals) {
  var rust_comms = caml_array_to_rust_vector(
    comms,
    rust_affine_of_caml_affine,
    plonk_wasm.caml_pallas_affine_one
  );
  var rust_chals = caml_fq_vector_to_rust(chals);
  var ok = plonk_wasm.caml_fq_srs_batch_accumulator_check(
    srs,
    rust_comms,
    rust_chals
  );
  return ok;
};

// Provides: caml_fq_srs_batch_accumulator_generate
// Requires: plonk_wasm, rust_affine_to_caml_affine, caml_array_of_rust_vector, caml_fq_vector_to_rust
var caml_fq_srs_batch_accumulator_generate = function (srs, comms, chals) {
  var rust_chals = caml_fq_vector_to_rust(chals);
  var rust_comms = plonk_wasm.caml_fq_srs_batch_accumulator_generate(
    srs,
    comms,
    rust_chals
  );
  return caml_array_of_rust_vector(
    rust_comms,
    plonk_wasm.WasmGPallas,
    rust_affine_to_caml_affine,
    false
  );
};

// Provides: caml_fq_srs_h
// Requires: plonk_wasm, rust_affine_to_caml_affine
var caml_fq_srs_h = function (t) {
  return rust_affine_to_caml_affine(plonk_wasm.caml_fq_srs_h(t));
};

// Provides: caml_fq_srs_add_lagrange_basis
// Requires: plonk_wasm
function caml_fq_srs_add_lagrange_basis(srs, log2_size) {
  return plonk_wasm.caml_fq_srs_add_lagrange_basis(srs, log2_size);
}

// Provides: caml_plonk_wire_of_rust
var caml_plonk_wire_of_rust = function (wire) {
  var res = [0, wire.row, wire.col];
  wire.free();
  return res;
};

// Provides: caml_plonk_wire_to_rust
// Requires: plonk_wasm
var caml_plonk_wire_to_rust = function (wire) {
  return plonk_wasm.Wire.create(wire[1], wire[2]);
};

// Provides: caml_plonk_wires_of_rust
// Requires: caml_plonk_wire_of_rust
var caml_plonk_wires_of_rust = function (wires) {
  var res = [
    0,
    caml_plonk_wire_of_rust(wires[0]),
    caml_plonk_wire_of_rust(wires[1]),
    caml_plonk_wire_of_rust(wires[2]),
    caml_plonk_wire_of_rust(wires[3]),
    caml_plonk_wire_of_rust(wires[4]),
    caml_plonk_wire_of_rust(wires[5]),
    caml_plonk_wire_of_rust(wires[6]),
  ];
  wires.free();
  return res;
};

// Provides: caml_plonk_wires_to_rust
// Requires: plonk_wasm, caml_plonk_wire_to_rust
var caml_plonk_wires_to_rust = function (wires) {
  return new plonk_wasm.WasmGateWires(
    caml_plonk_wire_to_rust(wires[1]),
    caml_plonk_wire_to_rust(wires[2]),
    caml_plonk_wire_to_rust(wires[3]),
    caml_plonk_wire_to_rust(wires[4]),
    caml_plonk_wire_to_rust(wires[5]),
    caml_plonk_wire_to_rust(wires[6]),
    caml_plonk_wire_to_rust(wires[7])
  );
};

// Provides: caml_plonk_gate_of_rust
// Requires: caml_plonk_wires_of_rust, caml_u8array_vector_of_rust_flat_vector
var caml_plonk_gate_of_rust = function (gate) {
  // TODO: Hardcoding 32 here is a little brittle
  var res = [
    0,
    gate.typ,
    caml_plonk_wires_of_rust(gate.wires),
    caml_u8array_vector_of_rust_flat_vector(gate.c, 32),
  ];
  gate.free();
  return res;
};

// Provides: caml_fp_plonk_gate_to_rust
// Requires: plonk_wasm, caml_plonk_wires_to_rust, caml_u8array_vector_to_rust_flat_vector
var caml_fp_plonk_gate_to_rust = function (gate) {
  return new plonk_wasm.WasmFpGate(
    gate[1],
    caml_plonk_wires_to_rust(gate[2]),
    caml_u8array_vector_to_rust_flat_vector(gate[3])
  );
};

// Provides: caml_fq_plonk_gate_to_rust
// Requires: plonk_wasm, caml_plonk_wires_to_rust, caml_u8array_vector_to_rust_flat_vector
var caml_fq_plonk_gate_to_rust = function (gate) {
  // TODO: Hardcoding 32 here is a little brittle
  return new plonk_wasm.WasmFqGate(
    gate[1],
    caml_plonk_wires_to_rust(gate[2]),
    caml_u8array_vector_to_rust_flat_vector(gate[3])
  );
};

// Provides: caml_pasta_fp_plonk_gate_vector_create
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_fp_plonk_gate_vector_create = function () {
  return free_on_finalize(plonk_wasm.caml_pasta_fp_plonk_gate_vector_create());
};

// Provides: caml_pasta_fp_plonk_gate_vector_add
// Requires: plonk_wasm, caml_fp_plonk_gate_to_rust
var caml_pasta_fp_plonk_gate_vector_add = function (v, x) {
  return plonk_wasm.caml_pasta_fp_plonk_gate_vector_add(
    v,
    caml_fp_plonk_gate_to_rust(x)
  );
};

// Provides: caml_pasta_fp_plonk_gate_vector_get
// Requires: plonk_wasm, caml_plonk_gate_of_rust
var caml_pasta_fp_plonk_gate_vector_get = function (v, i) {
  return caml_plonk_gate_of_rust(
    plonk_wasm.caml_pasta_fp_plonk_gate_vector_get(v, i)
  );
};

// Provides: caml_pasta_fp_plonk_gate_vector_len
// Requires: plonk_wasm
var caml_pasta_fp_plonk_gate_vector_len = function (v) {
  return plonk_wasm.caml_pasta_fp_plonk_gate_vector_len(v);
};

// Provides: caml_pasta_fp_plonk_gate_vector_wrap
// Requires: plonk_wasm, caml_plonk_wire_to_rust
var caml_pasta_fp_plonk_gate_vector_wrap = function (v, x, y) {
  return plonk_wasm.caml_pasta_fp_plonk_gate_vector_wrap(
    v,
    caml_plonk_wire_to_rust(x),
    caml_plonk_wire_to_rust(y)
  );
};

// Provides: caml_pasta_fp_plonk_gate_vector_digest
// Requires: plonk_wasm, caml_bytes_of_uint8array
var caml_pasta_fp_plonk_gate_vector_digest = function (
  public_input_size,
  gate_vector
) {
  var uint8array = plonk_wasm.caml_pasta_fp_plonk_gate_vector_digest(
    public_input_size,
    gate_vector
  );
  return caml_bytes_of_uint8array(uint8array);
};

// Provides: caml_pasta_fp_plonk_circuit_serialize
// Requires: plonk_wasm, caml_string_of_jsstring
var caml_pasta_fp_plonk_circuit_serialize = function (
  public_input_size,
  gate_vector
) {
  return caml_string_of_jsstring(
    plonk_wasm.caml_pasta_fp_plonk_circuit_serialize(
      public_input_size,
      gate_vector
    )
  );
};

// Provides: caml_pasta_fq_plonk_gate_vector_create
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_fq_plonk_gate_vector_create = function () {
  return free_on_finalize(plonk_wasm.caml_pasta_fq_plonk_gate_vector_create());
};

// Provides: caml_pasta_fq_plonk_gate_vector_add
// Requires: plonk_wasm, caml_fq_plonk_gate_to_rust
var caml_pasta_fq_plonk_gate_vector_add = function (v, x) {
  return plonk_wasm.caml_pasta_fq_plonk_gate_vector_add(
    v,
    caml_fq_plonk_gate_to_rust(x)
  );
};

// Provides: caml_pasta_fq_plonk_gate_vector_get
// Requires: plonk_wasm, caml_plonk_gate_of_rust
var caml_pasta_fq_plonk_gate_vector_get = function (v, i) {
  return caml_plonk_gate_of_rust(
    plonk_wasm.caml_pasta_fq_plonk_gate_vector_get(v, i)
  );
};

// Provides: caml_pasta_fq_plonk_gate_vector_len
// Requires: plonk_wasm
var caml_pasta_fq_plonk_gate_vector_len = function (v) {
  return plonk_wasm.caml_pasta_fq_plonk_gate_vector_len(v);
};

// Provides: caml_pasta_fq_plonk_gate_vector_wrap
// Requires: plonk_wasm, caml_plonk_wire_to_rust
var caml_pasta_fq_plonk_gate_vector_wrap = function (v, x, y) {
  return plonk_wasm.caml_pasta_fq_plonk_gate_vector_wrap(
    v,
    caml_plonk_wire_to_rust(x),
    caml_plonk_wire_to_rust(y)
  );
};

// Provides: caml_pasta_fq_plonk_gate_vector_digest
// Requires: plonk_wasm, caml_bytes_of_uint8array
var caml_pasta_fq_plonk_gate_vector_digest = function (
  public_input_size,
  gate_vector
) {
  var uint8array = plonk_wasm.caml_pasta_fq_plonk_gate_vector_digest(
    public_input_size,
    gate_vector
  );
  return caml_bytes_of_uint8array(uint8array);
};

// Provides: caml_pasta_fq_plonk_circuit_serialize
// Requires: plonk_wasm, caml_string_of_jsstring
var caml_pasta_fq_plonk_circuit_serialize = function (
  public_input_size,
  gate_vector
) {
  return caml_string_of_jsstring(
    plonk_wasm.caml_pasta_fq_plonk_circuit_serialize(
      public_input_size,
      gate_vector
    )
  );
};

// Provides: caml_pasta_fp_plonk_index_create
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_fp_plonk_index_create = function (
  gates,
  public_inputs,
  prev_challenges,
  urs
) {
  var t = plonk_wasm.caml_pasta_fp_plonk_index_create(
    gates,
    public_inputs,
    prev_challenges,
    urs
  );
  return free_on_finalize(t);
};

// Provides: caml_pasta_fp_plonk_index_max_degree
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_max_degree =
  plonk_wasm.caml_pasta_fp_plonk_index_max_degree;

// Provides: caml_pasta_fp_plonk_index_public_inputs
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_public_inputs =
  plonk_wasm.caml_pasta_fp_plonk_index_public_inputs;

// Provides: caml_pasta_fp_plonk_index_domain_d1_size
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_domain_d1_size =
  plonk_wasm.caml_pasta_fp_plonk_index_domain_d1_size;

// Provides: caml_pasta_fp_plonk_index_domain_d4_size
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_domain_d4_size =
  plonk_wasm.caml_pasta_fp_plonk_index_domain_d4_size;

// Provides: caml_pasta_fp_plonk_index_domain_d8_size
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_domain_d8_size =
  plonk_wasm.caml_pasta_fp_plonk_index_domain_d8_size;

// Provides: caml_pasta_fp_plonk_index_read
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fp_plonk_index_read = function (offset, urs, path) {
  if (offset === 0) {
    offset = undefined;
  } else {
    offset = offset[1];
  }
  return plonk_wasm.caml_pasta_fp_plonk_index_read(
    offset,
    urs,
    caml_jsstring_of_string(path)
  );
};

// Provides: caml_pasta_fp_plonk_index_write
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fp_plonk_index_write = function (append, t, path) {
  if (append === 0) {
    append = undefined;
  } else {
    append = append[1];
  }
  return plonk_wasm.caml_pasta_fp_plonk_index_write(
    append,
    t,
    caml_jsstring_of_string(path)
  );
};

// Provides: caml_pasta_fq_plonk_index_create
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_fq_plonk_index_create = function (
  gates,
  public_inputs,
  prev_challenges,
  urs
) {
  return free_on_finalize(
    plonk_wasm.caml_pasta_fq_plonk_index_create(
      gates,
      public_inputs,
      prev_challenges,
      urs
    )
  );
};

// Provides: caml_pasta_fq_plonk_index_max_degree
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_max_degree =
  plonk_wasm.caml_pasta_fq_plonk_index_max_degree;

// Provides: caml_pasta_fq_plonk_index_public_inputs
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_public_inputs =
  plonk_wasm.caml_pasta_fq_plonk_index_public_inputs;

// Provides: caml_pasta_fq_plonk_index_domain_d1_size
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_domain_d1_size =
  plonk_wasm.caml_pasta_fq_plonk_index_domain_d1_size;

// Provides: caml_pasta_fq_plonk_index_domain_d4_size
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_domain_d4_size =
  plonk_wasm.caml_pasta_fq_plonk_index_domain_d4_size;

// Provides: caml_pasta_fq_plonk_index_domain_d8_size
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_domain_d8_size =
  plonk_wasm.caml_pasta_fq_plonk_index_domain_d8_size;

// Provides: caml_pasta_fq_plonk_index_read
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fq_plonk_index_read = function (offset, urs, path) {
  if (offset === 0) {
    offset = undefined;
  } else {
    offset = offset[1];
  }
  return plonk_wasm.caml_pasta_fq_plonk_index_read(
    offset,
    urs,
    caml_jsstring_of_string(path)
  );
};

// Provides: caml_pasta_fq_plonk_index_write
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fq_plonk_index_write = function (append, t, path) {
  if (append === 0) {
    append = undefined;
  } else {
    append = append[1];
  }
  return plonk_wasm.caml_pasta_fq_plonk_index_write(
    append,
    t,
    caml_jsstring_of_string(path)
  );
};

// Provides: caml_plonk_domain_of_rust
var caml_plonk_domain_of_rust = function (x) {
  var log_size_of_group = x.log_size_of_group;
  var group_gen = x.group_gen;
  x.free();
  return [0, log_size_of_group, group_gen];
};

// Provides: caml_plonk_domain_to_rust
// Requires: free_on_finalize
var caml_plonk_domain_to_rust = function (x, klass) {
  // TODO: Check if this gets finalized
  return new klass(x[1], x[2]);
};

// Provides: caml_plonk_verification_evals_of_rust
// Requires: caml_poly_comm_of_rust_poly_comm, js_class_vector_of_rust_vector, plonk_wasm
var caml_plonk_verification_evals_of_rust = function (x, affine_klass) {
  var convert = function (poly_comm) {
    return caml_poly_comm_of_rust_poly_comm(poly_comm, affine_klass, false);
  };

  // var convertArray = function(comms) {
  //     var n = comms.length;
  //     var res = new Array(n-1);
  //     for (var i = 1; i < n; i++) {
  //         res[i-1] = convert(comms[i]);
  //     }
  //     return js_class_vector_to_rust_vector(res);
  //   };

  // should be inverse of the above ^
  // TODO: make work for both Wasm..PolyComm types
  var convertArray = function (comms) {
    comms = js_class_vector_of_rust_vector(comms, plonk_wasm.WasmFqPolyComm);
    // comms = js_class_vector_of_rust_vector(comms, plonk_wasm.WasmFpPolyComm);
    return [0].concat(comms.map(convert));
  };

  var sigma_comm = convertArray(x.sigma_comm);
  var coefficients_comm = convertArray(x.coefficients_comm);
  var generic_comm = convert(x.generic_comm);
  var psm_comm = convert(x.psm_comm);
  var complete_add_comm = convert(x.complete_add_comm);
  var mul_comm = convert(x.mul_comm);
  var emul_comm = convert(x.emul_comm);
  var endomul_scalar_comm = convert(x.endomul_scalar_comm);

  x.free();
  return [
    0,
    sigma_comm,
    coefficients_comm,
    generic_comm,
    psm_comm,
    complete_add_comm,
    mul_comm,
    emul_comm,
    endomul_scalar_comm,
    0,
  ];
};

// Provides: caml_plonk_verification_evals_to_rust
// Requires: caml_poly_comm_to_rust_poly_comm, js_class_vector_to_rust_vector
var caml_plonk_verification_evals_to_rust = function (
  x,
  klass,
  poly_comm_to_rust
) {
  var convertArray = function (comms) {
    var n = comms.length;
    var res = new Array(n - 1);
    for (var i = 1; i < n; i++) {
      res[i - 1] = poly_comm_to_rust(comms[i]);
    }
    return js_class_vector_to_rust_vector(res);
  };

  var sigma_comm = convertArray(x[1]);
  var coefficients_comm = convertArray(x[2]);
  var generic_comm = poly_comm_to_rust(x[3]);
  var psm_comm = poly_comm_to_rust(x[4]);
  var complete_add_comm = poly_comm_to_rust(x[5]);
  var mul_comm = poly_comm_to_rust(x[6]);
  var emul_comm = poly_comm_to_rust(x[7]);
  var endomul_scalar_comm = poly_comm_to_rust(x[8]);

  return new klass(
    sigma_comm,
    coefficients_comm,
    generic_comm,
    psm_comm,
    complete_add_comm,
    mul_comm,
    emul_comm,
    endomul_scalar_comm
  );
};

// Provides: caml_plonk_verification_shifts_of_rust
var caml_plonk_verification_shifts_of_rust = function (x) {
  var res = [0, x.s0, x.s1, x.s2, x.s3, x.s4, x.s5, x.s6];
  x.free();
  return res;
};

// Provides: caml_plonk_verification_shifts_to_rust
var caml_plonk_verification_shifts_to_rust = function (x, klass) {
  return new klass(x[1], x[2], x[3], x[4], x[5], x[6], x[7]);
};

// Provides: column_of_rust
function column_of_rust(col) {
  // type nonrec column = Witness of int | Z | LookupSorted of int | LookupAggreg | LookupTable | LookupKindIndex of int | Index of gate_type | Coefficient of int
  var tag = col.tag;
  var gate_type = col.gate_type;
  var i = col.i;
  col.free();
  return (
    {
      0: [tag, i],
      2: [tag, i],
      5: [tag, i],
      6: [tag, gate_type],
      7: [tag, i],
    }[tag] || tag
  );
}

// Provides: variable_of_rust
// Requires: column_of_rust
function variable_of_rust(variable) {
  // col * row
  var col = variable.col;
  var row = variable.row; // 0, 1
  variable.free();
  return [0, column_of_rust(col), row];
}

// Provides: polish_token_of_rust
// Requires: variable_of_rust
function polish_token_of_rust(token) {
  var tag = token.tag;
  var i0 = token.i0;
  var i1 = token.i1;
  var f = token.f;
  var v = variable_of_rust(token.v);
  token.free();
  return (
    {
      5: [5, i0, i1],
      6: [6, f],
      7: [7, v],
      9: [9, i0],
      14: [14, i0],
      16: [16, i0],
    }[tag] || tag
  );
}

// Provides: index_term_of_rust
// Requires: column_of_rust, js_class_vector_of_rust_vector, polish_token_of_rust
function index_term_of_rust(term, token_class) {
  // pub column: WasmColumn,
  // pub coefficient: WasmVector<WasmPolishToken>,
  var column = column_of_rust(term.column);
  var coefficient = js_class_vector_of_rust_vector(
    term.coefficient,
    token_class
  );
  coefficient = coefficient.map(polish_token_of_rust);
  coefficient = [0].concat(coefficient);
  term.free();
  return [0, column, coefficient];
}

// Provides: wrap
function wrap(ptr, klass) {
  var obj = Object.create(klass.prototype);
  obj.ptr = ptr;
  return obj;
}

// Provides: linearization_of_rust
// Requires: plonk_wasm, js_class_vector_of_rust_vector, polish_token_of_rust, wrap, index_term_of_rust
function linearization_of_rust(linearization, affine_class) {
  var F = affine_class === plonk_wasm.WasmGVesta ? 'Fq' : 'Fp';
  var WasmPolishToken = plonk_wasm['Wasm' + F + 'PolishToken'];
  var WasmIndexTerm = plonk_wasm['Wasm' + F + 'IndexTerm'];

  var constant_term = js_class_vector_of_rust_vector(
    linearization.constant_term,
    WasmPolishToken
  );
  constant_term = constant_term.map(polish_token_of_rust);
  constant_term = [0].concat(constant_term);

  var index_terms = Array.from(linearization.index_terms).map(function (ptr) {
    var wasmIndexTerm = wrap(ptr, WasmIndexTerm);
    return index_term_of_rust(wasmIndexTerm, WasmPolishToken);
  });
  index_terms = [0].concat(index_terms);

  linearization.free();
  return [0, constant_term, index_terms];
}

// Provides: None
var None = 0;

// Provides: caml_is_none
// Requires: None
var caml_is_none = function (v) {
  return v === None;
};

// Provides: caml_map_of_rust_vector
// Requires: js_class_vector_of_rust_vector
var caml_map_of_rust_vector = function (v, klass, converter_to_rust) {
  var a = js_class_vector_of_rust_vector(v, klass);
  var res = [0];
  for (var i = 0; i < a.length; ++i) {
    res.push(converter_to_rust(a[i]));
  }
  return res;
};

// Provides: caml_opt_of_rust
// Requires: None
var caml_opt_of_rust = function (value, value_of_rust) {
  if (value === undefined) {
    return None;
  } else {
    return [0, value_of_rust(value)];
  }
};

// Provides: caml_bool_of_rust
var caml_bool_of_rust = function (bool) {
  return bool;
};

// Provides: caml_lookup_patterns_of_rust
// Requires: plonk_wasm, caml_bool_of_rust
var caml_lookup_patterns_of_rust = function (wasm_lookup_patterns) {
  return [
    0,
    caml_bool_of_rust(wasm_lookup_patterns.xor),
    caml_bool_of_rust(wasm_lookup_patterns.lookup),
    caml_bool_of_rust(wasm_lookup_patterns.range_check),
    caml_bool_of_rust(wasm_lookup_patterns.foreign_field_mul),
  ];
};

// Provides: caml_lookup_features_of_rust
// Requires: plonk_wasm, caml_lookup_patterns_of_rust, caml_bool_of_rust
var caml_lookup_features_of_rust = function (wasm_lookup_features) {
  var caml_lookup_patterns = caml_lookup_patterns_of_rust(
    wasm_lookup_features.patterns
  );
  var caml_joint_lookup_used = caml_bool_of_rust(
    wasm_lookup_features.joint_lookup_used
  );
  var caml_uses_runtime_tables = caml_bool_of_rust(
    wasm_lookup_features.uses_runtime_tables
  );

  return [
    0,
    caml_lookup_patterns,
    caml_joint_lookup_used,
    caml_uses_runtime_tables,
  ];
};

// Provides: caml_lookup_info_of_rust
// Requires: plonk_wasm, caml_lookup_features_of_rust
var caml_lookup_info_of_rust = function (wasm_lookup_info) {
  var caml_max_per_row = wasm_lookup_info.max_per_row;
  var caml_max_joint_size = wasm_lookup_info.max_joint_size;
  var caml_lookup_features = caml_lookup_features_of_rust(
    wasm_lookup_info.features
  );

  return [0, caml_max_per_row, caml_max_joint_size, caml_lookup_features];
};

// Provides: caml_lookup_selectors_of_rust
// Requires: plonk_wasm, caml_opt_of_rust
var caml_lookup_selectors_of_rust = function (
  wasm_lookup_selectors,
  poly_comm_of_rust
) {
  var xor = caml_opt_of_rust(wasm_lookup_selectors.xor, poly_comm_of_rust);
  var lookup = caml_opt_of_rust(
    wasm_lookup_selectors.lookup,
    poly_comm_of_rust
  );
  var range_check = caml_opt_of_rust(
    wasm_lookup_selectors.range_check,
    poly_comm_of_rust
  );
  var ffmul = caml_opt_of_rust(wasm_lookup_selectors.ffmul, poly_comm_of_rust);

  return [0, xor, lookup, range_check, ffmul];
};

// Provides: caml_lookup_verifier_index_of_rust
// Requires: plonk_wasm, caml_map_of_rust_vector, caml_bool_of_rust, caml_lookup_selectors_of_rust, caml_opt_of_rust, caml_lookup_info_of_rust
var caml_lookup_verifier_index_of_rust = function (
  wasm_lookup_index,
  poly_comm_class,
  poly_comm_of_rust
) {
  var caml_joint_lookup_used = caml_bool_of_rust(
    wasm_lookup_index.join_lookup_used
  );

  // lookup table
  var caml_lookup_table = caml_map_of_rust_vector(
    wasm_lookup_index.lookup_table,
    poly_comm_class,
    poly_comm_of_rust
  );

  var caml_lookup_selectors = caml_lookup_selectors_of_rust(
    wasm_lookup_index.lookup_selectors,
    poly_comm_of_rust
  );

  var caml_table_ids = caml_opt_of_rust(
    wasm_lookup_index.table_ids,
    poly_comm_of_rust
  );

  var caml_lookup_info = caml_lookup_info_of_rust(
    wasm_lookup_index.lookup_info
  );

  var caml_runtime_tables_selector = caml_opt_of_rust(
    wasm_lookup_index.runtime_tables_selector,
    poly_comm_of_rust
  );

  return [
    0,
    caml_joint_lookup_used,
    caml_lookup_table,
    caml_lookup_selectors,
    caml_table_ids,
    caml_lookup_info,
    caml_runtime_tables_selector,
  ];
};

// Provides: caml_plonk_verifier_index_of_rust
// Requires: linearization_of_rust, caml_plonk_domain_of_rust, caml_plonk_verification_evals_of_rust, caml_plonk_verification_shifts_of_rust, free_on_finalize, None, caml_opt_of_rust, caml_lookup_verifier_index_of_rust
var caml_plonk_verifier_index_of_rust = function (x, affine_class) {
  var domain = caml_plonk_domain_of_rust(x.domain);
  var max_poly_size = x.max_poly_size;
  var public_ = x.public_;
  var prev_challenges = x.prev_challenges;
  var srs = free_on_finalize(x.srs);
  var evals = caml_plonk_verification_evals_of_rust(x.evals, affine_class);
  var shifts = caml_plonk_verification_shifts_of_rust(x.shifts);
  // TODO: Handle linearization correctly!
  // var linearization = linearization_of_rust(x.linearization, affine_class);

  var caml_lookup_index = caml_opt_of_rust(
    x.lookup_index,
    caml_lookup_verifier_index_of_rust
  );
  x.free();
  return [
    0,
    domain,
    max_poly_size,
    public_,
    prev_challenges,
    srs,
    evals,
    shifts,
    caml_lookup_index,
  ];
};
// Provides: caml_plonk_verifier_index_to_rust
// Requires: caml_plonk_domain_to_rust, caml_plonk_verification_evals_to_rust, caml_plonk_verification_shifts_to_rust, free_finalization_registry, caml_plonk_lookup_verifier_index_to_rust, caml_opt_to_rust, caml_poly_comm_to_rust_poly_comm
var caml_plonk_verifier_index_to_rust = function (
  x,
  klass,
  domain_class,
  verification_evals_class,
  poly_comm_class,
  mk_affine,
  verification_shifts_class,
  lookup_verifier_index_class,
  lookup_selectors_class
) {
  // Defining how to translate polynomial commitments from OCaml back to Rust
  var poly_comm_to_rust = function (poly_comm) {
    return caml_poly_comm_to_rust_poly_comm(
      poly_comm,
      poly_comm_class,
      mk_affine
    );
  };
  var domain = caml_plonk_domain_to_rust(x[1], domain_class);
  var max_poly_size = x[2];
  var public_ = x[3];
  var prev_challenges = x[4];
  var srs = x[5];
  var evals = caml_plonk_verification_evals_to_rust(
    x[6],
    verification_evals_class,
    poly_comm_to_rust
  );
  var shifts = caml_plonk_verification_shifts_to_rust(
    x[7],
    verification_shifts_class
  );

  //////////////////////////////////////////////////////////////////////////////
  // The lookup_index_to_rust function is defined only in order to be able to //
  // use the generic caml_opt_to_rust function.                               //
  //                                                                          //
  // We could as well inline it but I preferred not having to think about     //
  // internal representation of values yet again.                             //
  //////////////////////////////////////////////////////////////////////////////
  var lookup_index_to_rust = function (lidx) {
    return caml_plonk_lookup_verifier_index_to_rust(
      lidx,
      lookup_verifier_index_class,
      poly_comm_to_rust,
      lookup_selectors_class,
      mk_affine
    );
  };

  var wasm_lookup_index = caml_opt_to_rust(x[8], lookup_index_to_rust);

  return new klass(
    domain,
    max_poly_size,
    public_,
    prev_challenges,
    srs,
    evals,
    shifts,
    wasm_lookup_index
  );
};

// Provides: caml_opt_to_rust
// Requires: caml_is_none, None
var caml_opt_to_rust = function (caml_optional_value, to_rust) {
  // to_rust expects the parameters of the variant. A `Some vx` is represented
  // as [0, vx]
  if (caml_is_none(caml_optional_value)) {
    return undefined;
  } else {
    return to_rust(caml_optional_value[1]);
  }
};

// Provides: caml_lookup_selectors_to_rust
// Requires: plonk_wasm, caml_opt_to_rust
var caml_lookup_selectors_to_rust = function (
  wasm_lookup_selectors,
  klass,
  poly_comm_to_rust
) {
  var xor = caml_opt_to_rust(wasm_lookup_selectors[1], poly_comm_to_rust);
  var lookup = caml_opt_to_rust(wasm_lookup_selectors[2], poly_comm_to_rust);
  var range_check = caml_opt_to_rust(
    wasm_lookup_selectors[3],
    poly_comm_to_rust
  );
  var ffmul = caml_opt_to_rust(wasm_lookup_selectors[4], poly_comm_to_rust);

  return new klass(xor, lookup, range_check, ffmul);
};

// Provides: caml_lookup_table_to_rust
// Requires: plonk_wasm, caml_array_to_rust_vector, rust_affine_of_caml_affine
var caml_lookup_table_to_rust = function (wasm_lookup_table, mk_affine) {
  return caml_array_to_rust_vector(
    wasm_lookup_table,
    rust_affine_of_caml_affine,
    mk_affine
  );
};

// Provides: caml_lookup_patterns_to_rust
// Requires: plonk_wasm
var caml_lookup_patterns_to_rust = function (wasm_lookup_patterns, klass) {
  var xor = wasm_lookup_patterns[1];
  var lookup = wasm_lookup_patterns[2];
  var range_check = wasm_lookup_patterns[3];
  var foreign_field_mul = wasm_lookup_patterns[4];

  return new plonk_wasm.LookupPatterns(
    xor,
    lookup,
    range_check,
    foreign_field_mul
  );
};

// Provides: caml_lookup_features_to_rust
// Requires: plonk_wasm, caml_lookup_patterns_to_rust
var caml_lookup_features_to_rust = function (wasm_lookup_features) {
  var patterns = caml_lookup_patterns_to_rust(wasm_lookup_features[1]);
  var joint_lookup_used = wasm_lookup_features[2];
  var uses_runtime_tables = wasm_lookup_features[3];

  return new plonk_wasm.LookupFeatures(
    patterns,
    joint_lookup_used,
    uses_runtime_tables
  );
};

// Provides: caml_lookup_info_to_rust
// Requires: plonk_wasm, caml_lookup_features_to_rust
var caml_lookup_info_to_rust = function (wasm_lookup_info) {
  var max_per_row = wasm_lookup_info[1];
  var max_poly_size = wasm_lookup_info[2];
  var features = caml_lookup_features_to_rust(wasm_lookup_info[3]);

  return new plonk_wasm.LookupInfo(max_per_row, max_poly_size, features);
};

// Provides: caml_plonk_lookup_verifier_index_to_rust
// Requires: plonk_wasm, caml_lookup_table_to_rust, caml_lookup_selectors_to_rust, caml_lookup_info_to_rust, caml_opt_to_rust
var caml_plonk_lookup_verifier_index_to_rust = function (
  caml_lookup_verifier_index,
  klass,
  poly_comm_to_rust,
  lookup_selectors_class,
  mk_affine
) {
  // joint_lookup_used
  var joint_lookup_used = caml_lookup_verifier_index[1];

  // lookup_table
  var lookup_table = caml_lookup_table_to_rust(
    caml_lookup_verifier_index[2],
    mk_affine
  );

  // lookup_selectors
  var lookup_selectors = caml_lookup_selectors_to_rust(
    caml_lookup_verifier_index[3],
    lookup_selectors_class,
    poly_comm_to_rust
  );

  // table_ids
  var table_ids = caml_opt_to_rust(
    caml_lookup_verifier_index[4],
    poly_comm_to_rust
  );

  // lookup_info
  var lookup_info = caml_lookup_info_to_rust(caml_lookup_verifier_index[5]);

  // runtime_tables_selector
  var runtime_tables_selector = caml_opt_to_rust(
    caml_lookup_verifier_index[6],
    poly_comm_to_rust
  );

  return new klass(
    joint_lookup_used,
    lookup_table,
    lookup_selectors,
    table_ids,
    lookup_info,
    runtime_tables_selector
  );
};

// Provides: caml_pasta_fp_plonk_verifier_index_of_rust
// Requires: plonk_wasm, caml_plonk_verifier_index_of_rust
var caml_pasta_fp_plonk_verifier_index_of_rust = function (x) {
  return caml_plonk_verifier_index_of_rust(x, plonk_wasm.WasmGVesta);
};

// Provides: caml_pasta_fp_plonk_verifier_index_to_rust
// Requires: plonk_wasm, caml_plonk_verifier_index_to_rust
var caml_pasta_fp_plonk_verifier_index_to_rust = function (x) {
  return caml_plonk_verifier_index_to_rust(
    x,
    plonk_wasm.WasmFpPlonkVerifierIndex,
    plonk_wasm.WasmFpDomain,
    plonk_wasm.WasmFpPlonkVerificationEvals,
    plonk_wasm.WasmFpPolyComm,
    plonk_wasm.caml_vesta_affine_one,
    plonk_wasm.WasmFpShifts,
    plonk_wasm.WasmFpLookupVerifierIndex,
    plonk_wasm.WasmFpLookupSelectors
  );
};

// Provides: caml_pasta_fp_plonk_verifier_index_create
// Requires: plonk_wasm, caml_pasta_fp_plonk_verifier_index_of_rust
var caml_pasta_fp_plonk_verifier_index_create = function (x) {
  var vk = plonk_wasm.caml_pasta_fp_plonk_verifier_index_create(x);
  var vk_caml = caml_pasta_fp_plonk_verifier_index_of_rust(vk);
  return vk_caml;
};

// Provides: caml_pasta_fp_plonk_verifier_index_read
// Requires: plonk_wasm, caml_jsstring_of_string, caml_pasta_fp_plonk_verifier_index_of_rust
var caml_pasta_fp_plonk_verifier_index_read = function (offset, urs, path) {
  if (offset === 0) {
    offset = undefined;
  } else {
    offset = offset[1];
  }
  return caml_pasta_fp_plonk_verifier_index_of_rust(
    plonk_wasm.caml_pasta_fp_plonk_verifier_index_read(
      offset,
      urs,
      caml_jsstring_of_string(path)
    )
  );
};

// Provides: caml_pasta_fp_plonk_verifier_index_write
// Requires: plonk_wasm, caml_jsstring_of_string, caml_pasta_fp_plonk_verifier_index_to_rust
var caml_pasta_fp_plonk_verifier_index_write = function (append, t, path) {
  if (append === 0) {
    append = undefined;
  } else {
    append = append[1];
  }
  return plonk_wasm.caml_pasta_fp_plonk_verifier_index_write(
    append,
    caml_pasta_fp_plonk_verifier_index_to_rust(t),
    caml_jsstring_of_string(path)
  );
};

// Provides: caml_pasta_fp_plonk_verifier_index_shifts
// Requires: plonk_wasm, caml_plonk_verification_shifts_of_rust
var caml_pasta_fp_plonk_verifier_index_shifts = function (log2_size) {
  return caml_plonk_verification_shifts_of_rust(
    plonk_wasm.caml_pasta_fp_plonk_verifier_index_shifts(log2_size)
  );
};

// Provides: caml_pasta_fp_plonk_verifier_index_dummy
// Requires: plonk_wasm, caml_pasta_fp_plonk_verifier_index_of_rust
var caml_pasta_fp_plonk_verifier_index_dummy = function () {
  var res = plonk_wasm.caml_pasta_fp_plonk_verifier_index_dummy();
  return caml_pasta_fp_plonk_verifier_index_of_rust(res);
  // return caml_pasta_fp_plonk_verifier_index_of_rust(plonk_wasm.caml_pasta_fp_plonk_verifier_index_dummy());
};

// Provides: caml_pasta_fp_plonk_verifier_index_deep_copy
// Requires: plonk_wasm, caml_pasta_fp_plonk_verifier_index_of_rust, caml_pasta_fp_plonk_verifier_index_to_rust
var caml_pasta_fp_plonk_verifier_index_deep_copy = function (x) {
  return caml_pasta_fp_plonk_verifier_index_of_rust(
    plonk_wasm.caml_pasta_fp_plonk_verifier_index_deep_copy(
      caml_pasta_fp_plonk_verifier_index_to_rust(x)
    )
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_of_rust
// Requires: plonk_wasm, caml_plonk_verifier_index_of_rust
var caml_pasta_fq_plonk_verifier_index_of_rust = function (x) {
  return caml_plonk_verifier_index_of_rust(x, plonk_wasm.WasmGPallas);
};

// Provides: caml_pasta_fq_plonk_verifier_index_to_rust
// Requires: plonk_wasm, caml_plonk_verifier_index_to_rust
var caml_pasta_fq_plonk_verifier_index_to_rust = function (x) {
  return caml_plonk_verifier_index_to_rust(
    x,
    plonk_wasm.WasmFqPlonkVerifierIndex,
    plonk_wasm.WasmFqDomain,
    plonk_wasm.WasmFqPlonkVerificationEvals,
    plonk_wasm.WasmFqPolyComm,
    plonk_wasm.caml_pallas_affine_one,
    plonk_wasm.WasmFqShifts,
    plonk_wasm.WasmFqLookupVerifierIndex,
    plonk_wasm.WasmFqLookupSelectors
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_create
// Requires: plonk_wasm, caml_pasta_fq_plonk_verifier_index_of_rust
var caml_pasta_fq_plonk_verifier_index_create = function (x) {
  return caml_pasta_fq_plonk_verifier_index_of_rust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_create(x)
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_read
// Requires: plonk_wasm, caml_jsstring_of_string, caml_pasta_fq_plonk_verifier_index_of_rust
var caml_pasta_fq_plonk_verifier_index_read = function (offset, urs, path) {
  if (offset === 0) {
    offset = undefined;
  } else {
    offset = offset[1];
  }
  return caml_pasta_fq_plonk_verifier_index_of_rust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_read(
      offset,
      urs,
      caml_jsstring_of_string(path)
    )
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_write
// Requires: plonk_wasm, caml_jsstring_of_string, caml_pasta_fq_plonk_verifier_index_to_rust
var caml_pasta_fq_plonk_verifier_index_write = function (append, t, path) {
  if (append === 0) {
    append = undefined;
  } else {
    append = append[1];
  }
  return plonk_wasm.caml_pasta_fq_plonk_verifier_index_write(
    append,
    caml_pasta_fq_plonk_verifier_index_to_rust(t),
    caml_jsstring_of_string(path)
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_shifts
// Requires: plonk_wasm, caml_plonk_verification_shifts_of_rust
var caml_pasta_fq_plonk_verifier_index_shifts = function (log2_size) {
  return caml_plonk_verification_shifts_of_rust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_shifts(log2_size)
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_dummy
// Requires: plonk_wasm, caml_pasta_fq_plonk_verifier_index_of_rust
var caml_pasta_fq_plonk_verifier_index_dummy = function () {
  return caml_pasta_fq_plonk_verifier_index_of_rust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_dummy()
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_deep_copy
// Requires: plonk_wasm, caml_pasta_fq_plonk_verifier_index_of_rust, caml_pasta_fq_plonk_verifier_index_to_rust
var caml_pasta_fq_plonk_verifier_index_deep_copy = function (x) {
  return caml_pasta_fq_plonk_verifier_index_of_rust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_deep_copy(
      caml_pasta_fq_plonk_verifier_index_to_rust(x)
    )
  );
};

// Provides: COLUMNS
var COLUMNS = 15;
// Provides: PERMUTS_MINUS_1
var PERMUTS_MINUS_1 = 6;

// Provides: caml_pasta_fp_proof_evaluations_to_rust
// Requires: plonk_wasm, caml_fp_vector_to_rust, PERMUTS_MINUS_1, COLUMNS
var caml_pasta_fp_proof_evaluations_to_rust = function (x) {
  return x;
};

// Provides: caml_pasta_fp_proof_evaluations_of_rust
// Requires: plonk_wasm, caml_fp_vector_of_rust, COLUMNS, PERMUTS_MINUS_1
var caml_pasta_fp_proof_evaluations_of_rust = function (x) {
  return x;
};

// Provides: caml_pasta_fp_opening_proof_to_rust
// Requires: plonk_wasm, caml_array_to_rust_vector, rust_affine_of_caml_affine
var caml_pasta_fp_opening_proof_to_rust = function (x) {
  var convert_affines = function (affines) {
    return caml_array_to_rust_vector(
      affines,
      rust_affine_of_caml_affine,
      plonk_wasm.caml_vesta_affine_one
    );
  };
  var lr = x[1];
  var delta = rust_affine_of_caml_affine(
    x[2],
    plonk_wasm.caml_vesta_affine_one
  );
  var z1 = x[3];
  var z2 = x[4];
  var sg = rust_affine_of_caml_affine(x[5], plonk_wasm.caml_vesta_affine_one);
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
  return new plonk_wasm.WasmFpOpeningProof(l, r, delta, z1, z2, sg);
};

// Provides: caml_pasta_fp_opening_proof_of_rust
// Requires: plonk_wasm, caml_array_of_rust_vector, rust_affine_to_caml_affine
var caml_pasta_fp_opening_proof_of_rust = function (x) {
  var convert_affines = function (affines) {
    return caml_array_of_rust_vector(
      affines,
      plonk_wasm.WasmGVesta,
      rust_affine_to_caml_affine,
      false
    );
  };
  var l = convert_affines(x.lr_0);
  var r = convert_affines(x.lr_1);
  var delta = rust_affine_to_caml_affine(x.delta);
  var z1 = x.z1;
  var z2 = x.z2;
  var sg = rust_affine_to_caml_affine(x.sg);
  x.free();
  var len = l.length;
  if (len !== r.length) {
    throw new Error("l and r lengths don't match");
  }
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

// Provides: caml_fp_lookup_commitments_to_rust
// Requires: plonk_wasm, caml_vesta_poly_comm_to_rust, js_class_vector_to_rust_vector, caml_opt_to_rust
var caml_fp_lookup_commitments_to_rust = function (caml_lc) {
  var convertArray = function (v) {
    var n = v.length - 1;
    var res = new Array(n);
    for (var i = 0; i < n; ++i) {
      res[i] = caml_vesta_poly_comm_to_rust(v[i + 1]);
    }
    return js_class_vector_to_rust_vector(res);
  };

  var wasm_sorted = convertArray(caml_lc[1]);
  var wasm_aggreg = caml_vesta_poly_comm_to_rust(caml_lc[2]);
  var wasm_runtime;
  if (caml_lc[3] === 0) {
    wasm_runtime = undefined;
  } else {
    wasm_runtime = caml_vesta_poly_comm_to_rust(caml_lc[3][1]);
  }
  return plonk_wasm.WasmFpLookupCommitments(
    wasm_sorted,
    wasm_aggreg,
    wasm_runtime
  );
};

// Provides: caml_pasta_fp_commitments_to_rust
// Requires: plonk_wasm, caml_vesta_poly_comm_to_rust, js_class_vector_to_rust_vector, caml_fp_lookup_commitments_to_rust, caml_opt_to_rust
var caml_pasta_fp_commitments_to_rust = function (x) {
  var convertArray = function (v) {
    var n = v.length - 1;
    var res = new Array(n);
    for (var i = 0; i < n; ++i) {
      res[i] = caml_vesta_poly_comm_to_rust(v[i + 1]);
    }
    // TODO need to do finalizer things?
    return js_class_vector_to_rust_vector(res);
  };

  var w_comm = convertArray(x[1]);
  var z_comm = caml_vesta_poly_comm_to_rust(x[2]);
  var t_comm = caml_vesta_poly_comm_to_rust(x[3]);
  var lookup = caml_opt_to_rust(x[4], caml_fp_lookup_commitments_to_rust);
  return new plonk_wasm.WasmFpProverCommitments(w_comm, z_comm, t_comm, lookup);
};

// Provides: caml_fp_lookup_commitments_of_rust
// Requires: caml_vesta_poly_comm_of_rust, js_class_vector_of_rust_vector, plonk_wasm
var caml_fp_lookup_commitments_of_rust = function (wasm_lc) {
  var convertArray = function (v) {
    var a = js_class_vector_of_rust_vector(v, plonk_wasm.WasmFpPolyComm);
    var res = [0];
    for (var i = 0; i < a.length; ++i) {
      res.push(caml_vesta_poly_comm_of_rust(a[i]));
    }
    return res;
  };

  var sorted = convertArray(wasm_lc.sorted);
  var aggreg = caml_vesta_poly_comm_of_rust(wasm_lc.aggreg);
  var wasm_lc_runtime = wasm_lc.runtime;
  var caml_runtime;
  if (wasm_lc_runtime === undefined) {
    caml_runtime = 0;
  } else {
    caml_runtime = [0, caml_vesta_poly_comm_of_rust(wasm_lc_runtime)];
  }
  wasm_lc.free();
  return [0, sorted, aggreg, caml_runtime];
};

// Provides: caml_pasta_fp_commitments_of_rust
// Requires: caml_vesta_poly_comm_of_rust, js_class_vector_of_rust_vector, plonk_wasm, caml_fp_lookup_commitments_of_rust, caml_opt_of_rust
var caml_pasta_fp_commitments_of_rust = function (x) {
  var convertArray = function (v) {
    var a = js_class_vector_of_rust_vector(v, plonk_wasm.WasmFpPolyComm);
    var res = [0];
    for (var i = 0; i < a.length; ++i) {
      // TODO Check this. Could be off by 1
      res.push(caml_vesta_poly_comm_of_rust(a[i]));
    }
    return res;
  };

  var w_comm = convertArray(x.w_comm);
  var z_comm = caml_vesta_poly_comm_of_rust(x.z_comm);
  var t_comm = caml_vesta_poly_comm_of_rust(x.t_comm);
  var caml_lookup = caml_opt_of_rust(
    x.lookup,
    caml_fp_lookup_commitments_of_rust
  );
  x.free();
  return [0, w_comm, z_comm, t_comm, caml_lookup];
};

// Provides: caml_pasta_fp_proof_to_rust
// Requires: plonk_wasm, caml_pasta_fp_commitments_to_rust, caml_pasta_fp_opening_proof_to_rust, caml_pasta_fp_proof_evaluations_to_rust, caml_fp_vector_to_rust, caml_vesta_poly_comm_to_rust, js_class_vector_to_rust_vector
var caml_pasta_fp_proof_to_rust = function (x) {
  var commitments = caml_pasta_fp_commitments_to_rust(x[1]);
  var proof = caml_pasta_fp_opening_proof_to_rust(x[2]);
  var evals = caml_pasta_fp_proof_evaluations_to_rust(x[3]);
  var ft_eval1 = x[4];
  var public_ = caml_fp_vector_to_rust(x[5]);
  var prev_challenges = x[6];
  var chals_len = prev_challenges.length;
  var prev_challenges_scalars = new plonk_wasm.WasmVecVecFp(chals_len - 1);
  var prev_challenges_comms = new Array(chals_len - 1);
  for (var i = 1; i < chals_len; i++) {
    prev_challenges_scalars.push(caml_fp_vector_to_rust(prev_challenges[i][1]));
    prev_challenges_comms[i - 1] = caml_vesta_poly_comm_to_rust(
      prev_challenges[i][2]
    );
  }
  prev_challenges_comms = js_class_vector_to_rust_vector(prev_challenges_comms);
  return new plonk_wasm.WasmFpProverProof(
    commitments,
    proof,
    evals,
    ft_eval1,
    public_,
    prev_challenges_scalars,
    prev_challenges_comms
  );
};

// Provides: caml_pasta_fp_proof_of_rust
// Requires: plonk_wasm, caml_pasta_fp_commitments_of_rust, caml_pasta_fp_opening_proof_of_rust, caml_pasta_fp_proof_evaluations_of_rust, caml_fp_vector_of_rust, js_class_vector_of_rust_vector, caml_vesta_poly_comm_of_rust
var caml_pasta_fp_proof_of_rust = function (x) {
  var messages = caml_pasta_fp_commitments_of_rust(x.commitments);
  var proof = caml_pasta_fp_opening_proof_of_rust(x.proof);
  var evals = caml_pasta_fp_proof_evaluations_of_rust(x.evals);
  var ft_eval1 = x.ft_eval1;
  var public_ = caml_fp_vector_of_rust(x.public_);
  var prev_challenges_scalars = x.prev_challenges_scalars;
  var prev_challenges_comms = js_class_vector_of_rust_vector(
    x.prev_challenges_comms,
    plonk_wasm.WasmFpPolyComm
  );
  var chals_len = prev_challenges_comms.length;
  var prev_challenges = new Array(chals_len);
  prev_challenges[0] = 0;
  for (var i = 1; i < chals_len; i++) {
    var res = new Array(3);
    res[0] = 0;
    res[1] = caml_fp_vector_of_rust(prev_challenges_scalars.get(i - 1));
    // TODO Check this. Could be off by 1
    res[2] = caml_vesta_poly_comm_of_rust(prev_challenges_comms[i]);
    prev_challenges[i] = res;
  }
  return [0, messages, proof, evals, ft_eval1, public_, prev_challenges];
};

// Provides: caml_pasta_fp_plonk_proof_create
// Requires: plonk_wasm, caml_fp_vector_to_rust, caml_array_to_rust_vector, rust_affine_of_caml_affine, caml_pasta_fp_proof_of_rust
var caml_pasta_fp_plonk_proof_create = function (
  index,
  witness_cols,
  prev_challenges,
  prev_sgs
) {
  var w = new plonk_wasm.WasmVecVecFp(witness_cols.length - 1);
  for (var i = 1; i < witness_cols.length; i++) {
    w.push(caml_fp_vector_to_rust(witness_cols[i]));
  }
  witness_cols = w;
  prev_challenges = caml_fp_vector_to_rust(prev_challenges);
  prev_sgs = caml_array_to_rust_vector(
    prev_sgs,
    rust_affine_of_caml_affine,
    plonk_wasm.caml_vesta_affine_one
  );
  var res = plonk_wasm.caml_pasta_fp_plonk_proof_create(
    index,
    witness_cols,
    prev_challenges,
    prev_sgs
  );
  var proof = caml_pasta_fp_proof_of_rust(res);
  return proof;
};

// Provides: caml_pasta_fp_plonk_proof_verify
// Requires: plonk_wasm, caml_array_to_rust_vector, caml_vesta_poly_comm_to_rust, caml_pasta_fp_plonk_verifier_index_to_rust, caml_pasta_fp_proof_to_rust
var caml_pasta_fp_plonk_proof_verify = function (index, proof) {
  index = caml_pasta_fp_plonk_verifier_index_to_rust(index);
  proof = caml_pasta_fp_proof_to_rust(proof);
  return plonk_wasm.caml_pasta_fp_plonk_proof_verify(index, proof);
};

// Provides: caml_pasta_fp_plonk_proof_batch_verify
// Requires: plonk_wasm, caml_array_to_rust_vector, caml_vesta_poly_comm_to_rust, caml_pasta_fp_plonk_verifier_index_to_rust, caml_pasta_fp_proof_to_rust
var caml_pasta_fp_plonk_proof_batch_verify = function (indexes, proofs) {
  indexes = caml_array_to_rust_vector(
    indexes,
    caml_pasta_fp_plonk_verifier_index_to_rust
  );
  proofs = caml_array_to_rust_vector(proofs, caml_pasta_fp_proof_to_rust);
  return plonk_wasm.caml_pasta_fp_plonk_proof_batch_verify(indexes, proofs);
};

// Provides: caml_pasta_fp_plonk_proof_dummy
// Requires: plonk_wasm, caml_pasta_fp_proof_of_rust
var caml_pasta_fp_plonk_proof_dummy = function () {
  return caml_pasta_fp_proof_of_rust(
    plonk_wasm.caml_pasta_fp_plonk_proof_dummy()
  );
};

// Provides: caml_pasta_fp_plonk_proof_deep_copy
// Requires: plonk_wasm, caml_pasta_fp_proof_to_rust, caml_pasta_fp_proof_of_rust
var caml_pasta_fp_plonk_proof_deep_copy = function (proof) {
  return caml_pasta_fp_proof_of_rust(
    plonk_wasm.caml_pasta_fp_plonk_proof_deep_copy(
      caml_pasta_fp_proof_to_rust(proof)
    )
  );
};

// Provides: caml_pasta_fq_proof_evaluations_to_rust
// Requires: plonk_wasm, caml_fq_vector_to_rust, PERMUTS_MINUS_1, COLUMNS
var caml_pasta_fq_proof_evaluations_to_rust = function (x) {
  return x;
};

// Provides: caml_pasta_fq_proof_evaluations_of_rust
// Requires: plonk_wasm, caml_fq_vector_of_rust, COLUMNS, PERMUTS_MINUS_1
var caml_pasta_fq_proof_evaluations_of_rust = function (x) {
  return x;
};

// Provides: caml_pasta_fq_opening_proof_to_rust
// Requires: plonk_wasm, caml_array_to_rust_vector, rust_affine_of_caml_affine
var caml_pasta_fq_opening_proof_to_rust = function (x) {
  var convert_affines = function (affines) {
    return caml_array_to_rust_vector(
      affines,
      rust_affine_of_caml_affine,
      plonk_wasm.caml_pallas_affine_one
    );
  };
  var lr = x[1];
  var delta = rust_affine_of_caml_affine(
    x[2],
    plonk_wasm.caml_pallas_affine_one
  );
  var z1 = x[3];
  var z2 = x[4];
  var sg = rust_affine_of_caml_affine(x[5], plonk_wasm.caml_pallas_affine_one);
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
  return new plonk_wasm.WasmFqOpeningProof(l, r, delta, z1, z2, sg);
};

// Provides: caml_pasta_fq_opening_proof_of_rust
// Requires: plonk_wasm, caml_array_of_rust_vector, rust_affine_to_caml_affine
var caml_pasta_fq_opening_proof_of_rust = function (x) {
  var convert_affines = function (affines) {
    return caml_array_of_rust_vector(
      affines,
      plonk_wasm.WasmGPallas,
      rust_affine_to_caml_affine,
      false
    );
  };
  var l = convert_affines(x.lr_0);
  var r = convert_affines(x.lr_1);
  var delta = rust_affine_to_caml_affine(x.delta);
  var z1 = x.z1;
  var z2 = x.z2;
  var sg = rust_affine_to_caml_affine(x.sg);
  x.free();
  var len = l.length;
  if (len !== r.length) {
    throw new Error("l and r lengths don't match");
  }
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

// Provides: caml_fq_lookup_commitments_to_rust
// Requires: plonk_wasm, caml_pallas_poly_comm_to_rust, js_class_vector_to_rust_vector, caml_opt_to_rust
var caml_fq_lookup_commitments_to_rust = function (caml_lc) {
  var convertArray = function (v) {
    var n = v.length - 1;
    var res = new Array(n);
    for (var i = 0; i < n; ++i) {
      res[i] = caml_pallas_poly_comm_to_rust(v[i + 1]);
    }
    return js_class_vector_to_rust_vector(res);
  };

  var wasm_sorted = convertArray(caml_lc[1]);
  var wasm_aggreg = caml_pallas_poly_comm_to_rust(caml_lc[2]);
  var wasm_runtime = caml_opt_to_rust(
    caml_lc[3],
    caml_pallas_poly_comm_to_rust
  );
  return plonk_wasm.WasmFqLookupCommitments(
    wasm_sorted,
    wasm_aggreg,
    wasm_runtime
  );
};

// Provides: caml_pasta_fq_commitments_to_rust
// Requires: plonk_wasm, caml_pallas_poly_comm_to_rust, js_class_vector_to_rust_vector, caml_fq_lookup_commitments_to_rust, caml_opt_to_rust
var caml_pasta_fq_commitments_to_rust = function (x) {
  var convertArray = function (v) {
    var n = v.length - 1;
    var res = new Array(n);
    for (var i = 0; i < n; ++i) {
      res[i] = caml_pallas_poly_comm_to_rust(v[i + 1]);
    }
    return js_class_vector_to_rust_vector(res);
  };

  var w_comm = convertArray(x[1]);
  var z_comm = caml_pallas_poly_comm_to_rust(x[2]);
  var t_comm = caml_pallas_poly_comm_to_rust(x[3]);
  var lookup = caml_opt_to_rust(x[4], caml_fq_lookup_commitments_to_rust);
  return new plonk_wasm.WasmFqProverCommitments(w_comm, z_comm, t_comm, lookup);
};

// Provides: caml_fq_lookup_commitments_of_rust
// Requires: caml_pallas_poly_comm_of_rust, js_class_vector_of_rust_vector, plonk_wasm
var caml_fq_lookup_commitments_of_rust = function (wasm_lc) {
  var convertArray = function (v) {
    var a = js_class_vector_of_rust_vector(v, plonk_wasm.WasmFqPolyComm);
    var res = [0];
    for (var i = 0; i < a.length; ++i) {
      res.push(caml_pallas_poly_comm_of_rust(a[i]));
    }
    return res;
  };

  var sorted = convertArray(wasm_lc.sorted);
  var aggreg = caml_pallas_poly_comm_of_rust(wasm_lc.aggreg);
  var wasm_lc_runtime = wasm_lc.runtime;
  var caml_runtime;
  if (wasm_lc_runtime === undefined) {
    caml_runtime = 0;
  } else {
    caml_runtime = [0, caml_pallas_poly_comm_of_rust(wasm_lc_runtime)];
  }
  wasm_lc.free();
  return [0, sorted, aggreg, caml_runtime];
};

// Provides: caml_pasta_fq_commitments_of_rust
// Requires: caml_pallas_poly_comm_of_rust, js_class_vector_of_rust_vector, plonk_wasm, caml_fq_lookup_commitments_of_rust, caml_opt_of_rust
var caml_pasta_fq_commitments_of_rust = function (x) {
  var convertArray = function (v) {
    var a = js_class_vector_of_rust_vector(v, plonk_wasm.WasmFqPolyComm);
    var res = [0];
    for (var i = 0; i < a.length; ++i) {
      // TODO Check this. Could be off by 1
      res.push(caml_pallas_poly_comm_of_rust(a[i]));
    }
    return res;
  };

  var w_comm = convertArray(x.w_comm);
  var z_comm = caml_pallas_poly_comm_of_rust(x.z_comm);
  var t_comm = caml_pallas_poly_comm_of_rust(x.t_comm);
  var caml_lookup = caml_opt_of_rust(
    x.lookup,
    caml_fq_lookup_commitments_of_rust
  );
  x.free();
  return [0, w_comm, z_comm, t_comm, caml_lookup];
};

// Provides: caml_pasta_fq_proof_to_rust
// Requires: plonk_wasm, caml_pasta_fq_commitments_to_rust, caml_pasta_fq_opening_proof_to_rust, caml_pasta_fq_proof_evaluations_to_rust, caml_fq_vector_to_rust, caml_pallas_poly_comm_to_rust, js_class_vector_to_rust_vector
var caml_pasta_fq_proof_to_rust = function (x) {
  var messages = caml_pasta_fq_commitments_to_rust(x[1]);
  var proof = caml_pasta_fq_opening_proof_to_rust(x[2]);
  var evals = caml_pasta_fq_proof_evaluations_to_rust(x[3]);
  var ft_eval1 = x[4];
  var public_ = caml_fq_vector_to_rust(x[5]);
  var prev_challenges = x[6];
  var chals_len = prev_challenges.length;
  var prev_challenges_scalars = new plonk_wasm.WasmVecVecFq(chals_len - 1);
  var prev_challenges_comms = new Array(chals_len - 1);
  for (var i = 1; i < chals_len; i++) {
    prev_challenges_scalars.push(caml_fq_vector_to_rust(prev_challenges[i][1]));
    prev_challenges_comms[i - 1] = caml_pallas_poly_comm_to_rust(
      prev_challenges[i][2]
    );
  }
  prev_challenges_comms = js_class_vector_to_rust_vector(prev_challenges_comms);
  return new plonk_wasm.WasmFqProverProof(
    messages,
    proof,
    evals,
    ft_eval1,
    public_,
    prev_challenges_scalars,
    prev_challenges_comms
  );
};

// Provides: caml_pasta_fq_proof_of_rust
// Requires: plonk_wasm, caml_pasta_fq_commitments_of_rust, caml_pasta_fq_opening_proof_of_rust, caml_pasta_fq_proof_evaluations_of_rust, caml_fq_vector_of_rust, js_class_vector_of_rust_vector, caml_pallas_poly_comm_of_rust
var caml_pasta_fq_proof_of_rust = function (x) {
  var messages = caml_pasta_fq_commitments_of_rust(x.commitments);
  var proof = caml_pasta_fq_opening_proof_of_rust(x.proof);
  var evals = caml_pasta_fq_proof_evaluations_of_rust(x.evals);
  var evals1 = caml_pasta_fq_proof_evaluations_of_rust(x.evals1);
  var ft_eval1 = x.ft_eval1;
  var public_ = caml_fq_vector_of_rust(x.public_);
  var prev_challenges_scalars = x.prev_challenges_scalars;
  var prev_challenges_comms = js_class_vector_of_rust_vector(
    x.prev_challenges_comms,
    plonk_wasm.WasmFqPolyComm
  );
  var chals_len = prev_challenges_comms.length;
  var prev_challenges = new Array(chals_len);
  prev_challenges[0] = 0;
  for (var i = 1; i < chals_len; i++) {
    var res = new Array(3);
    res[0] = 0;
    res[1] = caml_fq_vector_of_rust(prev_challenges_scalars.get(i - 1));
    res[2] = caml_pallas_poly_comm_of_rust(prev_challenges_comms[i]);
    prev_challenges[i] = res;
  }
  return [0, messages, proof, evals, ft_eval1, public_, prev_challenges];
};

// Provides: caml_pasta_fq_plonk_proof_create
// Requires: plonk_wasm, caml_fq_vector_to_rust, caml_array_to_rust_vector, rust_affine_of_caml_affine, caml_pasta_fq_proof_of_rust
var caml_pasta_fq_plonk_proof_create = function (
  index,
  witness_cols,
  prev_challenges,
  prev_sgs
) {
  var w = new plonk_wasm.WasmVecVecFq(witness_cols.length - 1);
  for (var i = 1; i < witness_cols.length; i++) {
    w.push(caml_fq_vector_to_rust(witness_cols[i]));
  }
  witness_cols = w;
  prev_challenges = caml_fq_vector_to_rust(prev_challenges);
  prev_sgs = caml_array_to_rust_vector(
    prev_sgs,
    rust_affine_of_caml_affine,
    plonk_wasm.caml_pallas_affine_one
  );
  var res = plonk_wasm.caml_pasta_fq_plonk_proof_create(
    index,
    witness_cols,
    prev_challenges,
    prev_sgs
  );
  var proof = caml_pasta_fq_proof_of_rust(res);
  return proof;
};

// Provides: caml_pasta_fq_plonk_proof_verify
// Requires: plonk_wasm, caml_array_to_rust_vector, caml_pallas_poly_comm_to_rust, caml_pasta_fq_plonk_verifier_index_to_rust, caml_pasta_fq_proof_to_rust
var caml_pasta_fq_plonk_proof_verify = function (index, proof) {
  index = caml_pasta_fq_plonk_verifier_index_to_rust(index);
  proof = caml_pasta_fq_proof_to_rust(proof);
  return plonk_wasm.caml_pasta_fq_plonk_proof_verify(index, proof);
};

// Provides: caml_pasta_fq_plonk_proof_batch_verify
// Requires: plonk_wasm, caml_array_to_rust_vector, caml_pallas_poly_comm_to_rust, caml_pasta_fq_plonk_verifier_index_to_rust, caml_pasta_fq_proof_to_rust
var caml_pasta_fq_plonk_proof_batch_verify = function (indexes, proofs) {
  indexes = caml_array_to_rust_vector(
    indexes,
    caml_pasta_fq_plonk_verifier_index_to_rust
  );
  proofs = caml_array_to_rust_vector(proofs, caml_pasta_fq_proof_to_rust);
  return plonk_wasm.caml_pasta_fq_plonk_proof_batch_verify(indexes, proofs);
};

// Provides: caml_pasta_fq_plonk_proof_dummy
// Requires: plonk_wasm, caml_pasta_fq_proof_of_rust
var caml_pasta_fq_plonk_proof_dummy = function () {
  return caml_pasta_fq_proof_of_rust(
    plonk_wasm.caml_pasta_fq_plonk_proof_dummy()
  );
};

// Provides: caml_pasta_fq_plonk_proof_deep_copy
// Requires: plonk_wasm, caml_pasta_fq_proof_to_rust, caml_pasta_fq_proof_of_rust
var caml_pasta_fq_plonk_proof_deep_copy = function (proof) {
  return caml_pasta_fq_proof_of_rust(
    plonk_wasm.caml_pasta_fq_plonk_proof_deep_copy(
      caml_pasta_fq_proof_to_rust(proof)
    )
  );
};

// Provides: caml_random_oracles_of_rust
// Requires: caml_u8array_vector_of_rust_flat_vector, caml_option_of_maybe_undefined
var caml_random_oracles_of_rust = function (x) {
  var joint_combiner_chal = x.joint_combiner_chal;
  var joint_combiner = x.joint_combiner;
  var joint_combiner_ocaml = undefined;
  if (joint_combiner_chal !== undefined && joint_combiner !== undefined) {
    joint_combiner_ocaml = [0, [0, joint_combiner_chal], joint_combiner];
  }
  return [
    0,
    caml_option_of_maybe_undefined(joint_combiner_ocaml),
    x.beta,
    x.gamma,
    [0, x.alpha_chal],
    x.alpha,
    x.zeta,
    x.v,
    x.u,
    [0, x.zeta_chal],
    [0, x.v_chal],
    [0, x.u_chal],
  ];
};

// Provides: caml_random_oracles_to_rust
// Requires: caml_u8array_vector_to_rust_flat_vector, caml_option_to_maybe_undefined
var caml_random_oracles_to_rust = function (x, roKlass) {
  // var caml_vector = [0, x[1], x[2], x[3][1], x[4], x[5], x[6], x[7], x[8][1], x[9][1], x[10][1]];
  var joint_combiner_ocaml = caml_option_to_maybe_undefined(x[1]);
  var joint_combiner_chal = undefined;
  var joint_combiner = undefined;
  if (joint_combiner_ocaml !== undefined) {
    joint_combiner_chal = joint_combiner_ocaml[1][1];
    joint_combiner = joint_combiner_ocaml[2];
  }
  return new roKlass(
    joint_combiner_chal,
    joint_combiner,
    x[2],
    x[3],
    x[4][1],
    x[5],
    x[6],
    x[7],
    x[8],
    x[9][1],
    x[10][1],
    x[11][1]
  );
};

// Provides: caml_oracles_of_rust
// Requires: caml_u8array_vector_of_rust_flat_vector, caml_random_oracles_of_rust
var caml_oracles_of_rust = function (x) {
  return [
    0,
    caml_random_oracles_of_rust(x.o),
    [0, x.p_eval0, x.p_eval1],
    caml_u8array_vector_of_rust_flat_vector(
      x.opening_prechallenges,
      32 /* TODO: Don't hardcode */
    ),
    x.digest_before_evaluations,
  ];
};

// Provides: caml_oracles_to_rust
// Requires: caml_u8array_vector_to_rust_flat_vector, caml_random_oracles_to_rust
var caml_oracles_to_rust = function (x, klass, roKlass) {
  return new klass(
    caml_random_oracles_to_rust(x[1], roKlass),
    x[2][1],
    x[2][2],
    caml_u8array_vector_to_rust_flat_vector(x[3]),
    x[4]
  );
};

// Provides: fp_oracles_create
// Requires: plonk_wasm, caml_oracles_of_rust, caml_array_to_rust_vector, caml_vesta_poly_comm_to_rust, caml_pasta_fp_plonk_verifier_index_to_rust, caml_pasta_fp_proof_to_rust
var fp_oracles_create = function (lgr_comm, verifier_index, proof) {
  return caml_oracles_of_rust(
    plonk_wasm.fp_oracles_create(
      caml_array_to_rust_vector(lgr_comm, caml_vesta_poly_comm_to_rust),
      caml_pasta_fp_plonk_verifier_index_to_rust(verifier_index),
      caml_pasta_fp_proof_to_rust(proof)
    )
  );
};

// Provides: fp_oracles_dummy
// Requires: plonk_wasm, caml_oracles_of_rust
var fp_oracles_dummy = function () {
  return caml_oracles_of_rust(plonk_wasm.fp_oracles_dummy());
};

// Provides: fp_oracles_deep_copy
// Requires: plonk_wasm, caml_oracles_of_rust, caml_oracles_to_rust
var fp_oracles_deep_copy = function (x) {
  return caml_oracles_of_rust(
    plonk_wasm.fp_oracles_deep_copy(
      caml_oracles_to_rust(
        x,
        plonk_wasm.WasmFpOracles,
        plonk_wasm.WasmFpRandomOracles
      )
    )
  );
};

// Provides: fq_oracles_create
// Requires: plonk_wasm, caml_oracles_of_rust, caml_array_to_rust_vector, caml_pallas_poly_comm_to_rust, caml_pasta_fq_plonk_verifier_index_to_rust, caml_pasta_fq_proof_to_rust
var fq_oracles_create = function (lgr_comm, verifier_index, proof) {
  return caml_oracles_of_rust(
    plonk_wasm.fq_oracles_create(
      caml_array_to_rust_vector(lgr_comm, caml_pallas_poly_comm_to_rust),
      caml_pasta_fq_plonk_verifier_index_to_rust(verifier_index),
      caml_pasta_fq_proof_to_rust(proof)
    )
  );
};

// Provides: fq_oracles_dummy
// Requires: plonk_wasm, caml_oracles_of_rust
var fq_oracles_dummy = function () {
  return caml_oracles_of_rust(plonk_wasm.fq_oracles_dummy());
};

// Provides: fq_oracles_deep_copy
// Requires: plonk_wasm, caml_oracles_of_rust, caml_oracles_to_rust
var fq_oracles_deep_copy = function (x) {
  return caml_oracles_of_rust(
    plonk_wasm.fq_oracles_deep_copy(
      caml_oracles_to_rust(
        x,
        plonk_wasm.WasmFqOracles,
        plonk_wasm.WasmFqRandomOracles
      )
    )
  );
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
  var wasm_flat_vector = plonk_wasm.caml_pasta_fp_poseidon_block_cipher(
    caml_fp_vector_to_rust(fp_vector)
  );
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
  var wasm_flat_vector = plonk_wasm.caml_pasta_fq_poseidon_block_cipher(
    caml_fq_vector_to_rust(fq_vector)
  );
  var new_fq_vector = caml_fq_vector_of_rust(wasm_flat_vector);
  // 2. write back modified field vector to original one
  new_fq_vector.forEach(function (a, i) {
    fq_vector[i] = a;
  });
}

// Provides: prover_to_json
// Requires: plonk_wasm
var prover_to_json = plonk_wasm.prover_to_json;

// Provides: integers_uint64_of_uint32
// Requires: UInt64, caml_int64_of_int32
function integers_uint64_of_uint32(i) {
  // Same as integers_uint64_of_int
  return new UInt64(caml_int64_of_int32(i));
}

/////////////////////////////////////////////////////////////////////////////
// The *_example_* functions below are only used in the pickles unit tests //
/////////////////////////////////////////////////////////////////////////////

// Provides: caml_pasta_fp_plonk_proof_example_with_ffadd
function caml_pasta_fp_plonk_proof_example_with_ffadd() {
  throw new Error('Unimplemented caml_pasta_fp_plonk_proof_example_with_ffadd');
}

// Provides: caml_pasta_fp_plonk_proof_example_with_foreign_field_mul
function caml_pasta_fp_plonk_proof_example_with_foreign_field_mul() {
  throw new Error(
    'Unimplemented caml_pasta_fp_plonk_proof_example_with_foreign_field_mul'
  );
}

// Provides: caml_pasta_fp_plonk_proof_example_with_range_check
function caml_pasta_fp_plonk_proof_example_with_range_check() {
  throw new Error(
    'Unimplemented caml_pasta_fp_plonk_proof_example_with_range_check'
  );
}

// Provides: caml_pasta_fp_plonk_proof_example_with_range_check0
function caml_pasta_fp_plonk_proof_example_with_range_check0() {
  throw new Error(
    'Unimplemented caml_pasta_fp_plonk_proof_example_with_range_check0'
  );
}

// Provides: caml_pasta_fp_plonk_proof_example_with_rot
function caml_pasta_fp_plonk_proof_example_with_rot() {
  throw new Error('Unimplemented caml_pasta_fp_plonk_proof_example_with_rot');
}

// Provides: caml_pasta_fp_plonk_proof_example_with_xor
function caml_pasta_fp_plonk_proof_example_with_xor() {
  throw new Error('Unimplemented caml_pasta_fp_plonk_proof_example_with_xor');
}

// Provides: caml_pasta_fp_plonk_proof_example_with_lookup
function caml_pasta_fp_plonk_proof_example_with_lookup() {
  throw new Error(
    'Unimplemented caml_pasta_fp_plonk_proof_example_with_lookup'
  );
}
