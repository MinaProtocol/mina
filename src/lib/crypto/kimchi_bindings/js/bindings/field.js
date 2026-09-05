/* global tsBindings
*/

// Provides: caml_pasta_fp_copy
// Requires: tsBindings
var caml_pasta_fp_copy = tsBindings.caml_pasta_fp_copy;

// Provides: caml_pasta_fp_size_in_bits
// Requires: tsBindings
var caml_pasta_fp_size_in_bits = tsBindings.caml_pasta_fp_size_in_bits;

// Provides: caml_pasta_fp_size
// Requires: tsBindings
var caml_pasta_fp_size = tsBindings.caml_pasta_fp_size;

// Provides: caml_pasta_fp_add
// Requires: tsBindings
var caml_pasta_fp_add = tsBindings.caml_pasta_fp_add;

// Provides: caml_pasta_fp_sub
// Requires: tsBindings
var caml_pasta_fp_sub = tsBindings.caml_pasta_fp_sub;

// Provides: caml_pasta_fp_negate
// Requires: tsBindings
var caml_pasta_fp_negate = tsBindings.caml_pasta_fp_negate;

// Provides: caml_pasta_fp_mul
// Requires: tsBindings
var caml_pasta_fp_mul = tsBindings.caml_pasta_fp_mul;

// Provides: caml_pasta_fp_div
// Requires: tsBindings
var caml_pasta_fp_div = tsBindings.caml_pasta_fp_div;

// Provides: caml_pasta_fp_inv
// Requires: tsBindings
var caml_pasta_fp_inv = tsBindings.caml_pasta_fp_inv;

// Provides: caml_pasta_fp_square
// Requires: tsBindings
var caml_pasta_fp_square = tsBindings.caml_pasta_fp_square

// Provides: caml_pasta_fp_is_square
// Requires: tsBindings
var caml_pasta_fp_is_square = tsBindings.caml_pasta_fp_is_square;

// Provides: caml_pasta_fp_sqrt
// Requires: tsBindings
var caml_pasta_fp_sqrt = tsBindings.caml_pasta_fp_sqrt;

// Provides: caml_pasta_fp_of_int
// Requires: tsBindings
var caml_pasta_fp_of_int = tsBindings.caml_pasta_fp_of_int

// Provides: caml_pasta_fp_to_string
// Requires: tsBindings
var caml_pasta_fp_to_string = tsBindings.caml_pasta_fp_to_string;

// Provides: caml_pasta_fp_of_string
// Requires: tsBindings
var caml_pasta_fp_of_string = tsBindings.caml_pasta_fp_of_string;

// Provides: caml_pasta_fp_print
// Requires: tsBindings
var caml_pasta_fp_print = tsBindings.caml_pasta_fp_print;

// Provides: caml_pasta_fp_mut_add
// Requires: tsBindings
var caml_pasta_fp_mut_add = tsBindings.caml_pasta_fp_mut_add;

// Provides: caml_pasta_fp_mut_sub
// Requires: tsBindings
var caml_pasta_fp_mut_sub = tsBindings.caml_pasta_fp_mut_sub;

// Provides: caml_pasta_fp_mut_mul
// Requires: tsBindings
var caml_pasta_fp_mut_mul = tsBindings.caml_pasta_fp_mut_mul;

// Provides: caml_pasta_fp_mut_square
// Requires: tsBindings
var caml_pasta_fp_mut_square = tsBindings.caml_pasta_fp_mut_square;

// Provides: caml_pasta_fp_compare
// Requires: tsBindings
var caml_pasta_fp_compare = tsBindings.caml_pasta_fp_compare;

// Provides: caml_pasta_fp_equal
// Requires: tsBindings
var caml_pasta_fp_equal = tsBindings.caml_pasta_fp_equal;

// Provides: caml_pasta_fp_random
// Requires: tsBindings
var caml_pasta_fp_random = tsBindings.caml_pasta_fp_random;

// Provides: caml_pasta_fp_rng
// Requires: tsBindings
var caml_pasta_fp_rng = tsBindings.caml_pasta_fp_rng;

// Provides: caml_pasta_fp_to_bigint
// Requires: tsBindings
var caml_pasta_fp_to_bigint = tsBindings.caml_pasta_fp_to_bigint;

