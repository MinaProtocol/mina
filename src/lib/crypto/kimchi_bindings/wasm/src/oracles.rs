use crate::wasm_vector::WasmVector;
use ark_ff::{One, Zero};
use kimchi::{
    circuits::scalars::RandomOracles, proof::ProverProof,
    verifier_index::VerifierIndex as DlogVerifierIndex,
};
use mina_poseidon::{
    self,
    constants::PlonkSpongeConstantsKimchi,
    sponge::{DefaultFqSponge, DefaultFrSponge},
    FqSponge,
};
use paste::paste;
use poly_commitment::{
    commitment::{shift_scalar, PolyComm},
    ipa::OpeningProof,
    SRS,
};
use wasm_bindgen::prelude::*;

//
// CamlOracles
//

//
// Implementation
//

macro_rules! impl_oracles {
    ($WasmF: ty,
     $F: ty,
     $WasmG: ty,
     $G: ty,
     $WasmPolyComm: ty,
     $WasmProverProof: ty,
     $index: ty,
     $curve_params: ty,
     $field_name: ident) => {

        paste! {
            use wasm_types::FlatVector as WasmFlatVector;
            use mina_poseidon::sponge::ScalarChallenge;

            #[wasm_bindgen]
            #[derive(Clone, Copy)]
            pub struct [<Wasm $field_name:camel RandomOracles>] {
                pub joint_combiner_chal: Option<$WasmF>,
                pub joint_combiner: Option<$WasmF>,
                pub beta: $WasmF,
                pub gamma: $WasmF,
                pub alpha_chal: $WasmF,
                pub alpha: $WasmF,
                pub zeta: $WasmF,
                pub v: $WasmF,
                pub u: $WasmF,
                pub zeta_chal: $WasmF,
                pub v_chal: $WasmF,
                pub u_chal: $WasmF,
            }
            type WasmRandomOracles = [<Wasm $field_name:camel RandomOracles>];

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel RandomOracles>] {
                #[allow(clippy::too_many_arguments)]
                #[wasm_bindgen(constructor)]
                pub fn new(
                    joint_combiner_chal: Option<$WasmF>,
                    joint_combiner: Option<$WasmF>,
                    beta: $WasmF,
                    gamma: $WasmF,
                    alpha_chal: $WasmF,
                    alpha: $WasmF,
                    zeta: $WasmF,
                    v: $WasmF,
                    u: $WasmF,
                    zeta_chal: $WasmF,
                    v_chal: $WasmF,
                    u_chal: $WasmF) -> Self  {
                    Self {
                        joint_combiner_chal,
                        joint_combiner,
                        beta,
                        gamma,
                        alpha_chal,
                        alpha,
                        zeta,
                        v,
                        u,
                        zeta_chal,
                        v_chal,
                        u_chal,
                    }
                }
            }

            impl From<RandomOracles<$F>> for WasmRandomOracles
            {
                fn from(ro: RandomOracles<$F>) -> Self {
                    Self {
                        joint_combiner_chal: ro.joint_combiner.as_ref().map(|x| x.0.0.into()),
                        joint_combiner: ro.joint_combiner.as_ref().map(|x| x.1.into()),
                        beta: ro.beta.into(),
                        gamma: ro.gamma.into(),
                        alpha_chal: ro.alpha_chal.0.into(),
                        alpha: ro.alpha.into(),
                        zeta: ro.zeta.into(),
                        v: ro.v.into(),
                        u: ro.u.into(),
                        zeta_chal: ro.zeta_chal.0.into(),
                        v_chal: ro.v_chal.0.into(),
                        u_chal: ro.u_chal.0.into(),
                    }
                }
            }

            impl From<WasmRandomOracles> for RandomOracles<$F>
            {
                fn from(ro: WasmRandomOracles) -> Self {
                    Self {
                        joint_combiner: ro.joint_combiner_chal.and_then(|x| {
                            ro.joint_combiner.map(|y| (ScalarChallenge(x.into()), y.into()))
                        }),
                        beta: ro.beta.into(),
                        gamma: ro.gamma.into(),
                        alpha_chal: ScalarChallenge(ro.alpha_chal.into()),
                        alpha: ro.alpha.into(),
                        zeta: ro.zeta.into(),
                        v: ro.v.into(),
                        u: ro.u.into(),
                        zeta_chal: ScalarChallenge(ro.zeta_chal.into()),
                        v_chal: ScalarChallenge(ro.v_chal.into()),
                        u_chal: ScalarChallenge(ro.u_chal.into()),
                    }
                }
            }

            #[wasm_bindgen]
            #[derive(Clone)]
            pub struct [<Wasm $field_name:camel Oracles>] {
                pub o: [<Wasm $field_name:camel RandomOracles>],
                pub p_eval0: $WasmF,
                pub p_eval1: $WasmF,
                #[wasm_bindgen(skip)]
                pub opening_prechallenges: WasmFlatVector<$WasmF>,
                pub digest_before_evaluations: $WasmF,
            }

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel Oracles>] {
                #[wasm_bindgen(constructor)]
                pub fn new(
                    o: WasmRandomOracles,
                    p_eval0: $WasmF,
                    p_eval1: $WasmF,
                    opening_prechallenges: WasmFlatVector<$WasmF>,
                    digest_before_evaluations: $WasmF) -> Self {
                    Self {o, p_eval0, p_eval1, opening_prechallenges, digest_before_evaluations}
                }

                #[wasm_bindgen(getter)]
                pub fn opening_prechallenges(&self) -> WasmFlatVector<$WasmF> {
                    self.opening_prechallenges.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_opening_prechallenges(&mut self, x: WasmFlatVector<$WasmF>) {
                    self.opening_prechallenges = x;
                }
            }

            #[wasm_bindgen]
            pub fn [<$F:snake _oracles_create>](
                lgr_comm: WasmVector<$WasmPolyComm>, // the bases to commit polynomials
                index: $index,    // parameters
                proof: $WasmProverProof, // the final proof (contains public elements at the beginning)
            ) -> Result<[<Wasm $field_name:camel Oracles>], JsError> {
                // conversions
                let result = crate::rayon::run_in_pool(|| {
                    let index: DlogVerifierIndex<$G, OpeningProof<$G>> = index.into();

                    let lgr_comm: Vec<PolyComm<$G>> = lgr_comm
                        .into_iter()
                        .take(proof.public.len())
                        .map(Into::into)
                        .collect();
                    let lgr_comm_refs: Vec<_> = lgr_comm.iter().collect();

                    let p_comm = PolyComm::<$G>::multi_scalar_mul(
                        &lgr_comm_refs,
                        &proof
                            .public
                            .iter()
                            .map(|a| a.clone().into())
                            .map(|s: $F| -s)
                            .collect::<Vec<_>>(),
                    );
                    let p_comm = {
                        index
                            .srs()
                            .mask_custom(
                                p_comm.clone(),
                                &p_comm.map(|_| $F::one()),
                            )
                            .unwrap()
                            .commitment
                    };

                    let (proof, public_input): (ProverProof<$G, OpeningProof<$G>>, Vec<$F>) = proof.into();

                    let oracles_result =
                        proof.oracles::<
                            DefaultFqSponge<$curve_params, PlonkSpongeConstantsKimchi>,
                            DefaultFrSponge<$F, PlonkSpongeConstantsKimchi>
                        >(&index, &p_comm, Some(&public_input));
                    let oracles_result = match oracles_result {
                        Err(e) => {
                            return Err(format!("oracles_create: {}", e));
                        }
                        Ok(cs) => cs,
                    };

                    let (mut sponge, combined_inner_product, p_eval, digest, oracles) = (
                        oracles_result.fq_sponge,
                        oracles_result.combined_inner_product,
                        oracles_result.public_evals,
                        oracles_result.digest,
                        oracles_result.oracles,
                    );

                    sponge.absorb_fr(&[shift_scalar::<$G>(combined_inner_product)]);

                    let opening_prechallenges = proof
                        .proof
                        .prechallenges(&mut sponge)
                        .into_iter()
                        .map(|x| x.0.into())
                        .collect();

                    Ok((oracles, p_eval, opening_prechallenges, digest))
                });

                match result {
                    Ok((oracles, p_eval, opening_prechallenges, digest)) => Ok([<Wasm $field_name:camel Oracles>] {
                        o: oracles.into(),
                        p_eval0: p_eval[0][0].into(),
                        p_eval1: p_eval[1][0].into(),
                        opening_prechallenges,
                        digest_before_evaluations: digest.into()
                    }),
                    Err(err) => Err(JsError::new(&err))
                }
            }

            #[wasm_bindgen]
            pub fn [<$F:snake _oracles_dummy>]() -> [<Wasm $field_name:camel Oracles>] {
                [<Wasm $field_name:camel Oracles>] {
                    o: RandomOracles::<$F>::default().into(),
                    p_eval0: $F::zero().into(),
                    p_eval1: $F::zero().into(),
                    opening_prechallenges: vec![].into(),
                    digest_before_evaluations: $F::zero().into(),
                }
            }

            #[wasm_bindgen]
            pub fn [<$F:snake _oracles_deep_copy>](
                x: $WasmProverProof,
            ) -> $WasmProverProof {
                x
            }
        }
    }
}

