pub fn to_array<Caml: ocaml::ToValue, T: Into<Caml>>(x: Vec<T>) -> ocaml::Array<ocaml::Value> {
    let len = x.len();
    // Manually allocate an OCaml array of the right size
    let mut array = ocaml::Array::alloc(len);
    let mut i = 0;
    for c in x.into_iter() {
        unsafe {
            // Construct the OCaml value for each element, then place it in the correct position in
            // the array.
            // Bounds checks are skipped because we know statically that the indices are in range.
            array.set_unchecked(i, c.into().to_value());
        }
        i = i + 1;
    }
    array
}

pub fn ref_to_array<'a, Caml: ocaml::ToValue + From<&'a T>, T: 'a>(
    x: &'a Vec<T>,
) -> ocaml::Array<ocaml::Value> {
    let len = x.len();
    // Manually allocate an OCaml array of the right size
    let mut array = ocaml::Array::alloc(len);
    let mut i = 0;
    for c in x.into_iter() {
        unsafe {
            // Construct the OCaml value for each element, then place it in the correct position in
            // the array.
            // Bounds checks are skipped because we know statically that the indices are in range.
            array.set_unchecked(i, Caml::from(&c).to_value());
        }
        i = i + 1;
    }
    array
}

pub fn from_array<Caml: ocaml::ToValue + ocaml::FromValue, T: From<Caml>>(
    array: ocaml::Array<Caml>,
) -> Vec<T> {
    let len = array.len();
    let mut vec: Vec<T> = Vec::with_capacity(len);
    for i in 0..len {
        unsafe {
            vec.push(array.get_unchecked(i).into());
        }
    }
    vec
}

pub fn from_value_array<Caml: ocaml::FromValue, T: From<Caml>>(
    array: ocaml::Array<ocaml::Value>,
) -> Vec<T> {
    let len = array.len();
    let mut vec: Vec<T> = Vec::with_capacity(len);
    for i in 0..len {
        unsafe {
            vec.push(Caml::from_value(array.get_unchecked(i)).into());
        }
    }
    vec
}

pub fn from_pointer_array<Caml, T: From<ocaml::Pointer<Caml>>>(
    array: ocaml::Array<ocaml::Pointer<Caml>>,
) -> Vec<T> {
    let len = array.len();
    let mut vec: Vec<T> = Vec::with_capacity(len);
    for i in 0..len {
        unsafe {
            vec.push(array.get_unchecked(i).into());
        }
    }
    vec
}
