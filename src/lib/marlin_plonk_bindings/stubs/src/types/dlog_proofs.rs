use ark_ec::AffineCurve;
use plonk_protocol_dlog::{
    index::VerifierIndex as DlogVerifierIndex, prover::ProverProof as DlogProof,
};
use std::ops::Deref;

#[derive(Clone)]
pub struct CamlDlogProof<G>(pub DlogProof<G>)
where
    G: AffineCurve;

unsafe impl<G> ocaml::FromValue for CamlDlogProof<G>
where
    G: AffineCurve,
{
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        x.as_ref().clone()
    }
}

impl<G> CamlDlogProof<G>
where
    G: AffineCurve,
{
    extern "C" fn caml_pointer_finalize(v: ocaml::Value) {
        let v: ocaml::Pointer<Self> = ocaml::FromValue::from_value(v);
        unsafe {
            v.drop_in_place();
        }
    }
}

impl<G> ocaml::Custom for CamlDlogProof<G>
where
    G: AffineCurve,
{
    ocaml::custom! {
        name: concat!("rust.CamlDlogProof"),
        finalize: CamlDlogProof::<G>::caml_pointer_finalize,
    }
}

impl<G> Deref for CamlDlogProof<G>
where
    G: AffineCurve,
{
    type Target = DlogProof<G>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}
