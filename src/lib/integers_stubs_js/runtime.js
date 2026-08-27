// This code supports both Array and MlInt64 implementations of int64 in
// js_of_ocaml (pre- vs post-887507db1eb8efd779070cbedab3774098a52939).
//
// Compilation is currently broken on the MlInt64 implementation, due to
// removed internal js_of_ocaml primitives. Removing these (and the Array
// implementations, signalled by [instanceof Array] checks) will cause
// compilation to succeed.
//
// TODO: build-time magic to stub the unavailable primitives on later versions.

//Provides: UInt32 const
var UInt32 = (function() {
    var UInt32 = function(x) {
        this.value = x >>> 0;
    };
    UInt32.prototype.caml_custom = "integers:uint32";
    return UInt32;
})();

//Provides: integers_int32_of_uint32
function integers_int32_of_uint32(i) {
    return (i.value | 0);
}

//Provides: integers_size_t_size
function integers_size_t_size(unit) {
    return 4; // Set size_t = u32
}

//Provides: integers_uint16_of_string
//Requires: integers_uint32_of_string
function integers_uint16_of_string(x) {
    var y = integers_uint32_of_string(x);
    return (y.value & 0xFFFF);
}

//Provides: integers_uint32_add
//Requires: UInt32
function integers_uint32_add(x, y) {
    return new UInt32(x.value + y.value);
}

//Provides: integers_uint32_sub
//Requires: UInt32
function integers_uint32_sub(x, y) {
    return new UInt32(x.value - y.value);
}

//Provides: integers_uint32_div
//Requires: UInt32
function integers_uint32_div(x, y) {
    return new UInt32(x.value / y.value);
}

//Provides: integers_uint32_logand
//Requires: UInt32
function integers_uint32_logand(x, y) {
    return new UInt32(x.value & y.value);
}

//Provides: integers_uint32_logor
//Requires: UInt32
function integers_uint32_logor(x, y) {
    return new UInt32(x.value | y.value);
}

//Provides: integers_uint32_logxor
//Requires: UInt32
function integers_uint32_logxor(x, y) {
    return new UInt32(x.value ^ y.value);
}

//Provides: integers_uint32_max
//Requires: UInt32
function integers_uint32_max(unit) {
    return new UInt32(0xFFFFFFFF);
}

//Provides: integers_uint32_mul
//Requires: integers_uint32_to_int64, caml_int64_mul, caml_int64_to_int32, UInt32
function integers_uint32_mul(x, y) {
    // Convert to 64-bit and compute there.
    var x_64 = integers_uint32_to_int64(x);
    var y_64 = integers_uint32_to_int64(y);
    return new UInt32 (caml_int64_to_int32(caml_int64_mul(x_64, y_64)));
}

//Provides: integers_uint32_of_int
//Requires: UInt32
function integers_uint32_of_int(i) {
    return new UInt32(i);
}

//Provides: integers_uint32_of_int32
//Requires: UInt32
function integers_uint32_of_int32(i) {
    return new UInt32(i);
}

//Provides: integers_uint32_of_int64
//Requires: caml_int64_to_int32, UInt32
function integers_uint32_of_int64(i) {
    return new UInt32(caml_int64_to_int32(i));
}

//Provides: integers_uint32_of_string
//Requires: integers_uint_of_string, integers_uint32_of_int64, caml_int64_create_lo_mi_hi
function integers_uint32_of_string(s) {
    // To match the C implementation, we should parse the string as an uint64
    // and then downcast.
    var max_val = caml_int64_create_lo_mi_hi(0xffffff, 0xffffff, 0xffff);
    return integers_uint32_of_int64(integers_uint_of_string(s, max_val));
}

//Provides: integers_uint32_rem
//Requires: caml_raise_zero_divide, UInt32
function integers_uint32_rem(x, y) {
    if (y.value == 0) {
        caml_raise_zero_divide();
    }
    return new UInt32(x.value % y.value);
}

