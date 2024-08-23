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
                pub unshifted: WasmVector<$WasmG>,
                pub shifted: Option<$WasmG>,
            }

            type WasmPolyComm = [<Wasm $field_name:camel PolyComm>];

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel PolyComm>] {
                #[wasm_bindgen(constructor)]
                pub fn new(unshifted: WasmVector<$WasmG>, shifted: Option<$WasmG>) -> Self {
                    assert!(
                        shifted.is_none(),
                        "mina#14628: Shifted commitments are deprecated and must not be used"
                    );
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
                    let PolyComm { elems } = x;
                    let unshifted: Vec<$WasmG> =
                        elems.into_iter().map(|x| x.into()).collect();
                    WasmPolyComm {
                        unshifted: unshifted.into(),
                        shifted: None
                    }
                }
            }

            impl From<&PolyComm<$G>> for WasmPolyComm {
                fn from(x: &PolyComm<$G>) -> Self {
                    let unshifted: Vec<$WasmG> =
                        x.elems.iter().map(|x| x.into()).collect();
                    WasmPolyComm {
                        unshifted: unshifted.into(),
                        shifted: None,
                    }
                }
            }

            impl From<WasmPolyComm> for PolyComm<$G> {
                fn from(x: WasmPolyComm) -> Self {
                    let WasmPolyComm {unshifted, shifted} = x;
                    assert!(
                        shifted.is_none(),
                        "mina#14628: Shifted commitments are deprecated and must not be used"
                    );
                    PolyComm {
                        elems: (*unshifted).iter().map(|x| { (*x).into() }).collect(),
                    }
                }
            }

            impl From<&WasmPolyComm> for PolyComm<$G> {
                fn from(x: &WasmPolyComm) -> Self {
                    assert!(
                        x.shifted.is_none(),
                        "mina#14628: Shifted commitments are deprecated and must not be used"
                    );
                    PolyComm {
                        elems: x.unshifted.iter().map(|x| { (*x).into() }).collect(),
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
