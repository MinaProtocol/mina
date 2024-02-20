use crate::wasm_vector::WasmVector;
use paste::paste;
macro_rules! impl_poly_comm {
    (
     $WasmG: ty,
     $G: ty,
     $field_name: ident
     /*
     $CamlScalarField: ty,
     $BaseField: ty,
     $CamlBaseField: ty,
     $Projective: ty */
     ) => {
        paste! {
            use wasm_bindgen::prelude::*;
            use poly_commitment::commitment::PolyComm;

            #[wasm_bindgen]
            #[derive(Clone)]
            pub struct [<Wasm $field_name:camel PolyComm>] {
                #[wasm_bindgen(skip)]
                pub elems: WasmVector<$WasmG>,
            }

            type WasmPolyComm = [<Wasm $field_name:camel PolyComm>];

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel PolyComm>] {
                #[wasm_bindgen(constructor)]
                pub fn new(elems: WasmVector<$WasmG>) -> Self {
                    WasmPolyComm { elems }
                }

                #[wasm_bindgen(getter)]
                pub fn elems(&self) -> WasmVector<$WasmG> {
                    self.elems.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_elems(&mut self, x: WasmVector<$WasmG>) {
                    self.elems = x
                }
            }

            impl From<PolyComm<$G>> for WasmPolyComm {
                fn from(x: PolyComm<$G>) -> Self {
                    let PolyComm {elems} = x;
                    let elems: Vec<$WasmG> =
                        elems.into_iter().map(|x| x.into()).collect();
                    WasmPolyComm {
                        elems: elems.into(),
                    }
                }
            }

            impl From<&PolyComm<$G>> for WasmPolyComm {
                fn from(x: &PolyComm<$G>) -> Self {
                    let elems: Vec<$WasmG> =
                        x.elems.iter().map(|x| x.into()).collect();
                    WasmPolyComm {
                        elems: elems.into(),
                    }
                }
            }

            impl From<WasmPolyComm> for PolyComm<$G> {
                fn from(x: WasmPolyComm) -> Self {
                    let WasmPolyComm {elems} = x;
                    PolyComm {
                        elems: (*elems).iter().map(|x| { (*x).into() }).collect(),
                    }
                }
            }

            impl From<&WasmPolyComm> for PolyComm<$G> {
                fn from(x: &WasmPolyComm) -> Self {
                    PolyComm {
                        elems: x.elems.iter().map(|x| { (*x).into() }).collect(),
                    }
                }
            }
        }
    };
}

pub mod pallas {
    use super::*;
    use crate::arkworks::group_affine::WasmGPallas;
    use mina_curves::pasta::Pallas as GAffine;

    impl_poly_comm!(WasmGPallas, GAffine, Fq);
}

pub mod vesta {
    use super::*;
    use crate::arkworks::group_affine::WasmGVesta;
    use mina_curves::pasta::Vesta as GAffine;

    impl_poly_comm!(WasmGVesta, GAffine, Fp);
}
