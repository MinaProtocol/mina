use ark_ff::Field;
use plonk_circuits::scalars::RandomOracles;
use std::ops::Deref;

#[derive(Clone)]
pub struct CamlRandomOracles<F>(pub RandomOracles<F>)
where
    F: Field;

unsafe impl<F> ocaml::FromValue for CamlRandomOracles<F>
where
    F: Field,
{
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        x.as_ref().clone()
    }
}

impl<F> CamlRandomOracles<F>
where
    F: Field,
{
    extern "C" fn caml_pointer_finalize(v: ocaml::Value) {
        let v: ocaml::Pointer<Self> = ocaml::FromValue::from_value(v);
        unsafe {
            v.drop_in_place();
        }
    }
}

impl<F> ocaml::Custom for CamlRandomOracles<F>
where
    F: Field,
{
    ocaml::custom! {
        name: concat!("rust.CamlRandomOracles"),
        finalize: CamlRandomOracles::<F>::caml_pointer_finalize,
    }
}

impl<F> Deref for CamlRandomOracles<F>
where
    F: Field,
{
    type Target = RandomOracles<F>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}
