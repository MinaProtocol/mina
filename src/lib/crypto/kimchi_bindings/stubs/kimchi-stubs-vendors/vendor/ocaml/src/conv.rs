use std::convert::TryInto;

use crate::{
    sys,
    value::{FromValue, IntoValue, Value},
    Raw, Runtime, Tag,
};

macro_rules! value_i {
    ($t:ty) => {
        unsafe impl IntoValue for $t {
            fn into_value(self, _rt: &Runtime) -> $crate::Value {
                unsafe { $crate::Value::int(self as crate::Int) }
            }
        }

        unsafe impl<'a> FromValue<'a> for $t {
            fn from_value(v: $crate::Value) -> $t {
                unsafe { v.int_val() as $t }
            }
        }
    };
    ($($t:ty),*) => {
        $(value_i!($t);)*
    }
}

macro_rules! value_f {
    ($t:ty) => {
        unsafe impl IntoValue for $t {
            fn into_value(self, _rt: &Runtime) -> $crate::Value {
                unsafe { $crate::Value::float(self as crate::Float) }
            }
        }

        unsafe impl<'a> FromValue<'a> for $t {
            fn from_value(v: $crate::Value) -> $t {
                unsafe { v.float_val() as $t }
            }
        }
    };
    ($($t:ty),*) => {
        $(value_f!($t);)*
    }
}

value_i!(i8, u8, i16, u16, crate::Int, crate::Uint);
value_f!(f32, f64);

unsafe impl IntoValue for i64 {
    fn into_value(self, _rt: &Runtime) -> crate::Value {
        unsafe { Value::int64(self) }
    }
}

unsafe impl<'a> FromValue<'a> for i64 {
    fn from_value(v: Value) -> i64 {
        unsafe { v.int64_val() }
    }
}

unsafe impl IntoValue for u64 {
    fn into_value(self, _rt: &Runtime) -> crate::Value {
        unsafe { Value::int64(self as i64) }
    }
}

unsafe impl<'a> FromValue<'a> for u64 {
    fn from_value(v: Value) -> u64 {
        unsafe { v.int64_val() as u64 }
    }
}

unsafe impl IntoValue for i32 {
    fn into_value(self, _rt: &Runtime) -> crate::Value {
        unsafe { Value::int32(self) }
    }
}

unsafe impl<'a> FromValue<'a> for i32 {
    fn from_value(v: Value) -> i32 {
        unsafe { v.int32_val() }
    }
}

struct Incr(usize);

impl Incr {
    fn get(&mut self) -> usize {
        let i = self.0;
        self.0 = i + 1;
        i
    }
}

macro_rules! tuple_impl {
    ($($t:ident: $n:tt),*) => {
        unsafe impl<'a, $($t: FromValue<'a>),*> FromValue<'a> for ($($t,)*) {
            fn from_value(v: Value) -> ($($t,)*) {
                let mut i = Incr(0);
                #[allow(unused)]
                (
                    $(
                        $t::from_value(unsafe { v.field(i.get()) }),
                    )*
                )
            }
        }

        unsafe impl<$($t: IntoValue),*> IntoValue for ($($t,)*) {
            fn into_value(self, rt: &Runtime) -> crate::Value {
                #[allow(unused)]
                let mut len = 0;
                $(
                    #[allow(unused)]
                    {
                        len = $n + 1;
                    }
                )*

                unsafe {
                    let mut v = $crate::Value::alloc(len, Tag(0));
                    $(
                        v.store_field(rt, $n, self.$n);
                    )*

                    v
                }
            }
        }
    };
}

