// use kimchi::circuits::expr::{Linearization, PolishToken, Variable, Column};
// use kimchi::circuits::gate::{GateType, CurrOrNext};
use crate::wasm_flat_vector::WasmFlatVector;
use crate::wasm_vector::WasmVector;
use paste::paste;
use std::convert::TryInto;
use wasm_bindgen::prelude::*;
// use std::sync::Arc;
// use poly_commitment::srs::SRS;
// use kimchi::index::{expr_linearization, VerifierIndex as DlogVerifierIndex};
// use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use ark_ec::AffineCurve;
use ark_ff::One;
use array_init::array_init;
use kimchi::circuits::wires::COLUMNS;
use kimchi::verifier::Context;
use std::array;
// use std::path::Path;
use groupmap::GroupMap;
use kimchi::proof::{
    LookupCommitments, PointEvaluations, ProofEvaluations, ProverCommitments, ProverProof,
    RecursionChallenge,
};
use kimchi::prover_index::ProverIndex;
use kimchi::verifier::batch_verify;
use mina_poseidon::{
    constants::PlonkSpongeConstantsKimchi,
    sponge::{DefaultFqSponge, DefaultFrSponge},
};
use poly_commitment::{
    commitment::{CommitmentCurve, PolyComm},
    evaluation_proof::OpeningProof,
};
use serde::{Deserialize, Serialize};

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

