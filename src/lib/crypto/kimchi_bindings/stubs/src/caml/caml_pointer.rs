macro_rules! impl_caml_pointer {
    ($name: ident => $typ: ty) => {
        #[derive(std::fmt::Debug, Clone, ::ocaml_gen::CustomType)]
        pub struct $name(pub ::std::rc::Rc<$typ>);

        impl $name {
            extern "C" fn caml_pointer_finalize(v: ocaml::Raw) {
                unsafe {
                    let v: ocaml::Pointer<$name> = v.as_pointer();
                    v.drop_in_place();
                }
            }

            extern "C" fn caml_pointer_compare(_: ocaml::Raw, _: ocaml::Raw) -> i32 {
                // Always return equal. We can use this for sanity checks, and anything else using this
                // would be broken anyway.
                0
            }
        }

        ocaml::custom!($name {
            finalize: $name::caml_pointer_finalize,
            compare: $name::caml_pointer_compare,
        });

        unsafe impl<'a> ocaml::FromValue<'a> for $name {
            fn from_value(x: ocaml::Value) -> Self {
                let x = ocaml::Pointer::<Self>::from_value(x);
                $name(x.as_ref().0.clone())
            }
        }

        impl $name {
            pub fn create(x: $typ) -> $name {
                $name(::std::rc::Rc::new(x))
            }
        }

        impl ::std::ops::Deref for $name {
            type Target = $typ;

            fn deref(&self) -> &Self::Target {
                &*self.0
            }
        }

        impl ::std::ops::DerefMut for $name {
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
    };
}