//
//
//

pub mod fp {
    use super::*;
    use crate::{
        plonk_proof::fp::WasmFpProverProof as WasmProverProof,
        plonk_verifier_index::fp::WasmFpPlonkVerifierIndex as WasmPlonkVerifierIndex,
        poly_comm::vesta::WasmFpPolyComm as WasmPolyComm,
    };
    use arkworks::WasmPastaFp;
    use mina_curves::pasta::{Fp, Vesta as GAffine, VestaParameters};

    impl_oracles!(
        WasmPastaFp,
        Fp,
        WasmGVesta,
        GAffine,
        WasmPolyComm,
        WasmProverProof,
        WasmPlonkVerifierIndex,
        VestaParameters,
        Fp
    );
}

pub mod fq {
    use super::*;
    use crate::{
        plonk_proof::fq::WasmFqProverProof as WasmProverProof,
        plonk_verifier_index::fq::WasmFqPlonkVerifierIndex as WasmPlonkVerifierIndex,
        poly_comm::pallas::WasmFqPolyComm as WasmPolyComm,
    };
    use arkworks::WasmPastaFq;
    use mina_curves::pasta::{Fq, Pallas as GAffine, PallasParameters};

    impl_oracles!(
        WasmPastaFq,
        Fq,
        WasmGPallas,
        GAffine,
        WasmPolyComm,
        WasmProverProof,
        WasmPlonkVerifierIndex,
        PallasParameters,
        Fq
    );
}