macro_rules! impl_proof {
    (
     $name: ident,
     $WasmG: ty,
     $G: ty,
     $WasmF: ty,
     $F: ty,
     $WasmPolyComm: ty,
     $WasmSrs: ty,
     $GOther: ty,
     $FrSpongeParams: path,
     $FqSpongeParams: path,
     $WasmIndex: ty,
     $WasmVerifierIndex: ty,
     $field_name: ident
     ) => {

        paste! {
            #[wasm_bindgen]
            pub struct [<WasmVecVec $field_name:camel>](Vec<Vec<$F>>);
            type WasmVecVecF = [<WasmVecVec $field_name:camel>];

            #[wasm_bindgen]
            impl [<WasmVecVec $field_name:camel>] {
                #[wasm_bindgen(constructor)]
                pub fn create(n: i32) -> Self {
                    [<WasmVecVec $field_name:camel>](Vec::with_capacity(n as usize))
                }

                #[wasm_bindgen]
                pub fn push(&mut self, x: WasmFlatVector<$WasmF>) {
                    self.0.push(x.into_iter().map(Into::into).collect())
                }

                #[wasm_bindgen]
                pub fn get(&self, i: i32) -> WasmFlatVector<$WasmF> {
                    self.0[i as usize].clone().into_iter().map(Into::into).collect()
                }

                #[wasm_bindgen]
                pub fn set(&mut self, i: i32, x: WasmFlatVector<$WasmF>) {
                    self.0[i as usize] = x.into_iter().map(Into::into).collect()
                }
            }

            #[derive(Clone)]
            pub struct [<Wasm $field_name:camel ProofEvaluations>](
                ProofEvaluations<PointEvaluations<Vec<$F>>>
            );
            type WasmProofEvaluations = [<Wasm $field_name:camel ProofEvaluations>];

            impl wasm_bindgen::describe::WasmDescribe for WasmProofEvaluations {
                fn describe() {
                    <JsValue as wasm_bindgen::describe::WasmDescribe>::describe()
                }
            }

            impl wasm_bindgen::convert::FromWasmAbi for WasmProofEvaluations {
                type Abi = <JsValue as wasm_bindgen::convert::FromWasmAbi>::Abi;
                unsafe fn from_abi(js: Self::Abi) -> Self {
                    let js: JsValue = wasm_bindgen::convert::FromWasmAbi::from_abi(js);
                    Self(
                        ProofEvaluations::deserialize(
                            crate::wasm_ocaml_serde::de::Deserializer::from(js),
                        )
                        .unwrap(),
                    )
                }
            }

            impl wasm_bindgen::convert::IntoWasmAbi for WasmProofEvaluations {
                type Abi = <JsValue as wasm_bindgen::convert::IntoWasmAbi>::Abi;
                fn into_abi(self) -> Self::Abi {
                    let js = self
                        .0
                        .serialize(&crate::wasm_ocaml_serde::ser::Serializer::new())
                        .unwrap();
                    wasm_bindgen::convert::IntoWasmAbi::into_abi(js)
                }
            }

            impl From<&WasmProofEvaluations> for ProofEvaluations<PointEvaluations<Vec<$F>>> {
                fn from(x: &WasmProofEvaluations) -> Self {
                    x.0.clone()
                }
            }

            impl From<WasmProofEvaluations> for ProofEvaluations<PointEvaluations<Vec<$F>>> {
                fn from(x: WasmProofEvaluations) -> Self {
                    x.0
                }
            }

            impl From<&ProofEvaluations<PointEvaluations<Vec<$F>>>> for WasmProofEvaluations {
                fn from(x: &ProofEvaluations<PointEvaluations<Vec<$F>>>) -> Self {
                    Self(x.clone())
                }
            }

            impl From<ProofEvaluations<PointEvaluations<Vec<$F>>>> for WasmProofEvaluations {
                fn from(x: ProofEvaluations<PointEvaluations<Vec<$F>>>) -> Self {
                    Self(x)
                }
            }

            #[wasm_bindgen]
            #[derive(Clone)]
            pub struct [<Wasm $field_name:camel LookupCommitments>]
            {
                #[wasm_bindgen(skip)]
                pub sorted: WasmVector<$WasmPolyComm>,
                #[wasm_bindgen(skip)]
                pub aggreg: $WasmPolyComm,
                #[wasm_bindgen(skip)]
                pub runtime: Option<$WasmPolyComm>,
            }

            type WasmLookupCommitments = [<Wasm $field_name:camel LookupCommitments>];

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel LookupCommitments>] {
                #[wasm_bindgen(constructor)]
                pub fn new(
                    sorted: WasmVector<$WasmPolyComm>,
                    aggreg: $WasmPolyComm,
                    runtime: Option<$WasmPolyComm>) -> Self {
                    WasmLookupCommitments { sorted, aggreg, runtime }
                }

                #[wasm_bindgen(getter)]
                pub fn sorted(&self) -> WasmVector<$WasmPolyComm> {
                    self.sorted.clone()
                }

                #[wasm_bindgen(getter)]
                pub fn aggreg(&self) -> $WasmPolyComm {
                    self.aggreg.clone()
                }

                #[wasm_bindgen(getter)]
                pub fn runtime(&self) -> Option<$WasmPolyComm> {
                    self.runtime.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_sorted(&mut self, s: WasmVector<$WasmPolyComm>) {
                    self.sorted = s
                }

                #[wasm_bindgen(setter)]
                pub fn set_aggreg(&mut self, a: $WasmPolyComm) {
                    self.aggreg = a
                }

                #[wasm_bindgen(setter)]
                pub fn set_runtime(&mut self, r: Option<$WasmPolyComm>) {
                    self.runtime = r
                }
            }


            impl From<&LookupCommitments<$G>> for WasmLookupCommitments {
                fn from(x: &LookupCommitments<$G>) -> Self {
                    WasmLookupCommitments {
                        sorted: x.sorted.iter().map(Into::into).collect(),
                        aggreg: x.aggreg.clone().into(),
                        runtime: x.runtime.clone().map(Into::into)
                    }
                }
            }

            impl From<LookupCommitments<$G>> for WasmLookupCommitments {
                fn from(x: LookupCommitments<$G>) -> Self {
                    WasmLookupCommitments {
                        sorted: x.sorted.into_iter().map(Into::into).collect(),
                        aggreg: x.aggreg.into(),
                        runtime: x.runtime.map(Into::into)
                    }
                }
            }

            impl From<&WasmLookupCommitments> for LookupCommitments<$G> {
                fn from(x: &WasmLookupCommitments) -> Self {
                    LookupCommitments {
                        sorted: x.sorted.iter().map(Into::into).collect(),
                        aggreg: x.aggreg.clone().into(),
                        runtime: x.runtime.clone().map(Into::into)
                    }
                }
            }

            impl From<WasmLookupCommitments> for LookupCommitments<$G> {
                fn from(x: WasmLookupCommitments) -> Self {
                    LookupCommitments {
                        sorted: x.sorted.into_iter().map(Into::into).collect(),
                        aggreg: x.aggreg.into(),
                        runtime: x.runtime.map(Into::into)
                    }
                }
            }

            #[wasm_bindgen]
            #[derive(Clone)]
            pub struct [<Wasm $field_name:camel ProverCommitments>]
            {
                #[wasm_bindgen(skip)]
                pub w_comm: WasmVector<$WasmPolyComm>,
                #[wasm_bindgen(skip)]
                pub z_comm: $WasmPolyComm,
                #[wasm_bindgen(skip)]
                pub t_comm: $WasmPolyComm,
                #[wasm_bindgen(skip)]
                pub lookup: Option<WasmLookupCommitments>
            }
            type WasmProverCommitments = [<Wasm $field_name:camel ProverCommitments>];

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel ProverCommitments>] {
                #[wasm_bindgen(constructor)]
                pub fn new(
                    w_comm: WasmVector<$WasmPolyComm>,
                    z_comm: $WasmPolyComm,
                    t_comm: $WasmPolyComm,
                    lookup: Option<WasmLookupCommitments>
                ) -> Self {
                    WasmProverCommitments { w_comm, z_comm, t_comm, lookup }
                }

                #[wasm_bindgen(getter)]
                pub fn w_comm(&self) -> WasmVector<$WasmPolyComm> {
                    self.w_comm.clone()
                }
                #[wasm_bindgen(getter)]
                pub fn z_comm(&self) -> $WasmPolyComm {
                    self.z_comm.clone()
                }
                #[wasm_bindgen(getter)]
                pub fn t_comm(&self) -> $WasmPolyComm {
                    self.t_comm.clone()
                }

                #[wasm_bindgen(getter)]
                pub fn lookup(&self) -> Option<WasmLookupCommitments> {
                    self.lookup.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_w_comm(&mut self, x: WasmVector<$WasmPolyComm>) {
                    self.w_comm = x
                }
                #[wasm_bindgen(setter)]
                pub fn set_z_comm(&mut self, x: $WasmPolyComm) {
                    self.z_comm = x
                }
                #[wasm_bindgen(setter)]
                pub fn set_t_comm(&mut self, x: $WasmPolyComm) {
                    self.t_comm = x
                }

                #[wasm_bindgen(setter)]
                pub fn set_lookup(&mut self, l: Option<WasmLookupCommitments>) {
                    self.lookup = l
                }
            }

            impl From<&ProverCommitments<$G>> for WasmProverCommitments {
                fn from(x: &ProverCommitments<$G>) -> Self {
                    WasmProverCommitments {
                        w_comm: x.w_comm.iter().map(Into::into).collect(),
                        z_comm: x.z_comm.clone().into(),
                        t_comm: x.t_comm.clone().into(),
                        lookup: x.lookup.clone().map(Into::into),
                    }
                }
            }

            impl From<ProverCommitments<$G>> for WasmProverCommitments {
                fn from(x: ProverCommitments<$G>) -> Self {
                    WasmProverCommitments {
                        w_comm: x.w_comm.iter().map(Into::into).collect(),
                        z_comm: x.z_comm.into(),
                        t_comm: x.t_comm.into(),
                        lookup: x.lookup.map(Into::into),
                    }
                }
            }

            impl From<&WasmProverCommitments> for ProverCommitments<$G> {
                fn from(x: &WasmProverCommitments) -> Self {
                    ProverCommitments {
                        w_comm: array_init(|i| x.w_comm[i].clone().into()),
                        z_comm: x.z_comm.clone().into(),
                        t_comm: x.t_comm.clone().into(),
                        lookup: x.lookup.clone().map(Into::into),
                    }
                }
            }

            impl From<WasmProverCommitments> for ProverCommitments<$G> {
                fn from(x: WasmProverCommitments) -> Self {
                    ProverCommitments {
                        w_comm: array_init(|i| (&x.w_comm[i]).into()),
                        z_comm: x.z_comm.into(),
                        t_comm: x.t_comm.into(),
                        lookup: x.lookup.map(Into::into),
                    }
                }
            }

            #[wasm_bindgen]
            #[derive(Clone, Debug)]
            pub struct [<Wasm $field_name:camel OpeningProof>] {
                #[wasm_bindgen(skip)]
                pub lr_0: WasmVector<$WasmG>, // vector of rounds of L commitments
                #[wasm_bindgen(skip)]
                pub lr_1: WasmVector<$WasmG>, // vector of rounds of R commitments
                #[wasm_bindgen(skip)]
                pub delta: $WasmG,
                pub z1: $WasmF,
                pub z2: $WasmF,
                #[wasm_bindgen(skip)]
                pub sg: $WasmG,
            }
            type WasmOpeningProof = [<Wasm $field_name:camel OpeningProof>];

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel OpeningProof>] {
                #[wasm_bindgen(constructor)]
                pub fn new(
                    lr_0: WasmVector<$WasmG>,
                    lr_1: WasmVector<$WasmG>,
                    delta: $WasmG,
                    z1: $WasmF,
                    z2: $WasmF,
                    sg: $WasmG) -> Self {
                    WasmOpeningProof { lr_0, lr_1, delta, z1, z2, sg }
                }

                #[wasm_bindgen(getter)]
                pub fn lr_0(&self) -> WasmVector<$WasmG> {
                    self.lr_0.clone()
                }
                #[wasm_bindgen(getter)]
                pub fn lr_1(&self) -> WasmVector<$WasmG> {
                    self.lr_1.clone()
                }
                #[wasm_bindgen(getter)]
                pub fn delta(&self) -> $WasmG {
                    self.delta.clone()
                }
                #[wasm_bindgen(getter)]
                pub fn sg(&self) -> $WasmG {
                    self.sg.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_lr_0(&mut self, lr_0: WasmVector<$WasmG>) {
                    self.lr_0 = lr_0
                }
                #[wasm_bindgen(setter)]
                pub fn set_lr_1(&mut self, lr_1: WasmVector<$WasmG>) {
                    self.lr_1 = lr_1
                }
                #[wasm_bindgen(setter)]
                pub fn set_delta(&mut self, delta: $WasmG) {
                    self.delta = delta
                }
                #[wasm_bindgen(setter)]
                pub fn set_sg(&mut self, sg: $WasmG) {
                    self.sg = sg
                }
            }

            impl From<&WasmOpeningProof> for OpeningProof<$G> {
                fn from(x: &WasmOpeningProof) -> Self {
                    OpeningProof {
                        lr: x.lr_0.clone().into_iter().zip(x.lr_1.clone().into_iter()).map(|(x, y)| (x.into(), y.into())).collect(),
                        delta: x.delta.clone().into(),
                        z1: x.z1.into(),
                        z2: x.z2.into(),
                        sg: x.sg.clone().into(),
                    }
                }
            }

            impl From<WasmOpeningProof> for OpeningProof<$G> {
                fn from(x: WasmOpeningProof) -> Self {
                    let WasmOpeningProof {lr_0, lr_1, delta, z1, z2, sg} = x;
                    OpeningProof {
                        lr: lr_0.into_iter().zip(lr_1.into_iter()).map(|(x, y)| (x.into(), y.into())).collect(),
                        delta: delta.into(),
                        z1: z1.into(),
                        z2: z2.into(),
                        sg: sg.into(),
                    }
                }
            }

            impl From<&OpeningProof<$G>> for WasmOpeningProof {
                fn from(x: &OpeningProof<$G>) -> Self {
                    let (lr_0, lr_1) = x.lr.clone().into_iter().map(|(x, y)| (x.into(), y.into())).unzip();
                    WasmOpeningProof {
                        lr_0,
                        lr_1,
                        delta: x.delta.clone().into(),
                        z1: x.z1.into(),
                        z2: x.z2.into(),
                        sg: x.sg.clone().into(),
                    }
                }
            }

            impl From<OpeningProof<$G>> for WasmOpeningProof {
                fn from(x: OpeningProof<$G>) -> Self {
                    let (lr_0, lr_1) = x.lr.clone().into_iter().map(|(x, y)| (x.into(), y.into())).unzip();
                    WasmOpeningProof {
                        lr_0,
                        lr_1,
                        delta: x.delta.clone().into(),
                        z1: x.z1.into(),
                        z2: x.z2.into(),
                        sg: x.sg.clone().into(),
                    }
                }
            }

            #[wasm_bindgen]
            pub struct [<Wasm $field_name:camel ProverProof>] {
                #[wasm_bindgen(skip)]
                pub commitments: WasmProverCommitments,
                #[wasm_bindgen(skip)]
                pub proof: WasmOpeningProof,
                // OCaml doesn't have sized arrays, so we have to convert to a tuple..
                #[wasm_bindgen(skip)]
                pub evals: WasmProofEvaluations,
                pub ft_eval1: $WasmF,
                #[wasm_bindgen(skip)]
                pub public: WasmFlatVector<$WasmF>,
                #[wasm_bindgen(skip)]
                pub prev_challenges_scalars: Vec<Vec<$F>>,
                #[wasm_bindgen(skip)]
                pub prev_challenges_comms: WasmVector<$WasmPolyComm>,
            }
            type WasmProverProof = [<Wasm $field_name:camel ProverProof>];

            impl From<(&ProverProof<$G>, &Vec<$F>)> for WasmProverProof {
                fn from((x, public): (&ProverProof<$G>, &Vec<$F>)) -> Self {
                    let (scalars, comms) =
                        x.prev_challenges
                            .iter()
                            .map(|RecursionChallenge { chals, comm }| {
                                    (chals.clone().into(), comm.into())
                                })
                            .unzip();
                    WasmProverProof {
                        commitments: x.commitments.clone().into(),
                        proof: x.proof.clone().into(),
                        evals: x.evals.clone().into(),
                        ft_eval1: x.ft_eval1.clone().into(),
                        public: public.clone().into_iter().map(Into::into).collect(),
                        prev_challenges_scalars: scalars,
                        prev_challenges_comms: comms,
                    }
                }
            }

            impl From<(ProverProof<$G>, Vec<$F>)> for WasmProverProof {
                fn from((x, public): (ProverProof<$G>, Vec<$F>)) -> Self {
                    let ProverProof {ft_eval1, commitments, proof, evals , prev_challenges} = x;
                    let (scalars, comms) =
                        prev_challenges
                            .into_iter()
                            .map(|RecursionChallenge { chals, comm }| (chals.into(), comm.into()))
                            .unzip();
                    WasmProverProof {
                        commitments: commitments.into(),
                        proof: proof.into(),
                        evals: evals.into(),
                        ft_eval1: ft_eval1.clone().into(),
                        public: public.into_iter().map(Into::into).collect(),
                        prev_challenges_scalars: scalars,
                        prev_challenges_comms: comms,
                    }
                }
            }

            impl From<&WasmProverProof> for (ProverProof<$G>, Vec<$F>) {
                fn from(x: &WasmProverProof) -> Self {
                    let proof = ProverProof {
                        commitments: x.commitments.clone().into(),
                        proof: x.proof.clone().into(),
                        evals: x.evals.clone().into(),
                        prev_challenges:
                            (&x.prev_challenges_scalars)
                                .into_iter()
                                .zip((&x.prev_challenges_comms).into_iter())
                                .map(|(chals, comm)| {
                                    RecursionChallenge {
                                        chals: chals.clone(),
                                        comm: comm.into(),
                                    }
                                })
                                .collect(),
                        ft_eval1: x.ft_eval1.clone().into()
                    };
                    let public = x.public.clone().into_iter().map(Into::into).collect();
                    (proof, public)
                }
            }

            impl From<WasmProverProof> for (ProverProof<$G>, Vec<$F>) {
                fn from(x: WasmProverProof) -> Self {
                    let proof =ProverProof {
                        commitments: x.commitments.into(),
                        proof: x.proof.into(),
                        evals: x.evals.into(),
                        prev_challenges:
                            (x.prev_challenges_scalars)
                                .into_iter()
                                .zip((x.prev_challenges_comms).into_iter())
                                .map(|(chals, comm)| {
                                    RecursionChallenge {
                                        chals: chals.into(),
                                        comm: comm.into(),
                                    }
                                })
                                .collect(),
                        ft_eval1: x.ft_eval1.into()
                    };
                    let public = x.public.into_iter().map(Into::into).collect();
                    (proof, public)
                }
            }

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel ProverProof>] {
                #[wasm_bindgen(constructor)]
                pub fn new(
                    commitments: WasmProverCommitments,
                    proof: WasmOpeningProof,
                    evals: WasmProofEvaluations,
                    ft_eval1: $WasmF,
                    public_: WasmFlatVector<$WasmF>,
                    prev_challenges_scalars: WasmVecVecF,
                    prev_challenges_comms: WasmVector<$WasmPolyComm>) -> Self {
                    WasmProverProof {
                        commitments,
                        proof,
                        evals,
                        ft_eval1,
                        public: public_,
                        prev_challenges_scalars: prev_challenges_scalars.0,
                        prev_challenges_comms,
                    }
                }

                #[wasm_bindgen(getter)]
                pub fn commitments(&self) -> WasmProverCommitments {
                    self.commitments.clone()
                }
                #[wasm_bindgen(getter)]
                pub fn proof(&self) -> WasmOpeningProof {
                    self.proof.clone()
                }
                #[wasm_bindgen(getter)]
                pub fn evals(&self) -> WasmProofEvaluations {
                    self.evals.clone()
                }
                #[wasm_bindgen(getter)]
                pub fn public_(&self) -> WasmFlatVector<$WasmF> {
                    self.public.clone()
                }
                #[wasm_bindgen(getter)]
                pub fn prev_challenges_scalars(&self) -> WasmVecVecF {
                    [<WasmVecVec $field_name:camel>](self.prev_challenges_scalars.clone())
                }
                #[wasm_bindgen(getter)]
                pub fn prev_challenges_comms(&self) -> WasmVector<$WasmPolyComm> {
                    self.prev_challenges_comms.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_commitments(&mut self, commitments: WasmProverCommitments) {
                    self.commitments = commitments
                }
                #[wasm_bindgen(setter)]
                pub fn set_proof(&mut self, proof: WasmOpeningProof) {
                    self.proof = proof
                }
                #[wasm_bindgen(setter)]
                pub fn set_evals(&mut self, evals: WasmProofEvaluations) {
                    self.evals = evals
                }
                #[wasm_bindgen(setter)]
                pub fn set_public_(&mut self, public_: WasmFlatVector<$WasmF>) {
                    self.public = public_
                }
                #[wasm_bindgen(setter)]
                pub fn set_prev_challenges_scalars(&mut self, prev_challenges_scalars: WasmVecVecF) {
                    self.prev_challenges_scalars = prev_challenges_scalars.0
                }
                #[wasm_bindgen(setter)]
                pub fn set_prev_challenges_comms(&mut self, prev_challenges_comms: WasmVector<$WasmPolyComm>) {
                    self.prev_challenges_comms = prev_challenges_comms
                }

                #[wasm_bindgen]
                pub fn serialize(&self) -> String {
                    let (proof, _public_input) = self.into();
                    let serialized = rmp_serde::to_vec(&proof).unwrap();
                    base64::encode(serialized)
                }
            }

            #[wasm_bindgen]
            pub fn [<$name:snake _create>](
                index: &$WasmIndex,
                witness: WasmVecVecF,
                prev_challenges: WasmFlatVector<$WasmF>,
                prev_sgs: WasmVector<$WasmG>,
            ) -> Result<WasmProverProof, JsError> {
                console_error_panic_hook::set_once();
                let (maybe_proof, public_input) = crate::rayon::run_in_pool(|| {
                    {
                        let ptr: &mut poly_commitment::srs::SRS<$G> =
                            unsafe { &mut *(std::sync::Arc::as_ptr(&index.0.as_ref().srs) as *mut _) };
                        ptr.add_lagrange_basis(index.0.as_ref().cs.domain.d1);
                    }
                    let prev: Vec<RecursionChallenge<$G>> = {
                        if prev_challenges.is_empty() {
                            Vec::new()
                        } else {
                            let challenges_per_sg = prev_challenges.len() / prev_sgs.len();
                            prev_sgs
                                .into_iter()
                                .map(Into::<$G>::into)
                                .enumerate()
                                .map(|(i, sg)| {
                                    let chals =
                                        prev_challenges[(i * challenges_per_sg)..(i + 1) * challenges_per_sg]
                                            .iter()
                                            .map(|a| a.clone().into())
                                            .collect();
                                    let comm = PolyComm::<$G> {
                                        unshifted: vec![sg],
                                        shifted: None,
                                    };
                                    RecursionChallenge { chals, comm }
                                })
                                .collect()
                        }
                    };

                    let witness: [Vec<_>; COLUMNS] = witness.0
                        .try_into()
                        .expect("the witness should be a column of 15 vectors");

                    let index: &ProverIndex<$G> = &index.0.as_ref();

                    let public_input = witness[0][0..index.cs.public].to_vec();

                    // Release the runtime lock so that other threads can run using it while we generate the proof.
                    let group_map = GroupMap::<_>::setup();
                    let maybe_proof = ProverProof::create_recursive::<
                        DefaultFqSponge<_, PlonkSpongeConstantsKimchi>,
                        DefaultFrSponge<_, PlonkSpongeConstantsKimchi>,
                        >(&group_map, witness, &[], index, prev, None);
                    (maybe_proof, public_input)
                });

                return match maybe_proof {
                    Ok(proof) => Ok((proof, public_input).into()),
                    Err(err) => Err(JsError::from(err))
                }
            }

            #[wasm_bindgen]
            pub fn [<$name:snake _verify>](
                index: $WasmVerifierIndex,
                proof: WasmProverProof,
            ) -> bool {
                crate::rayon::run_in_pool(|| {
                    let group_map = <$G as CommitmentCurve>::Map::setup();
                    let verifier_index = &index.into();
                    let (proof, public_input) = &proof.into();
                    batch_verify::<
                        $G,
                        DefaultFqSponge<_, PlonkSpongeConstantsKimchi>,
                        DefaultFrSponge<_, PlonkSpongeConstantsKimchi>,
                    >(
                        &group_map,
                        &[Context { verifier_index, proof, public_input }]
                    ).is_ok()
                })
            }

            #[wasm_bindgen]
            pub struct [<WasmVecVec $field_name:camel PolyComm>](Vec<Vec<PolyComm<$G>>>);

            #[wasm_bindgen]
            impl [<WasmVecVec $field_name:camel PolyComm>] {
                #[wasm_bindgen(constructor)]
                pub fn create(n: i32) -> Self {
                    [<WasmVecVec $field_name:camel PolyComm>](Vec::with_capacity(n as usize))
                }

                #[wasm_bindgen]
                pub fn push(&mut self, x: WasmVector<$WasmPolyComm>) {
                    self.0.push(x.into_iter().map(Into::into).collect())
                }
            }

            #[wasm_bindgen]
            pub fn [<$name:snake _batch_verify>](
                indexes: WasmVector<$WasmVerifierIndex>,
                proofs: WasmVector<WasmProverProof>,
            ) -> bool {
                crate::rayon::run_in_pool(|| {
                    let ts: Vec<_> = indexes
                        .into_iter()
                        .zip(proofs.into_iter())
                        .map(|(index, proof)| (index.into(), proof.into()))
                        .collect();
                    let ts: Vec<_> = ts.iter().map(|(verifier_index, (proof, public_input))| Context { verifier_index, proof, public_input}).collect();
                    let group_map = GroupMap::<_>::setup();

                    batch_verify::<
                        $G,
                        DefaultFqSponge<_, PlonkSpongeConstantsKimchi>,
                        DefaultFrSponge<_, PlonkSpongeConstantsKimchi>,
                    >(&group_map, &ts)
                    .is_ok()
                })
            }

            #[wasm_bindgen]
            pub fn [<$name:snake _dummy>]() -> WasmProverProof {
                fn comm() -> PolyComm<$G> {
                    let g = $G::prime_subgroup_generator();
                    PolyComm {
                        shifted: Some(g),
                        unshifted: vec![g, g, g],
                    }
                }

                let prev = RecursionChallenge {
                    chals: vec![$F::one(), $F::one()],
                    comm: comm(),
                };
                let prev_challenges = vec![prev.clone(), prev.clone(), prev.clone()];

                let g = $G::prime_subgroup_generator();
                let proof = OpeningProof {
                    lr: vec![(g, g), (g, g), (g, g)],
                    z1: $F::one(),
                    z2: $F::one(),
                    delta: g,
                    sg: g,
                };
                let eval = || PointEvaluations {
                    zeta: vec![$F::one()],
                    zeta_omega: vec![$F::one()],
                };
                let evals = ProofEvaluations {
                    w: array_init(|_| eval()),
                    coefficients: array_init(|_| eval()),
                    z: eval(),
                    s: array_init(|_| eval()),
                    generic_selector: eval(),
                    poseidon_selector: eval(),
                    complete_add_selector: eval(),
                    mul_selector: eval(),
                    emul_selector: eval(),
                    endomul_scalar_selector: eval(),
                    range_check0_selector: None,
                    range_check1_selector: None,
                    foreign_field_add_selector: None,
                    foreign_field_mul_selector: None,
                    xor_selector: None,
                    rot_selector: None,
                    lookup_aggregation: None,
                    lookup_table: None,
                    lookup_sorted: array::from_fn(|_| None),
                    runtime_lookup_table: None,
                    runtime_lookup_table_selector: None,
                    xor_lookup_selector: None,
                    lookup_gate_lookup_selector: None,
                    range_check_lookup_selector: None,
                    foreign_field_mul_lookup_selector: None,
                };

                let dlogproof = ProverProof {
                    commitments: ProverCommitments {
                        w_comm: array_init(|_| comm()),
                        z_comm: comm(),
                        t_comm: comm(),
                        lookup: None,
                    },
                    proof,
                    evals,
                    ft_eval1: $F::one(),
                    prev_challenges,
                };

                let public = vec![$F::one(), $F::one()];
                (dlogproof, public).into()
            }

            #[wasm_bindgen]
            pub fn [<$name:snake _deep_copy>](
                x: WasmProverProof
            ) -> WasmProverProof {
                x
            }
        }
    }
}

