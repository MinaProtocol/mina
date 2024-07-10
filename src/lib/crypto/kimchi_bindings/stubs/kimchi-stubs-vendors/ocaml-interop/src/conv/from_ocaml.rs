// Copyright (c) Viable Systems and TezEdge Contributors
// SPDX-License-Identifier: MIT

use crate::{
    mlvalues::{field_val, OCamlBytes, OCamlFloat, OCamlInt, OCamlInt32, OCamlInt64, OCamlList},
    value::OCaml,
};

/// Implements conversion from OCaml values into Rust values.
pub unsafe trait FromOCaml<T> {
    /// Convert from OCaml value.
    fn from_ocaml(v: OCaml<T>) -> Self;
}

unsafe impl FromOCaml<()> for () {
    fn from_ocaml(_v: OCaml<()>) -> Self {
        // Nothing, just unit
    }
}

unsafe impl FromOCaml<OCamlInt> for i64 {
    fn from_ocaml(v: OCaml<OCamlInt>) -> Self {
        v.to_i64()
    }
}

unsafe impl FromOCaml<OCamlInt> for i32 {
    fn from_ocaml(v: OCaml<OCamlInt>) -> Self {
        v.to_i64() as i32
    }
}

unsafe impl FromOCaml<OCamlInt32> for i32 {
    fn from_ocaml(v: OCaml<OCamlInt32>) -> Self {
        let val = unsafe { field_val(v.raw(), 1) };
        unsafe { *(val as *const i32) }
    }
}

unsafe impl FromOCaml<OCamlInt64> for i64 {
    fn from_ocaml(v: OCaml<OCamlInt64>) -> Self {
        let val = unsafe { field_val(v.raw(), 1) };
        unsafe { *(val as *const i64) }
    }
}

unsafe impl FromOCaml<bool> for bool {
    fn from_ocaml(v: OCaml<bool>) -> Self {
        v.to_bool()
    }
}

unsafe impl FromOCaml<OCamlFloat> for f64 {
    fn from_ocaml(v: OCaml<OCamlFloat>) -> Self {
        unsafe { *(v.raw() as *const f64) }
    }
}

unsafe impl FromOCaml<String> for Vec<u8> {
    fn from_ocaml(v: OCaml<String>) -> Self {
        let raw_bytes = v.as_bytes();
        let mut vec: Vec<u8> = Vec::with_capacity(raw_bytes.len());
        vec.extend_from_slice(raw_bytes);
        vec
    }
}

unsafe impl FromOCaml<String> for String {
    fn from_ocaml(v: OCaml<String>) -> Self {
        String::from_utf8_lossy(v.as_bytes()).into_owned()
    }
}

unsafe impl FromOCaml<OCamlBytes> for Vec<u8> {
    fn from_ocaml(v: OCaml<OCamlBytes>) -> Self {
        let raw_bytes = v.as_bytes();
        let mut vec: Vec<u8> = Vec::with_capacity(raw_bytes.len());
        vec.extend_from_slice(raw_bytes);
        vec
    }
}

unsafe impl FromOCaml<OCamlBytes> for String {
    fn from_ocaml(v: OCaml<OCamlBytes>) -> Self {
        unsafe { v.as_str_unchecked() }.to_owned()
    }
}

unsafe impl<OCamlT, T: FromOCaml<OCamlT>> FromOCaml<OCamlT> for Box<T> {
    fn from_ocaml(v: OCaml<OCamlT>) -> Self {
        Box::new(T::from_ocaml(v))
    }
}

unsafe impl<A, OCamlA, Err, OCamlErr> FromOCaml<Result<OCamlA, OCamlErr>> for Result<A, Err>
where
    A: FromOCaml<OCamlA>,
    Err: FromOCaml<OCamlErr>,
{
    fn from_ocaml(v: OCaml<Result<OCamlA, OCamlErr>>) -> Self {
        match v.to_result() {
            Ok(ocaml_ok) => Ok(A::from_ocaml(ocaml_ok)),
            Err(ocaml_err) => Err(Err::from_ocaml(ocaml_err)),
        }
    }
}

unsafe impl<A, OCamlA> FromOCaml<Option<OCamlA>> for Option<A>
where
    A: FromOCaml<OCamlA>,
{
    fn from_ocaml(v: OCaml<Option<OCamlA>>) -> Self {
        v.to_option().map(A::from_ocaml)
    }
}

unsafe impl<A, OCamlA> FromOCaml<OCamlList<OCamlA>> for Vec<A>
where
    A: FromOCaml<OCamlA>,
{
    fn from_ocaml(v: OCaml<OCamlList<OCamlA>>) -> Self {
        // TODO: pre-calculate actual required capacity?
        let mut vec = Vec::new();
        let mut current = v;
        while let Some((hd, tl)) = current.uncons() {
            current = tl;
            vec.push(A::from_ocaml(hd));
        }
        vec
    }
}

// Tuples

macro_rules! tuple_from_ocaml {
    ($($accessor:ident: $t:ident => $ot:ident),+) => {
        unsafe impl<$($t),+, $($ot: 'static),+> FromOCaml<($($ot),+)> for ($($t),+)
        where
            $($t: FromOCaml<$ot>),+
        {
            fn from_ocaml(v: OCaml<($($ot),+)>) -> Self {
                ($($t::from_ocaml(v.$accessor())),+)

            }
        }
    };
}

tuple_from_ocaml!(
    fst: OCamlA => A,
    snd: OCamlB => B);
tuple_from_ocaml!(
    fst: OCamlA => A,
    snd: OCamlB => B,
    tuple_3: OCamlC => C);
tuple_from_ocaml!(
    fst: OCamlA => A,
    snd: OCamlB => B,
    tuple_3: OCamlC => C,
    tuple_4: OCamlD => D);
tuple_from_ocaml!(
    fst: OCamlA => A,
    snd: OCamlB => B,
    tuple_3: OCamlC => C,
    tuple_4: OCamlD => D,
    tuple_5: OCamlE => E);
tuple_from_ocaml!(
    fst: OCamlA => A,
    snd: OCamlB => B,
    tuple_3: OCamlC => C,
    tuple_4: OCamlD => D,
    tuple_5: OCamlE => E,
    tuple_6: OCamlF => F);
tuple_from_ocaml!(
    fst: OCamlA => A,
    snd: OCamlB => B,
    tuple_3: OCamlC => C,
    tuple_4: OCamlD => D,
    tuple_5: OCamlE => E,
    tuple_6: OCamlF => F,
    tuple_7: OCamlG => G);
tuple_from_ocaml!(
    fst: OCamlA => A,
    snd: OCamlB => B,
    tuple_3: OCamlC => C,
    tuple_4: OCamlD => D,
    tuple_5: OCamlE => E,
    tuple_6: OCamlF => F,
    tuple_7: OCamlG => G,
    tuple_8: OCamlH => H);
tuple_from_ocaml!(
    fst: OCamlA => A,
    snd: OCamlB => B,
    tuple_3: OCamlC => C,
    tuple_4: OCamlD => D,
    tuple_5: OCamlE => E,
    tuple_6: OCamlF => F,
    tuple_7: OCamlG => G,
    tuple_8: OCamlH => H,
    tuple_9: OCamlI => I);
