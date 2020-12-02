use std::ops::{Deref, DerefMut};

pub struct CamlPointer<T>(pub *mut T);

impl<T> CamlPointer<T> {
    extern "C" fn caml_pointer_finalize(v: ocaml::Value) {
        let mut v: ocaml::Pointer<CamlPointer<T>> = ocaml::FromValue::from_value(v);
        unsafe {
            // Memory is freed when the variable goes out of scope
            let _box = Box::from_raw(v.as_mut().0);
        }
    }

    extern "C" fn caml_pointer_compare(_: ocaml::Value, _: ocaml::Value) -> i32 {
        // Always return equal. We can use this for sanity checks, and anything else using this
        // would be broken anyway.
        0
    }
}

ocaml::custom!(CamlPointer<T> {
    finalize: CamlPointer::<T>::caml_pointer_finalize,
    compare: CamlPointer::<T>::caml_pointer_compare,
});

unsafe impl<T> ocaml::FromValue for CamlPointer<T> {
    fn from_value(x: ocaml::Value) -> Self {
        let x = ocaml::Pointer::<Self>::from_value(x);
        CamlPointer(x.as_ref().0)
    }
}

pub fn create<T>(x: T) -> CamlPointer<T> {
    CamlPointer(Box::into_raw(Box::new(x)))
}

impl<T> Deref for CamlPointer<T> {
    type Target = T;

    fn deref(&self) -> &Self::Target {
        unsafe { &*self.0 }
    }
}

impl<T> DerefMut for CamlPointer<T> {
    fn deref_mut(&mut self) -> &mut Self::Target {
        unsafe { &mut *self.0 }
    }
}