//Provides: integers_uint32_shift_left
//Requires: UInt32
function integers_uint32_shift_left(x, y) {
    return new UInt32(x.value << y);
}

//Provides: integers_uint32_shift_right
//Requires: UInt32
function integers_uint32_shift_right(x, y) {
    return new UInt32(x.value >>> y);
}

//Provides: integers_uint32_to_int
function integers_uint32_to_int(i) {
    return (i.value | 0);
}

//Provides: integers_uint32_to_int64
//Requires: caml_int64_create_lo_mi_hi
function integers_uint32_to_int64(i) {
    return caml_int64_create_lo_mi_hi(i.value & 0xffffff, (i.value >>> 24) & 0xffffff, 0);
}

//Provides: integers_uint32_to_string
//Requires: caml_new_string
function integers_uint32_to_string(i) {
   return caml_new_string(i.value.toString());
}

//Provides: UInt64 const
var UInt64 = (function () {
    var UInt64 = function (x) {
      this.value = x; // x is an MlInt64
    };
    UInt64.prototype.caml_custom = "integers:uint64";
    return UInt64;
})();

//Provides: integers_uint64_add
//Requires: caml_int64_add, UInt64
function integers_uint64_add(x, y) {
    return new UInt64(caml_int64_add(x.value, y.value));
}

//Provides: integers_uint64_div
//Requires: caml_raise_zero_divide, UInt64
function integers_uint64_div(x, y) {
    if (y.value.isZero()) {
        caml_raise_zero_divide();
    }
    // Coerce the high parts to be unsigned before division.
    x.value.hi = x.value.hi >>> 0;
    y.value.hi = y.value.hi >>> 0;
    return new UInt64(x.value.udivmod(y.value).quotient);
}

//Provides: integers_uint64_logand
//Requires: caml_int64_and, UInt64
function integers_uint64_logand(x, y) {
    return new UInt64(caml_int64_and(x.value, y.value));
}

//Provides: integers_uint64_logor
//Requires: caml_int64_or, UInt64
function integers_uint64_logor(x, y) {
    return new UInt64(caml_int64_or(x.value, y.value));
}

//Provides: integers_uint64_logxor
//Requires: caml_int64_xor, UInt64
function integers_uint64_logxor(x, y) {
    return new UInt64(caml_int64_xor(x.value, y.value));
}

//Provides: integers_uint64_max
//Requires: caml_int64_create_lo_mi_hi, UInt64
function integers_uint64_max(unit) {
    var x = caml_int64_create_lo_mi_hi(0xffffff, 0xffffff, 0xffff);
    x.hi = x.hi >>> 0;
    return new UInt64(x);
}

//Provides: integers_uint64_mul
//Requires: caml_int64_mul, UInt64
function integers_uint64_mul(x, y) {
    return new UInt64(caml_int64_mul(x.value, y.value));
}

//Provides: integers_uint64_of_int
//Requires: caml_int64_of_int32, UInt64
function integers_uint64_of_int(i) {
    return new UInt64(caml_int64_of_int32(i));
}

//Provides: integers_uint64_of_int64
//Requires: caml_int64_create_lo_mi_hi, UInt64
function integers_uint64_of_int64(i) {
    return new UInt64(caml_int64_create_lo_mi_hi(i.lo, i.mi, i.hi >>> 0));
}