// Provides: caml_pasta_fp_of_bigint
// Requires: tsBindings
var caml_pasta_fp_of_bigint = tsBindings.caml_pasta_fp_of_bigint;

// Provides: caml_pasta_fp_two_adic_root_of_unity
// Requires: tsBindings
var caml_pasta_fp_two_adic_root_of_unity = tsBindings.caml_pasta_fp_two_adic_root_of_unity;

// Provides: caml_pasta_fp_domain_generator
// Requires: tsBindings
var caml_pasta_fp_domain_generator = tsBindings.caml_pasta_fp_domain_generator;

// Provides: caml_pasta_fp_to_bytes
// Requires: tsBindings
var caml_pasta_fp_to_bytes = tsBindings.caml_pasta_fp_to_bytes;

// Provides: caml_pasta_fp_of_bytes
// Requires: tsBindings
var caml_pasta_fp_of_bytes = tsBindings.caml_pasta_fp_of_bytes;

// Provides: caml_pasta_fp_to_bytes_into
// Requires: tsBindings, caml_ba_set_1, caml_bytes_unsafe_get
function caml_pasta_fp_to_bytes_into(x, buf, pos) {
  var bytes = tsBindings.caml_pasta_fp_to_bytes(x);
  for (var i = 0; i < 32; i++) {
    caml_ba_set_1(buf, pos + i, caml_bytes_unsafe_get(bytes, i));
  }
  return 0;
}

// Provides: caml_pasta_fp_of_bytes_from
// Requires: tsBindings, caml_ba_get_1, caml_create_bytes, caml_bytes_unsafe_set
function caml_pasta_fp_of_bytes_from(buf, pos) {
  var bytes = caml_create_bytes(32);
  for (var i = 0; i < 32; i++) {
    caml_bytes_unsafe_set(bytes, i, caml_ba_get_1(buf, pos + i));
  }
  return tsBindings.caml_pasta_fp_of_bytes(bytes);
}

// Provides: caml_pasta_fp_deep_copy
// Requires: tsBindings
var caml_pasta_fp_deep_copy = tsBindings.caml_pasta_fp_deep_copy;




// Provides: caml_pasta_fq_copy
// Requires: tsBindings
var caml_pasta_fq_copy = tsBindings.caml_pasta_fq_copy;

// Provides: caml_pasta_fq_size_in_bits
// Requires: tsBindings
var caml_pasta_fq_size_in_bits = tsBindings.caml_pasta_fq_size_in_bits;

// Provides: caml_pasta_fq_size
// Requires: tsBindings
var caml_pasta_fq_size = tsBindings.caml_pasta_fq_size;

// Provides: caml_pasta_fq_add
// Requires: tsBindings
var caml_pasta_fq_add = tsBindings.caml_pasta_fq_add;

// Provides: caml_pasta_fq_sub
// Requires: tsBindings
var caml_pasta_fq_sub = tsBindings.caml_pasta_fq_sub;

// Provides: caml_pasta_fq_negate
// Requires: tsBindings
var caml_pasta_fq_negate = tsBindings.caml_pasta_fq_negate;

// Provides: caml_pasta_fq_mul
// Requires: tsBindings
var caml_pasta_fq_mul = tsBindings.caml_pasta_fq_mul;

// Provides: caml_pasta_fq_div
// Requires: tsBindings
var caml_pasta_fq_div = tsBindings.caml_pasta_fq_div;

// Provides: caml_pasta_fq_inv
// Requires: tsBindings
var caml_pasta_fq_inv = tsBindings.caml_pasta_fq_inv; 

// Provides: caml_pasta_fq_square
// Requires: tsBindings
var caml_pasta_fq_square = tsBindings.caml_pasta_fq_square

// Provides: caml_pasta_fq_is_square
// Requires: tsBindings
var caml_pasta_fq_is_square = tsBindings.caml_pasta_fq_is_square;

// Provides: caml_pasta_fq_sqrt
// Requires: tsBindings
var caml_pasta_fq_sqrt = tsBindings.caml_pasta_fq_sqrt;

// Provides: caml_pasta_fq_of_int
// Requires: tsBindings
var caml_pasta_fq_of_int = tsBindings.caml_pasta_fq_of_int;

