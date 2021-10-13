use wasm_bindgen::prelude::*;
use wasm_bindgen::convert::{IntoWasmAbi, FromWasmAbi};
use mina_curves::pasta::{
    vesta::{Affine as GAffine, VestaParameters},
    fp::Fp,
};
use algebra::Zero;

use oracle::{
    self,
    poseidon::PlonkSpongeConstants,
    sponge::{DefaultFqSponge, DefaultFrSponge},
    FqSponge,
};

use commitment_dlog::commitment::{shift_scalar, PolyComm};
use plonk_protocol_dlog::{
    index::VerifierIndex as DlogVerifierIndex, prover::ProverProof as DlogProof,
};

use crate::pasta_fp::WasmPastaFp;
use crate::wasm_vector::WasmVector;
use crate::wasm_flat_vector::WasmFlatVector;
use crate::pasta_vesta_poly_comm::WasmPastaVestaPolyComm;
use crate::pasta_fp_plonk_verifier_index::WasmPastaFpPlonkVerifierIndex;
use crate::pasta_fp_plonk_proof::WasmPastaFpProverProof;

#[derive(Copy, Clone, Debug)]
pub struct WasmPastaFpRandomOracles
{
    pub beta: WasmPastaFp,
    pub gamma: WasmPastaFp,
    pub alpha_chal: WasmPastaFp,
    pub alpha: WasmPastaFp,
    pub zeta: WasmPastaFp,
    pub v: WasmPastaFp,
    pub u: WasmPastaFp,
    pub zeta_chal: WasmPastaFp,
    pub v_chal: WasmPastaFp,
    pub u_chal: WasmPastaFp,
}

impl wasm_bindgen::describe::WasmDescribe for WasmPastaFpRandomOracles {
    fn describe() { <WasmFlatVector<WasmPastaFp> as wasm_bindgen::describe::WasmDescribe>::describe() }
}

impl FromWasmAbi for WasmPastaFpRandomOracles {
    type Abi = <WasmFlatVector<WasmPastaFp> as FromWasmAbi>::Abi;
    unsafe fn from_abi(js: Self::Abi) -> Self {
        let fields: Vec<WasmPastaFp> = From::<WasmFlatVector<WasmPastaFp>>::from(FromWasmAbi::from_abi(js));
        WasmPastaFpRandomOracles {
            beta: fields[0],
            gamma: fields[1],
            alpha_chal: fields[2],
            alpha: fields[3],
            zeta: fields[4],
            v: fields[5],
            u: fields[6],
            zeta_chal: fields[7],
            v_chal: fields[8],
            u_chal: fields[9],
        }
    }
}

impl IntoWasmAbi for WasmPastaFpRandomOracles {
    type Abi = <WasmFlatVector<WasmPastaFp> as FromWasmAbi>::Abi;
    fn into_abi(self) -> Self::Abi {
        let vec: WasmFlatVector<WasmPastaFp> =
            (vec![
                self.beta,
                self.gamma,
                self.alpha_chal,
                self.alpha,
                self.zeta,
                self.v,
                self.u,
                self.zeta_chal,
                self.v_chal,
                self.u_chal]
            ).into();
        vec.into_abi()
    }
}

#[wasm_bindgen]
pub struct WasmPastaFpPlonkOracles {
    pub o: WasmPastaFpRandomOracles,
    pub p_eval0: WasmPastaFp,
    pub p_eval1: WasmPastaFp,
    #[wasm_bindgen(skip)]
    pub opening_prechallenges: WasmFlatVector<WasmPastaFp>,
    pub digest_before_evaluations: WasmPastaFp,
}

#[wasm_bindgen]
impl WasmPastaFpPlonkOracles {
    #[wasm_bindgen(constructor)]
    pub fn new(
        o: WasmPastaFpRandomOracles,
        p_eval0: WasmPastaFp,
        p_eval1: WasmPastaFp,
        opening_prechallenges: WasmFlatVector<WasmPastaFp>,
        digest_before_evaluations: WasmPastaFp) -> Self {
        Self {o, p_eval0, p_eval1, opening_prechallenges, digest_before_evaluations}
    }

    #[wasm_bindgen(getter)]
    pub fn opening_prechallenges(&self) -> WasmFlatVector<WasmPastaFp> {
        self.opening_prechallenges.clone()
    }

    #[wasm_bindgen(setter)]
    pub fn set_opening_prechallenges(&mut self, x: WasmFlatVector<WasmPastaFp>) {
        self.opening_prechallenges = x
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_oracles_create(
    lgr_comm: WasmVector<WasmPastaVestaPolyComm>,
    index: WasmPastaFpPlonkVerifierIndex,
    proof: WasmPastaFpProverProof,
) -> Result<WasmPastaFpPlonkOracles, JsValue> {
    let index: DlogVerifierIndex<'_, GAffine> = index.into();
    let proof: DlogProof<GAffine> = proof.into();
    let lgr_comm: Vec<PolyComm<GAffine>> = lgr_comm.into_iter().map(From::from).collect();

    let p_comm = PolyComm::<GAffine>::multi_scalar_mul(
        &lgr_comm
            .iter()
            .take(proof.public.len())
            .map(|x| x)
            .collect(),
        &proof.public.iter().map(|s| -*s).collect(),
    ).ok_or("Could not commit to public inputs")?;
    let (mut sponge, digest_before_evaluations, o, _, p_eval, _, _, _, combined_inner_product) =
        proof.oracles::<DefaultFqSponge<VestaParameters, PlonkSpongeConstants>, DefaultFrSponge<Fp, PlonkSpongeConstants>>(&index, &p_comm).ok_or("Could not create oracles")?;

    sponge.absorb_fr(&[shift_scalar(combined_inner_product)]);

    Ok(WasmPastaFpPlonkOracles {
        o: WasmPastaFpRandomOracles {
            beta: o.beta.into(),
            gamma: o.gamma.into(),
            alpha_chal: o.alpha_chal.0.into(),
            alpha: o.alpha.into(),
            zeta: o.zeta.into(),
            v: o.v.into(),
            u: o.u.into(),
            zeta_chal: o.zeta_chal.0.into(),
            v_chal: o.v_chal.0.into(),
            u_chal: o.u_chal.0.into(),
        },
        p_eval0: p_eval[0][0].into(),
        p_eval1: p_eval[1][0].into(),
        opening_prechallenges: proof
            .proof
            .prechallenges(&mut sponge)
            .into_iter()
            .map(|x| x.0.into())
            .collect(),
        digest_before_evaluations: digest_before_evaluations.into(),
    })
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_oracles_dummy() -> WasmPastaFpPlonkOracles {
    WasmPastaFpPlonkOracles {
        o: WasmPastaFpRandomOracles {
            beta: Fp::zero().into(),
            gamma: Fp::zero().into(),
            alpha: Fp::zero().into(),
            zeta: Fp::zero().into(),
            v: Fp::zero().into(),
            u: Fp::zero().into(),
            alpha_chal: Fp::zero().into(),
            zeta_chal: Fp::zero().into(),
            v_chal: Fp::zero().into(),
            u_chal: Fp::zero().into(),
        },
        p_eval0: Fp::zero().into(),
        p_eval1: Fp::zero().into(),
        opening_prechallenges: vec![].into(),
        digest_before_evaluations: Fp::zero().into(),
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_oracles_deep_copy(x: WasmPastaFpPlonkOracles) -> WasmPastaFpPlonkOracles {
    x
}
