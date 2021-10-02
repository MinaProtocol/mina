use ocaml_gen::OCamlCustomType;
use std::ops::{Deref, DerefMut};
use std::rc::Rc;

/// A CamlPointer is just a pointer to a reference-counting pointer ([Rc]).
#[derive(Debug, Clone, OCamlCustomType)]
pub struct CamlPointer<T>(pub Rc<T>);

impl<T> CamlPointer<T> {
    extern "C" fn caml_pointer_finalize(v: ocaml::Raw) {
        unsafe {
            let v: ocaml::Pointer<CamlPointer<T>> = v.as_pointer();
            v.drop_in_place();
        }
    }

    extern "C" fn caml_pointer_compare(_: ocaml::Raw, _: ocaml::Raw) -> i32 {
        // Always return equal. We can use this for sanity checks, and anything else using this
        // would be broken anyway.
        0
    }

    pub fn new(x: T) -> Self {
        CamlPointer(Rc::new(x))
    }
}

ocaml::custom!(CamlPointer<T> {
    finalize: CamlPointer::<T>::caml_pointer_finalize,
    compare: CamlPointer::<T>::caml_pointer_compare,
});

unsafe impl<'a, T> ocaml::FromValue<'a> for CamlPointer<T> {
    fn from_value(x: ocaml::Value) -> Self {
        let x = ocaml::Pointer::<Self>::from_value(x);
        CamlPointer(x.as_ref().0.clone())
    }
}

impl<T> Deref for CamlPointer<T> {
    type Target = T;

    fn deref(&self) -> &Self::Target {
        &*self.0
    }
}

impl<T> DerefMut for CamlPointer<T> {
    fn deref_mut(&mut self) -> &mut Self::Target {
        unsafe {
            // Wholely unsafe, Batman!
            // We would use [`get_mut_unchecked`] here, but it is nightly-only.
            // Instead, we get coerce our constant pointer to a mutable pointer, in the knowledge
            // that
            // * all of our mutations called from OCaml are blocking, so we won't have multiple
            // live mutable references live simultaneously, and
            // * the underlying pointer is in the correct state to be mutable, since we can call
            //   [`get_mut_unchecked`] in nightly, or can call [`get_mut`] and unwrap if this is
            //   the only live reference.
            &mut *(((&*self.0) as *const Self::Target) as *mut Self::Target)
        }
    }
}