tuple_impl!(A: 0);
tuple_impl!(A: 0, B: 1);
tuple_impl!(A: 0, B: 1, C: 2);
tuple_impl!(A: 0, B: 1, C: 2, D: 3);
tuple_impl!(A: 0, B: 1, C: 2, D: 3, E: 4);
tuple_impl!(A: 0, B: 1, C: 2, D: 3, E: 4, F: 5);
tuple_impl!(A: 0, B: 1, C: 2, D: 3, E: 4, F: 5, G: 6);
tuple_impl!(A: 0, B: 1, C: 2, D: 3, E: 4, F: 5, G: 6, H: 7);
tuple_impl!(A: 0, B: 1, C: 2, D: 3, E: 4, F: 5, G: 6, H: 7, I: 8);
tuple_impl!(A: 0, B: 1, C: 2, D: 3, E: 4, F: 5, G: 6, H: 7, I: 8, J: 9);
tuple_impl!(A: 0, B: 1, C: 2, D: 3, E: 4, F: 5, G: 6, H: 7, I: 8, J: 9, K: 10);
tuple_impl!(A: 0, B: 1, C: 2, D: 3, E: 4, F: 5, G: 6, H: 7, I: 8, J: 9, K: 10, L: 11);
tuple_impl!(A: 0, B: 1, C: 2, D: 3, E: 4, F: 5, G: 6, H: 7, I: 8, J: 9, K: 10, L: 11, M: 12);
tuple_impl!(A: 0, B: 1, C: 2, D: 3, E: 4, F: 5, G: 6, H: 7, I: 8, J: 9, K: 10, L: 11, M: 12, N: 13);
tuple_impl!(A: 0, B: 1, C: 2, D: 3, E: 4, F: 5, G: 6, H: 7, I: 8, J: 9, K: 10, L: 11, M: 12, N: 13, O: 14);
tuple_impl!(A: 0, B: 1, C: 2, D: 3, E: 4, F: 5, G: 6, H: 7, I: 8, J: 9, K: 10, L: 11, M: 12, N: 13, O: 14, P: 15);
tuple_impl!(A: 0, B: 1, C: 2, D: 3, E: 4, F: 5, G: 6, H: 7, I: 8, J: 9, K: 10, L: 11, M: 12, N: 13, O: 14, P: 15, Q: 16);
tuple_impl!(A: 0, B: 1, C: 2, D: 3, E: 4, F: 5, G: 6, H: 7, I: 8, J: 9, K: 10, L: 11, M: 12, N: 13, O: 14, P: 15, Q: 16, R: 17);
tuple_impl!(A: 0, B: 1, C: 2, D: 3, E: 4, F: 5, G: 6, H: 7, I: 8, J: 9, K: 10, L: 11, M: 12, N: 13, O: 14, P: 15, Q: 16, R: 17, S: 18);
tuple_impl!(A: 0, B: 1, C: 2, D: 3, E: 4, F: 5, G: 6, H: 7, I: 8, J: 9, K: 10, L: 11, M: 12, N: 13, O: 14, P: 15, Q: 16, R: 17, S: 18, T: 19);
tuple_impl!(A: 0, B: 1, C: 2, D: 3, E: 4, F: 5, G: 6, H: 7, I: 8, J: 9, K: 10, L: 11, M: 12, N: 13, O: 14, P: 15, Q: 16, R: 17, S: 18, T: 19, U: 20);

unsafe impl IntoValue for bool {
    fn into_value(self, _rt: &Runtime) -> Value {
        unsafe { Value::int(self as isize) }
    }
}

unsafe impl<'a> FromValue<'a> for bool {
    fn from_value(v: Value) -> bool {
        unsafe { v.int_val() != 0 }
    }
}

#[cfg(not(feature = "no-std"))]
unsafe impl IntoValue for String {
    fn into_value(self, _rt: &Runtime) -> Value {
        unsafe { Value::string(self.as_str()) }
    }
}

#[cfg(not(feature = "no-std"))]
unsafe impl<'a> FromValue<'a> for String {
    fn from_value(value: Value) -> String {
        unsafe { value.string_val().into() }
    }
}

unsafe impl IntoValue for () {
    fn into_value(self, _rt: &Runtime) -> Value {
        Value::unit()
    }
}