//Provides: integers_uint_of_string
//Requires: caml_ml_string_length, caml_failwith, caml_string_unsafe_get, caml_int64_create_lo_mi_hi, caml_int64_of_int32, caml_parse_digit, caml_int64_ult, caml_int64_add, caml_int64_mul
function integers_uint_of_string(s, max_val) {
    // Note: This code matches the behavior of the C function (integers >= 0.5).
    // In particular,
    // - an optional leading '+' is accepted
    // - a base prefix selects the radix: 0x/0X -> 16, 0o/0O -> 8, 0b/0B -> 2,
    //   0u/0U -> unsigned marker (no-op), otherwise base 10
    // - '_' digit separators are ignored
    // - the longest valid prefix is accepted; overflow pins to the maximum value
    var i = 0, len = caml_ml_string_length(s), base = 10;
    if (i >= len) {
        caml_failwith("int_of_string");
    }
    // Strip a leading '+' sign, if given.
    if (caml_string_unsafe_get(s, i) === 43) {
        i++;
    }
    // Detect a base prefix on a leading '0'.
    if (i < len && caml_string_unsafe_get(s, i) === 48 /* '0' */ && i + 1 < len) {
        var p = caml_string_unsafe_get(s, i + 1);
        if (p === 120 || p === 88) { base = 16; i += 2; }      // 0x / 0X
        else if (p === 111 || p === 79) { base = 8; i += 2; }  // 0o / 0O
        else if (p === 98 || p === 66) { base = 2; i += 2; }   // 0b / 0B
        else if (p === 117 || p === 85) { i += 2; }            // 0u / 0U (no-op)
    }
    var no_digits = true;
    // Ensure that the high byte is unsigned before division.
    max_val.hi = max_val.hi >>> 0;
    var js_base = caml_int64_of_int32(base);
    var max_prefix = max_val.udivmod(js_base).quotient;
    var res = caml_int64_of_int32(0);
    for (; i < len; i++) {
        var c = caml_string_unsafe_get(s, i);
        if (c === 95) { // '_' digit separator
            continue;
        }
        var d = caml_parse_digit(c);
        if (d < 0 || d >= base) {
            break;
        }
        no_digits = false;
        // Any further digit would overflow. Pin to the maximum value.
        if (caml_int64_ult(max_prefix, res)) {
            return max_val;
        }
        d = caml_int64_of_int32(d);
        res = caml_int64_add(caml_int64_mul(js_base, res), d);
        // The addition overflowed. Pin to the maximum value.
        if (caml_int64_ult(res, d)) {
            return max_val;
        }
    }
    if (no_digits) {
        caml_failwith("int_of_string");
    }
    // Set the high byte as unsigned.
    res.hi = res.hi >>> 0;
    return res;
}

//Provides: integers_uint64_of_string
//Requires: integers_uint_of_string, caml_int64_create_lo_mi_hi, UInt64
function integers_uint64_of_string(s) {
  var max_val = caml_int64_create_lo_mi_hi(0xffffff, 0xffffff, 0xffff);
  return new UInt64(integers_uint_of_string(s, max_val));
}

//Provides: integers_uint64_rem
//Requires: caml_raise_zero_divide, caml_int64_is_zero, UInt64
function integers_uint64_rem(x, y) {
    if (y.value.isZero()) {
        caml_raise_zero_divide();
    }
    // Coerce the high parts to be unsigned before division.
    x.value.hi = x.value.hi >>> 0;
    y.value.hi = y.value.hi >>> 0;
    return new UInt64(x.value.udivmod(y.value).modulus);
}

//Provides: integers_uint64_shift_left
//Requires: caml_int64_shift_left, UInt64
function integers_uint64_shift_left(x, y) {
    return new UInt64(caml_int64_shift_left(x.value, y));
}

//Provides: integers_uint64_shift_right
//Requires: caml_int64_shift_right_unsigned, UInt64
function integers_uint64_shift_right(x, y) {
    return new UInt64(caml_int64_shift_right_unsigned(x.value, y));
}

//Provides: integers_uint64_sub
//Requires: caml_int64_sub, UInt64
function integers_uint64_sub(x, y) {
    return new UInt64(caml_int64_sub(x.value, y.value));
}

//Provides: integers_uint64_to_int
//Requires: caml_int64_to_int32
function integers_uint64_to_int(i) {
    return caml_int64_to_int32(i.value);
}

