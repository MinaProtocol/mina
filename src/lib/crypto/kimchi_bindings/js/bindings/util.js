/* global UInt64, caml_int64_of_int32, caml_create_bytes,
    caml_bytes_unsafe_set, caml_bytes_unsafe_get, caml_ml_bytes_length,
    kimchi_ffi, getTsBindings
 */

// Provides: tsBindings
var tsBindings = globalThis.__snarkyTsBindings;

// Provides: kimchi_backend
// Requires: kimchi_ffi
var kimchi_backend = kimchi_ffi ? kimchi_ffi.__kimchi_backend : 'wasm'; // default to wasm

// Provides: kimchi_is_wasm
// Requires: kimchi_backend
var kimchi_is_wasm = kimchi_backend === 'wasm';

// Provides: kimchi_is_native
// Requires: kimchi_backend
var kimchi_is_native = kimchi_backend === 'native';

// Internal timing helper: 
// Intentionally not exposed as a JSOO primitive. Use only for debugging
var _report_kimchi_timing = function (label, fn) {
  var now =
    globalThis.performance && globalThis.performance.now
      ? function () {
        return globalThis.performance.now();
      }
      : Date.now;
  var t0 = now();
  try {
    return fn();
  } finally {
    var dt = now() - t0;
    if (globalThis.console && globalThis.console.log) {
      globalThis.console.log('[kimchi timing] ' + label + ': ' + dt.toFixed(3) + 'ms');
    }
  }
};

// Provides: tsRustConversion
// Requires: tsBindings, kimchi_ffi
var tsRustConversion = tsBindings.rustConversion(kimchi_ffi);

// Provides: getTsBindings
// Requires: tsBindings
function getTsBindings() {
  return tsBindings;
}

// Provides: integers_uint64_of_uint32
// Requires: UInt64, caml_int64_of_int32
function integers_uint64_of_uint32(i) {
  // Same as integers_uint64_of_int
  return new UInt64(caml_int64_of_int32(i));
}

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
  var bytes = new globalThis.Uint8Array(length);
  for (var i = 0; i < length; i++) {
    // No need to convert here: OCaml Char.t is just an int under the hood.
    bytes[i] = caml_bytes_unsafe_get(ocaml_bytes, i);
  }
  return bytes;
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

// Provides: free_finalization_registry
var free_finalization_registry = new globalThis.FinalizationRegistry(function (
  instance_representative
) {
  instance_representative.free();
});

// Provides: free_on_finalize
// Requires: free_finalization_registry, kimchi_is_native
var free_on_finalize = function (x) {
  // No-op for native backend
  if (kimchi_is_native) {
    return x;
  }
  // wasm-bindgen wrappers already carry their own finalization logic.
  // Registering an extra free path for them can cause double-free / borrow
  // errors (and eventually memory corruption).
  if (x && typeof x.__destroy_into_raw === 'function') {
    return x;
  }
  // We want `x` to be garbage-collected naturally, but still release its Rust
  // allocation when that happens.
  //
  // FinalizationRegistry cannot hold `x` itself as the representative value,
  // because that would keep `x` alive. Instead we create a tiny stand-in that
  // only carries the prototype + raw pointer, which is enough to call `.free()`
  // once `x` is collected.
  //
  // We intentionally avoid `__wrap()` here, because that constructor path is
  // for normal wasm-bindgen object creation and can interact with ownership
  // bookkeeping we do not want in this finalizer surrogate.
  var instance_representative = Object.create(x.constructor.prototype);
  instance_representative.__wbg_ptr = x.__wbg_ptr;
  free_finalization_registry.register(x, instance_representative, x);
  return x;
};
