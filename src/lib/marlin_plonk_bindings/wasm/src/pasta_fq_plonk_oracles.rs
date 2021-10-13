use wasm_bindgen::prelude::*;
use wasm_bindgen::convert::{IntoWasmAbi, FromWasmAbi};
use mina_curves::pasta::{
    pallas::{Affine as GAffine, PallasParameters},
    fq::Fq,
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

use crate::pasta_fq::WasmPastaFq;
use crate::wasm_vector::WasmVector;
use crate::wasm_flat_vector::WasmFlatVector;
use crate::pasta_pallas_poly_comm::WasmPastaPallasPolyComm;
use crate::pasta_fq_plonk_verifier_index::WasmPastaFqPlonkVerifierIndex;
use crate::pasta_fq_plonk_proof::WasmPastaFqProverProof;

#[derive(Copy, Clone, Debug)]
pub struct WasmPastaFqRandomOracles
{
    pub beta: WasmPastaFq,
    pub gamma: WasmPastaFq,
    pub alpha_chal: WasmPastaFq,
    pub alpha: WasmPastaFq,
    pub zeta: WasmPastaFq,
    pub v: WasmPastaFq,
    pub u: WasmPastaFq,
    pub zeta_chal: WasmPastaFq,
    pub v_chal: WasmPastaFq,
    pub u_chal: WasmPastaFq,
}

impl wasm_bindgen::describe::WasmDescribe for WasmPastaFqRandomOracles {
    fn describe() { <WasmFlatVector<WasmPastaFq> as wasm_bindgen::describe::WasmDescribe>::describe() }
}

impl FromWasmAbi for WasmPastaFqRandomOracles {
    type Abi = <WasmFlatVector<WasmPastaFq> as FromWasmAbi>::Abi;
    unsafe fn from_abi(js: Self::Abi) -> Self {
        let fields: Vec<WasmPastaFq> = From::<WasmFlatVector<WasmPastaFq>>::from(FromWasmAbi::from_abi(js));
        WasmPastaFqRandomOracles {
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

impl IntoWasmAbi for WasmPastaFqRandomOracles {
    type Abi = <WasmFlatVector<WasmPastaFq> as FromWasmAbi>::Abi;
    fn into_abi(self) -> Self::Abi {
        let vec: WasmFlatVector<WasmPastaFq> =
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
pub struct WasmPastaFqPlonkOracles {
    pub o: WasmPastaFqRandomOracles,
    pub p_eval0: WasmPastaFq,
    pub p_eval1: WasmPastaFq,
    #[wasm_bindgen(skip)]
    pub opening_prechallenges: WasmFlatVector<WasmPastaFq>,
    pub digest_before_evaluations: WasmPastaFq,
}

#[wasm_bindgen]
impl WasmPastaFqPlonkOracles {
    #[wasm_bindgen(constructor)]
    pub fn new(
        o: WasmPastaFqRandomOracles,
        p_eval0: WasmPastaFq,
        p_eval1: WasmPastaFq,
        opening_prechallenges: WasmFlatVector<WasmPastaFq>,
        digest_before_evaluations: WasmPastaFq) -> Self {
        Self {o, p_eval0, p_eval1, opening_prechallenges, digest_before_evaluations}
    }

    #[wasm_bindgen(getter)]
    pub fn opening_prechallenges(&self) -> WasmFlatVector<WasmPastaFq> {
        self.opening_prechallenges.clone()
    }

    #[wasm_bindgen(setter)]
    pub fn set_opening_prechallenges(&mut self, x: WasmFlatVector<WasmPastaFq>) {
        self.opening_prechallenges = x
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_oracles_create(
    lgr_comm: WasmVector<WasmPastaPallasPolyComm>,
    index: WasmPastaFqPlonkVerifierIndex,
    proof: WasmPastaFqProverProof,
) -> Result<WasmPastaFqPlonkOracles, JsValue> {
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
        proof.oracles::<DefaultFqSponge<PallasParameters, PlonkSpongeConstants>, DefaultFrSponge<Fq, PlonkSpongeConstants>>(&index, &p_comm).ok_or("Could not create oracles")?;

    sponge.absorb_fr(&[shift_scalar(combined_inner_product)]);

    Ok(WasmPastaFqPlonkOracles {
        o: WasmPastaFqRandomOracles {
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
pub fn caml_pasta_fq_plonk_oracles_dummy() -> WasmPastaFqPlonkOracles {
    WasmPastaFqPlonkOracles {
        o: WasmPastaFqRandomOracles {
            beta: Fq::zero().into(),
            gamma: Fq::zero().into(),
            alpha: Fq::zero().into(),
            zeta: Fq::zero().into(),
            v: Fq::zero().into(),
            u: Fq::zero().into(),
            alpha_chal: Fq::zero().into(),
            zeta_chal: Fq::zero().into(),
            v_chal: Fq::zero().into(),
            u_chal: Fq::zero().into(),
        },
        p_eval0: Fq::zero().into(),
        p_eval1: Fq::zero().into(),
        opening_prechallenges: vec![].into(),
        digest_before_evaluations: Fq::zero().into(),
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_oracles_deep_copy(x: WasmPastaFqPlonkOracles) -> WasmPastaFqPlonkOracles {
    x
}