//Provides: integers_uint64_to_int64
//Requires: caml_int64_create_lo_mi_hi
function integers_uint64_to_int64(i) {
    i = i.value;
    return caml_int64_create_lo_mi_hi(i.lo, i.mi, i.hi | 0);
}

//Provides: integers_uint64_to_string
//Requires: caml_int64_format, caml_new_string
function integers_uint64_to_string(i) {
    return caml_int64_format(caml_new_string("%u"), i.value);
}

//Provides: integers_uint64_unmarshal
//Requires: caml_int64_unmarshal, UInt64
function integers_uint64_unmarshal(reader, size){
    return new UInt64(caml_int64_unmarshal(reader, size));
}
  
//Provides: integers_uint64_marshal
//Requires: caml_int64_marshal
function integers_uint64_marshal(writer, v, sizes) {
    caml_int64_marshal(writer, v.value, sizes);
}

//Provides: integers_uint64_hash
//Requires: caml_int64_hash
function integers_uint64_hash(v) {
    return caml_int64_hash(v.value);
}

//Provides: integers_uint8_of_string
//Requires: integers_uint32_of_string
function integers_uint8_of_string(x) {
    var y = integers_uint32_of_string(x);
    return (x.value & 0xFF);
}

//Provides: integers_uint_size
function integers_uint_size(unit) {
    return 4;
}

//Provides: integers_ulong_size
function integers_ulong_size(unit) {
    return 4;
}

//Provides: integers_ulonglong_size
function integers_ulonglong_size(unit) {
    return 8;
}

//Provides: integers_unsigned_init
//Requires: caml_custom_ops, integers_uint8_deserialize, integers_uint16_deserialize, integers_uint32_serialize, integers_uint32_deserialize, integers_uint32_hash, integers_uint32_compare, integers_uint64_compare, integers_uint64_hash, integers_uint64_marshal, integers_uint64_unmarshal
function integers_unsigned_init(unit) {
    caml_custom_ops["integers:uint8"] =
    { deserialize: integers_uint8_deserialize
    , fixed_length: 1 };
    caml_custom_ops["integers:uint16"] =
    { deserialize: integers_uint16_deserialize
    , fixed_length: 2 };
    caml_custom_ops["integers:uint32"] =
    { serialize: integers_uint32_serialize
    , deserialize: integers_uint32_deserialize
    , fixed_length: 4
    , hash: integers_uint32_hash
    , compare: integers_uint32_compare };
    caml_custom_ops["integers:uint64"] =
    { serialize: integers_uint64_marshal
    , deserialize: integers_uint64_unmarshal
    , hash: integers_uint64_hash
    , compare: integers_uint64_compare };
    return unit;
}

//Provides: integers_ushort_size
function integers_ushort_size(unit) {
    return 4;
}

//Provides: integers_uint32_serialize
function integers_uint32_serialize(writer, v, size) {
    writer.write(32, v.value);
    size[0] = 4;
    size[1] = 4;
}

//Provides: integers_uint8_deserialize
function integers_uint8_deserialize(reader, size) {
    size[0] = 1;
    return reader.read8u();
}

//Provides: integers_uint16_deserialize
function integers_uint16_deserialize(reader, size) {
    size[0] = 2;
    return reader.read16u();
}

//Provides: integers_uint32_deserialize
//Requires: UInt32
function integers_uint32_deserialize(reader, size) {
    size[0] = 4;
    return new UInt32(reader.read32u());
}

//Provides: integers_uint32_hash
function integers_uint32_hash(v) {
    return v.value;
}

//Provides: integers_uint32_compare
function integers_uint32_compare(x, y) {
    if (x.value > y.value) { return 1; }
    if (x.value < y.value) { return -1; }
    return 0;
}

//Provides: integers_uint64_compare
//Requires: caml_int64_compare
function integers_uint64_compare(x, y) {
    x.value.hi = x.value.hi >>> 0;
    y.value.hi = y.value.hi >>> 0;
    return x.value.ucompare(y.value);
}
