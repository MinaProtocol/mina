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
}

ocaml::custom!(CamlPointer<T> {
    finalize: CamlPointer::<T>::caml_pointer_finalize,
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
