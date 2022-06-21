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