unsafe impl<'a, T: FromValue<'a>> FromValue<'a> for Option<T> {
    fn from_value(value: Value) -> Option<T> {
        if value.raw().0 == sys::NONE {
            return None;
        }

        unsafe { Some(T::from_value(value.field(0))) }
    }
}

unsafe impl<'a, T: IntoValue> IntoValue for Option<T> {
    fn into_value(self, rt: &Runtime) -> Value {
        match self {
            Some(y) => unsafe { Value::some(rt, y) },
            None => Value::none(),
        }
    }
}

unsafe impl<'a> FromValue<'a> for &'a str {
    fn from_value(value: Value) -> &'a str {
        unsafe {
            let len = sys::caml_string_length(value.raw().0);
            let ptr = sys::string_val(value.raw().0);
            let slice = ::core::slice::from_raw_parts(ptr, len);
            ::core::str::from_utf8(slice).expect("Invalid UTF-8")
        }
    }
}

unsafe impl<'a> IntoValue for &str {
    fn into_value(self, _rt: &Runtime) -> Value {
        unsafe { Value::string(self) }
    }
}

unsafe impl<'a> FromValue<'a> for &'a mut str {
    fn from_value(value: Value) -> &'a mut str {
        unsafe {
            let len = sys::caml_string_length(value.raw().0);
            let ptr = sys::string_val(value.raw().0);
            let slice = ::core::slice::from_raw_parts_mut(ptr, len);
            ::core::str::from_utf8_mut(slice).expect("Invalid UTF-8")
        }
    }
}

unsafe impl<'a> IntoValue for &mut str {
    fn into_value(self, _rt: &Runtime) -> Value {
        unsafe { Value::string(self) }
    }
}

unsafe impl<'a> FromValue<'a> for &'a [u8] {
    fn from_value(value: Value) -> &'a [u8] {
        unsafe {
            let len = sys::caml_string_length(value.raw().0);
            let ptr = sys::string_val(value.raw().0);
            ::core::slice::from_raw_parts(ptr, len)
        }
    }
}

unsafe impl<'a> IntoValue for &[u8] {
    fn into_value(self, _rt: &Runtime) -> Value {
        unsafe { Value::bytes(self) }
    }
}

unsafe impl<'a> FromValue<'a> for &'a mut [u8] {
    fn from_value(value: Value) -> &'a mut [u8] {
        unsafe {
            let len = sys::caml_string_length(value.raw().0);
            let ptr = sys::string_val(value.raw().0);
            ::core::slice::from_raw_parts_mut(ptr, len)
        }
    }
}

unsafe impl<'a> IntoValue for &mut [u8] {
    fn into_value(self, _rt: &Runtime) -> Value {
        unsafe { Value::bytes(self) }
    }
}

macro_rules! array_impl {
    ($n:tt) => {
        unsafe impl FromValue<'static> for [u8; $n] {
            fn from_value(value: Value) -> Self {
                unsafe {
                    let len = sys::caml_string_length(value.raw().0);
                    assert!(len == $n);
                    let ptr = sys::string_val(value.raw().0);
                    ::core::slice::from_raw_parts(ptr, len).try_into().unwrap()
                }
            }
        }

        unsafe impl IntoValue for [u8; $n] {
            fn into_value(self, _rt: &Runtime) -> Value {
                unsafe { Value::bytes(self) }
            }
        }
    };
}

array_impl!(1);
array_impl!(2);
array_impl!(3);
array_impl!(4);
array_impl!(5);
array_impl!(6);
array_impl!(7);
array_impl!(8);
array_impl!(9);
array_impl!(10);
array_impl!(11);
array_impl!(12);
array_impl!(13);
array_impl!(14);
array_impl!(15);
array_impl!(16);
array_impl!(17);
array_impl!(18);
array_impl!(19);
array_impl!(20);
array_impl!(21);
array_impl!(22);
array_impl!(23);
array_impl!(24);
array_impl!(25);
array_impl!(26);
array_impl!(27);
array_impl!(28);
array_impl!(29);
array_impl!(30);
array_impl!(31);
array_impl!(32);

