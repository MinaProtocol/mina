pub fn to_array_<T, F: Fn(T) -> ocaml::Value>(v: Vec<T>, f: F) -> ocaml::Array<ocaml::Value> {
    let len = v.len();
    // Manually allocate an OCaml array of the right size
    let mut array = ocaml::Array::alloc(len);
    for (i, x) in v.into_iter().enumerate() {
        unsafe {
            array.set_unchecked(i, f(x));
        }
    }
    array
}

pub fn ref_to_array<T, F: Fn(&T) -> ocaml::Value>(v: &Vec<T>, f: F) -> ocaml::Array<ocaml::Value> {
    let len = v.len();
    // Manually allocate an OCaml array of the right size
    let mut array = ocaml::Array::alloc(len);
    for (i, x) in v.into_iter().enumerate() {
        unsafe {
            array.set_unchecked(i, f(x));
        }
    }
    array
}

pub fn to_array<Caml: ocaml::ToValue, T: Into<Caml>>(v: Vec<T>) -> ocaml::Array<ocaml::Value> {
    to_array_(v, |x| Into::<Caml>::into(x).to_value())
}

pub fn from_array_<A: ocaml::ToValue + ocaml::FromValue, T, F: Fn(A) -> T>(
    array: ocaml::Array<A>,
    f: F,
) -> Vec<T> {
    let len = array.len();
    let mut vec: Vec<T> = Vec::with_capacity(len);
    for i in 0..len {
        unsafe {
            vec.push(f(array.get_unchecked(i)));
        }
    }
    vec
}

pub fn from_array<Caml: ocaml::ToValue + ocaml::FromValue, T: From<Caml>>(
    array: ocaml::Array<Caml>,
) -> Vec<T> {
    from_array_(array, T::from)
}

pub fn from_value_array<Caml: ocaml::FromValue, T: From<Caml>>(
    array: ocaml::Array<ocaml::Value>,
) -> Vec<T> {
    from_array_(array, |x| Caml::from_value(x).into())
}
