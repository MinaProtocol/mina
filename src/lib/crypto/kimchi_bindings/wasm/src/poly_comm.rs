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
            use commitment_dlog::commitment::PolyComm;

            #[wasm_bindgen]
            #[derive(Clone)]
            pub struct [<Wasm $field_name:camel PolyComm>] {
                #[wasm_bindgen(skip)]
                pub unshifted: WasmVector<$WasmG>,
                pub shifted: Option<$WasmG>,
            }

            type WasmPolyComm = [<Wasm $field_name:camel PolyComm>];

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel PolyComm>] {
                #[wasm_bindgen(constructor)]
                pub fn new(unshifted: WasmVector<$WasmG>, shifted: Option<$WasmG>) -> Self {
                    WasmPolyComm { unshifted, shifted }
                }

                #[wasm_bindgen(getter)]
                pub fn unshifted(&self) -> WasmVector<$WasmG> {
                    self.unshifted.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_unshifted(&mut self, x: WasmVector<$WasmG>) {
                    self.unshifted = x
                }
            }

            impl From<PolyComm<$G>> for WasmPolyComm {
                fn from(x: PolyComm<$G>) -> Self {
                    let PolyComm {unshifted, shifted} = x;
                    let unshifted: Vec<$WasmG> =
                        unshifted.into_iter().map(|x| x.into()).collect();
                    WasmPolyComm {
                        unshifted: unshifted.into(),
                        shifted: shifted.map(|x| x.into()),
                    }
                }
            }

            impl From<&PolyComm<$G>> for WasmPolyComm {
                fn from(x: &PolyComm<$G>) -> Self {
                    let unshifted: Vec<$WasmG> =
                        x.unshifted.iter().map(|x| x.into()).collect();
                    WasmPolyComm {
                        unshifted: unshifted.into(),
                        shifted: x.shifted.map(|x| x.into()),
                    }
                }
            }

            impl From<WasmPolyComm> for PolyComm<$G> {
                fn from(x: WasmPolyComm) -> Self {
                    let WasmPolyComm {unshifted, shifted} = x;
                    PolyComm {
                        unshifted: (*unshifted).iter().map(|x| { (*x).into() }).collect(),
                        shifted: shifted.map(|x| x.into()),
                    }
                }
            }

            impl From<&WasmPolyComm> for PolyComm<$G> {
                fn from(x: &WasmPolyComm) -> Self {
                    PolyComm {
                        unshifted: x.unshifted.iter().map(|x| { (*x).into() }).collect(),
                        shifted: x.shifted.map(|x| x.into()),
                    }
                }
            }
        }
    };
}

pub mod pallas {
    use super::*;
    use crate::arkworks::group_affine::WasmGPallas;
    use mina_curves::pasta::pallas::Affine as GAffine;

    impl_poly_comm!(WasmGPallas, GAffine, Fq);
}

pub mod vesta {
    use super::*;
    use crate::arkworks::group_affine::WasmGVesta;
    use mina_curves::pasta::vesta::Affine as GAffine;

    impl_poly_comm!(WasmGVesta, GAffine, Fp);
}