// Provides: caml_pasta_fq_to_string
// Requires: tsBindings
var caml_pasta_fq_to_string = tsBindings.caml_pasta_fq_to_string;

// Provides: caml_pasta_fq_of_string
// Requires: tsBindings
var caml_pasta_fq_of_string = tsBindings.caml_pasta_fq_of_string;

// Provides: caml_pasta_fq_print
// Requires: tsBindings
var caml_pasta_fq_print = tsBindings.caml_pasta_fq_print;

// Provides: caml_pasta_fq_mut_add
// Requires: tsBindings
var caml_pasta_fq_mut_add = tsBindings.caml_pasta_fq_mut_add;

// Provides: caml_pasta_fq_mut_sub
// Requires: tsBindings
var caml_pasta_fq_mut_sub = tsBindings.caml_pasta_fq_mut_sub;

// Provides: caml_pasta_fq_mut_mul
// Requires: tsBindings
var caml_pasta_fq_mut_mul = tsBindings.caml_pasta_fq_mut_mul;

// Provides: caml_pasta_fq_mut_square
// Requires: tsBindings
var caml_pasta_fq_mut_square = tsBindings.caml_pasta_fq_mut_square;

// Provides: caml_pasta_fq_compare
// Requires: tsBindings
var caml_pasta_fq_compare = tsBindings.caml_pasta_fq_compare;

// Provides: caml_pasta_fq_equal
// Requires: tsBindings
var caml_pasta_fq_equal = tsBindings.caml_pasta_fq_equal;

// Provides: caml_pasta_fq_random
// Requires: tsBindings
var caml_pasta_fq_random = tsBindings.caml_pasta_fq_random;

// Provides: caml_pasta_fq_rng
// Requires: tsBindings
var caml_pasta_fq_rng = tsBindings.caml_pasta_fq_rng;

// Provides: caml_pasta_fq_to_bigint
// Requires: tsBindings
var caml_pasta_fq_to_bigint = tsBindings.caml_pasta_fq_to_bigint;

// Provides: caml_pasta_fq_of_bigint
// Requires: tsBindings
var caml_pasta_fq_of_bigint = tsBindings.caml_pasta_fq_of_bigint;

// Provides: caml_pasta_fq_two_adic_root_of_unity
// Requires: tsBindings
var caml_pasta_fq_two_adic_root_of_unity = tsBindings.caml_pasta_fq_two_adic_root_of_unity;

// Provides: caml_pasta_fq_domain_generator
// Requires: tsBindings
var caml_pasta_fq_domain_generator = tsBindings.caml_pasta_fq_domain_generator;

// Provides: caml_pasta_fq_to_bytes
// Requires: tsBindings
var caml_pasta_fq_to_bytes = tsBindings.caml_pasta_fq_to_bytes;

// Provides: caml_pasta_fq_of_bytes
// Requires: tsBindings
var caml_pasta_fq_of_bytes = tsBindings.caml_pasta_fq_of_bytes;

// Provides: caml_pasta_fq_to_bytes_into
// Requires: tsBindings, caml_ba_set_1, caml_bytes_unsafe_get
function caml_pasta_fq_to_bytes_into(x, buf, pos) {
  var bytes = tsBindings.caml_pasta_fq_to_bytes(x);
  for (var i = 0; i < 32; i++) {
    caml_ba_set_1(buf, pos + i, caml_bytes_unsafe_get(bytes, i));
  }
  return 0;
}

// Provides: caml_pasta_fq_of_bytes_from
// Requires: tsBindings, caml_ba_get_1, caml_create_bytes, caml_bytes_unsafe_set
function caml_pasta_fq_of_bytes_from(buf, pos) {
  var bytes = caml_create_bytes(32);
  for (var i = 0; i < 32; i++) {
    caml_bytes_unsafe_set(bytes, i, caml_ba_get_1(buf, pos + i));
  }
  return tsBindings.caml_pasta_fq_of_bytes(bytes);
}

// Provides: caml_pasta_fq_deep_copy
// Requires: tsBindings
var caml_pasta_fq_deep_copy = tsBindings.caml_pasta_fq_deep_copy;