#[cfg(not(feature = "no-std"))]
unsafe impl<'a, V: IntoValue> IntoValue for Vec<V> {
    fn into_value(self, rt: &Runtime) -> Value {
        let len = self.len();
        let mut arr = unsafe { Value::alloc(len, Tag(0)) };

        for (i, v) in self.into_iter().enumerate() {
            unsafe {
                arr.store_field(rt, i, v);
            }
        }

        arr
    }
}

#[cfg(not(feature = "no-std"))]
unsafe impl<'a, V: FromValue<'a>> FromValue<'a> for Vec<V> {
    fn from_value(v: Value) -> Vec<V> {
        unsafe {
            let len = crate::sys::caml_array_length(v.raw().0);
            let mut dst = Vec::with_capacity(len);
            for i in 0..len {
                dst.push(V::from_value(Value::new(*crate::sys::field(v.raw().0, i))))
            }
            dst
        }
    }
}

unsafe impl<'a> FromValue<'a> for &'a [Raw] {
    fn from_value(value: Value) -> &'a [Raw] {
        unsafe {
            ::core::slice::from_raw_parts(
                crate::sys::field(value.raw().0, 0) as *mut Raw,
                crate::sys::wosize_val(value.raw().0),
            )
        }
    }
}

unsafe impl<'a> FromValue<'a> for &'a mut [Raw] {
    fn from_value(value: Value) -> &'a mut [Raw] {
        unsafe {
            ::core::slice::from_raw_parts_mut(
                crate::sys::field(value.raw().0, 0) as *mut Raw,
                crate::sys::wosize_val(value.raw().0),
            )
        }
    }
}

#[cfg(not(feature = "no-std"))]
unsafe impl<'a, K: Ord + FromValue<'a>, V: FromValue<'a>> FromValue<'a>
    for std::collections::BTreeMap<K, V>
{
    fn from_value(v: Value) -> std::collections::BTreeMap<K, V> {
        let mut dest = std::collections::BTreeMap::new();
        unsafe {
            let mut tmp = v;
            while tmp.raw().0 != crate::sys::EMPTY_LIST {
                let (k, v) = FromValue::from_value(tmp.field(0));
                dest.insert(k, v);
                tmp = tmp.field(1);
            }
        }

        dest
    }
}

#[cfg(not(feature = "no-std"))]
unsafe impl<K: IntoValue, V: IntoValue> IntoValue for std::collections::BTreeMap<K, V> {
    fn into_value(self, rt: &Runtime) -> Value {
        let mut list = crate::List::empty();

        for (k, v) in self.into_iter().rev() {
            let k_ = k.into_value(rt);
            let v_ = v.into_value(rt);
            list = unsafe { list.add(rt, (k_, v_)) };
        }

        list.into_value(rt)
    }
}

#[cfg(not(feature = "no-std"))]
unsafe impl<'a, T: FromValue<'a>> FromValue<'a> for std::collections::LinkedList<T> {
    fn from_value(v: Value) -> std::collections::LinkedList<T> {
        let mut dest: std::collections::LinkedList<T> = std::collections::LinkedList::new();

        unsafe {
            let mut tmp = v;
            while tmp.raw().0 != crate::sys::EMPTY_LIST {
                let t = T::from_value(tmp.field(0));
                dest.push_back(t);
                tmp = tmp.field(1);
            }
        }

        dest
    }
}

#[cfg(not(feature = "no-std"))]
unsafe impl<T: IntoValue> IntoValue for std::collections::LinkedList<T> {
    fn into_value(self, rt: &Runtime) -> Value {
        let mut list = crate::List::empty();

        for v in self.into_iter().rev() {
            let v_ = v.into_value(rt);
            list = unsafe { list.add(rt, v_) };
        }

        list.into_value(rt)
    }
}

unsafe impl<'a> IntoValue for &Value {
    fn into_value(self, _rt: &Runtime) -> Value {
        unsafe { Value::new(self.raw()) }
    }
}