pub mod fp {
    use super::*;
    use crate::arkworks::{WasmGVesta, WasmPastaFp};
    use crate::pasta_fp_plonk_index::WasmPastaFpPlonkIndex;
    use crate::plonk_verifier_index::fp::WasmFpPlonkVerifierIndex as WasmPlonkVerifierIndex;
    use crate::poly_comm::vesta::WasmFpPolyComm as WasmPolyComm;
    use mina_curves::pasta::{Fp, Vesta as GAffine};

    impl_proof!(
        caml_pasta_fp_plonk_proof,
        WasmGVesta,
        GAffine,
        WasmPastaFp,
        Fp,
        WasmPolyComm,
        WasmSrs,
        GAffineOther,
        mina_poseidon::pasta::fp_kimchi,
        mina_poseidon::pasta::fq_kimchi,
        WasmPastaFpPlonkIndex,
        WasmPlonkVerifierIndex,
        Fp
    );
}

pub mod fq {
    use super::*;
    use crate::arkworks::{WasmGPallas, WasmPastaFq};
    use crate::pasta_fq_plonk_index::WasmPastaFqPlonkIndex;
    use crate::plonk_verifier_index::fq::WasmFqPlonkVerifierIndex as WasmPlonkVerifierIndex;
    use crate::poly_comm::pallas::WasmFqPolyComm as WasmPolyComm;
    use mina_curves::pasta::{Fq, Pallas as GAffine};

    impl_proof!(
        caml_pasta_fq_plonk_proof,
        WasmGPallas,
        GAffine,
        WasmPastaFq,
        Fq,
        WasmPolyComm,
        WasmSrs,
        GAffineOther,
        mina_poseidon::pasta::fq_kimchi,
        mina_poseidon::pasta::fp_kimchi,
        WasmPastaFqPlonkIndex,
        WasmPlonkVerifierIndex,
        Fq
    );
}
