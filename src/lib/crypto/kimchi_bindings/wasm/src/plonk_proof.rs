// use kimchi::circuits::expr::{Linearization, PolishToken, Variable, Column};
// use kimchi::circuits::gate::{GateType, CurrOrNext};
use crate::wasm_flat_vector::WasmFlatVector;
use crate::wasm_vector::WasmVector;
use paste::paste;
use std::convert::TryInto;
use wasm_bindgen::prelude::*;
// use std::sync::Arc;
// use commitment_dlog::srs::SRS;
// use kimchi::index::{expr_linearization, VerifierIndex as DlogVerifierIndex};
// use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use ark_ec::AffineCurve;
use ark_ff::One;
use array_init::array_init;
use kimchi::circuits::{
    scalars::ProofEvaluations,
    // nolookup::constraints::{zk_polynomial, zk_w3, Shifts},
    wires::COLUMNS,
};
// use std::path::Path;
use commitment_dlog::commitment::{CommitmentCurve, OpeningProof, PolyComm};
use groupmap::GroupMap;
use kimchi::index::Index;
use kimchi::prover::{ProverCommitments, ProverProof};
use oracle::{
    poseidon::PlonkSpongeConstants15W,
    sponge::{DefaultFqSponge, DefaultFrSponge},
};

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

            #[wasm_bindgen]
            #[derive(Clone)]
            pub struct [<Wasm $field_name:camel ProofEvaluations>] {
                #[wasm_bindgen(skip)]
                pub w: Vec<Vec<$F>>,
                #[wasm_bindgen(skip)]
                pub z: WasmFlatVector<$WasmF>,
                #[wasm_bindgen(skip)]
                pub s: Vec<Vec<$F>>,
                #[wasm_bindgen(skip)]
                pub generic_selector: WasmFlatVector<$WasmF>,
                #[wasm_bindgen(skip)]
                pub poseidon_selector: WasmFlatVector<$WasmF>,
                // TODO: Lookup
            }
            type WasmProofEvaluations = [<Wasm $field_name:camel ProofEvaluations>];

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel ProofEvaluations>] {
                #[wasm_bindgen(constructor)]
                pub fn new(
                    w: WasmVecVecF,
                    z: WasmFlatVector<$WasmF>,
                    s: WasmVecVecF,
                    generic_selector: WasmFlatVector<$WasmF>,
                    poseidon_selector: WasmFlatVector<$WasmF>) -> Self {
                    WasmProofEvaluations { w: w.0, z, s: s.0, generic_selector, poseidon_selector }
                }

                #[wasm_bindgen(getter)]
                pub fn w(&self) -> WasmVecVecF {
                    [<WasmVecVec $field_name:camel>](self.w.clone())
                }

                #[wasm_bindgen(getter)]
                pub fn z(&self) -> WasmFlatVector<$WasmF> {
                    self.z.clone()
                }

                #[wasm_bindgen(getter)]
                pub fn s(&self) -> WasmVecVecF {
                    [<WasmVecVec $field_name:camel>](self.s.clone())
                }

                #[wasm_bindgen(getter)]
                pub fn generic_selector(&self) -> WasmFlatVector<$WasmF> {
                    self.generic_selector.clone()
                }

                #[wasm_bindgen(getter)]
                pub fn poseidon_selector(&self) -> WasmFlatVector<$WasmF> {
                    self.poseidon_selector.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_w(&mut self, x: WasmVecVecF) {
                    self.w = x.0
                }
                #[wasm_bindgen(setter)]
                pub fn set_s(&mut self, x: WasmVecVecF) {
                    self.s = x.0
                }
                #[wasm_bindgen(setter)]
                pub fn set_z(&mut self, x: WasmFlatVector<$WasmF>) {
                    self.z = x
                }
                #[wasm_bindgen(setter)]
                pub fn set_generic_selector(&mut self, x: WasmFlatVector<$WasmF>) {
                    self.generic_selector = x
                }
                #[wasm_bindgen(setter)]
                pub fn set_poseidon_selector(&mut self, x: WasmFlatVector<$WasmF>) {
                    self.poseidon_selector = x
                }
            }

            impl From<&WasmProofEvaluations> for ProofEvaluations<Vec<$F>> {
                fn from(x: &WasmProofEvaluations) -> Self {
                    ProofEvaluations {
                        w: array_init(|i| x.w[i].clone()),
                        s: array_init(|i| x.s[i].clone()),
                        z: x.z.iter().map(|a| a.clone().into()).collect(),
                        generic_selector: x.generic_selector.iter().map(|a| a.clone().into()).collect(),
                        poseidon_selector: x.poseidon_selector.iter().map(|a| a.clone().into()).collect(),
                        // TODO
                        lookup: None
                    }
                }
            }

            impl From<WasmProofEvaluations> for ProofEvaluations<Vec<$F>> {
                fn from(x: WasmProofEvaluations) -> Self {
                    ProofEvaluations {
                        w: array_init(|i| x.w[i].clone()),
                        s: array_init(|i| x.s[i].clone()),
                        z: x.z.into_iter().map(Into::into).collect(),
                        generic_selector: x.generic_selector.into_iter().map(Into::into).collect(),
                        poseidon_selector: x.poseidon_selector.into_iter().map(Into::into).collect(),
                        // TODO
                        lookup: None
                    }
                }
            }

            impl From<&ProofEvaluations<Vec<$F>>> for WasmProofEvaluations {
                fn from(x: &ProofEvaluations<Vec<$F>>) -> Self {
                    WasmProofEvaluations {
                        w: x.w.to_vec(),
                        s: x.s.to_vec(),
                        z: x.z.iter().map(|a| a.clone().into()).collect(),
                        generic_selector: x.generic_selector.iter().map(|a| a.clone().into()).collect(),
                        poseidon_selector: x.poseidon_selector.iter().map(|a| a.clone().into()).collect(),
                    }
                }
            }

            impl From<ProofEvaluations<Vec<$F>>> for WasmProofEvaluations {
                fn from(x: ProofEvaluations<Vec<$F>>) -> Self {
                    WasmProofEvaluations {
                        w: x.w.to_vec(),
                        s: x.s.to_vec(),
                        z: x.z.into_iter().map(Into::into).collect(),
                        generic_selector: x.generic_selector.into_iter().map(Into::into).collect(),
                        poseidon_selector: x.poseidon_selector.into_iter().map(Into::into).collect(),
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
                /* TODO
                #[wasm_bindgen(skip)]
                pub lookup: Option<LookupCommitments<G>>,
                */
            }
            type WasmProverCommitments = [<Wasm $field_name:camel ProverCommitments>];

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel ProverCommitments>] {
                #[wasm_bindgen(constructor)]
                pub fn new(
                    w_comm: WasmVector<$WasmPolyComm>,
                    z_comm: $WasmPolyComm,
                    t_comm: $WasmPolyComm) -> Self {
                    WasmProverCommitments { w_comm, z_comm, t_comm }
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
            }

            impl From<&ProverCommitments<GAffine>> for WasmProverCommitments {
                fn from(x: &ProverCommitments<GAffine>) -> Self {
                    WasmProverCommitments {
                        w_comm: x.w_comm.iter().map(Into::into).collect(),
                        z_comm: x.z_comm.clone().into(),
                        t_comm: x.t_comm.clone().into(),
                    }
                }
            }

            impl From<ProverCommitments<GAffine>> for WasmProverCommitments {
                fn from(x: ProverCommitments<GAffine>) -> Self {
                    WasmProverCommitments {
                        w_comm: x.w_comm.iter().map(Into::into).collect(),
                        z_comm: x.z_comm.into(),
                        t_comm: x.t_comm.into(),
                    }
                }
            }

            impl From<&WasmProverCommitments> for ProverCommitments<GAffine> {
                fn from(x: &WasmProverCommitments) -> Self {
                    ProverCommitments {
                        w_comm: array_init(|i| x.w_comm[i].clone().into()),
                        z_comm: x.z_comm.clone().into(),
                        t_comm: x.t_comm.clone().into(),
                        // TODO
                        lookup: None,
                    }
                }
            }

            impl From<WasmProverCommitments> for ProverCommitments<GAffine> {
                fn from(x: WasmProverCommitments) -> Self {
                    ProverCommitments {
                        w_comm: array_init(|i| (&x.w_comm[i]).into()),
                        z_comm: x.z_comm.into(),
                        t_comm: x.t_comm.into(),
                        // TODO
                        lookup: None,
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
                pub evals0: WasmProofEvaluations,
                #[wasm_bindgen(skip)]
                pub evals1: WasmProofEvaluations,
                pub ft_eval1: $WasmF,
                #[wasm_bindgen(skip)]
                pub public: WasmFlatVector<$WasmF>,
                #[wasm_bindgen(skip)]
                pub prev_challenges_scalars: Vec<Vec<$F>>,
                #[wasm_bindgen(skip)]
                pub prev_challenges_comms: WasmVector<$WasmPolyComm>,
            }
            type WasmProverProof = [<Wasm $field_name:camel ProverProof>];

            impl From<&ProverProof<$G>> for WasmProverProof {
                fn from(x: &ProverProof<$G>) -> Self {
                    let (scalars, comms) = x.prev_challenges.iter().map(|(x, y)| (x.clone().into(), y.into())).unzip();
                    WasmProverProof {
                        commitments: x.commitments.clone().into(),
                        proof: x.proof.clone().into(),
                        evals0: x.evals[0].clone().into(),
                        evals1: x.evals[1].clone().into(),
                        ft_eval1: x.ft_eval1.clone().into(),
                        public: x.public.clone().into_iter().map(Into::into).collect(),
                        prev_challenges_scalars: scalars,
                        prev_challenges_comms: comms,
                    }
                }
            }

            impl From<ProverProof<$G>> for WasmProverProof {
                fn from(x: ProverProof<$G>) -> Self {
                    let ProverProof {ft_eval1, commitments, proof, evals: [evals0, evals1], public, prev_challenges} = x;
                    let (scalars, comms) = prev_challenges.into_iter().map(|(x, y)| (x.into(), y.into())).unzip();
                    WasmProverProof {
                        commitments: commitments.into(),
                        proof: proof.into(),
                        evals0: evals0.into(),
                        evals1: evals1.into(),
                        ft_eval1: ft_eval1.clone().into(),
                        public: public.into_iter().map(Into::into).collect(),
                        prev_challenges_scalars: scalars,
                        prev_challenges_comms: comms,
                    }
                }
            }

            impl From<&WasmProverProof> for ProverProof<$G> {
                fn from(x: &WasmProverProof) -> Self {
                    ProverProof {
                        commitments: x.commitments.clone().into(),
                        proof: x.proof.clone().into(),
                        evals: [x.evals0.clone().into(), x.evals1.clone().into()],
                        public: x.public.clone().into_iter().map(Into::into).collect(),
                        prev_challenges: (&x.prev_challenges_scalars).into_iter().zip((&x.prev_challenges_comms).into_iter()).map(|(x, y)| { (x.clone().into(), y.into()) }).collect(),
                        ft_eval1: x.ft_eval1.clone().into()
                    }
                }
            }

            impl From<WasmProverProof> for ProverProof<$G> {
                fn from(x: WasmProverProof) -> Self {
                    ProverProof {
                        commitments: x.commitments.into(),
                        proof: x.proof.into(),
                        evals: [x.evals0.into(), x.evals1.into()],
                        public: x.public.into_iter().map(Into::into).collect(),
                        prev_challenges: (x.prev_challenges_scalars).into_iter().zip((x.prev_challenges_comms).into_iter()).map(|(x, y)| { (x.into(), y.into()) }).collect(),
                        ft_eval1: x.ft_eval1.into()
                    }
                }
            }

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel ProverProof>] {
                #[wasm_bindgen(constructor)]
                pub fn new(
                    commitments: WasmProverCommitments,
                    proof: WasmOpeningProof,
                    evals0: WasmProofEvaluations,
                    evals1: WasmProofEvaluations,
                    ft_eval1: $WasmF,
                    public_: WasmFlatVector<$WasmF>,
                    prev_challenges_scalars: WasmVecVecF,
                    prev_challenges_comms: WasmVector<$WasmPolyComm>) -> Self {
                    WasmProverProof {
                        commitments,
                        proof,
                        evals0,
                        evals1,
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
                pub fn evals0(&self) -> WasmProofEvaluations {
                    self.evals0.clone()
                }
                #[wasm_bindgen(getter)]
                pub fn evals1(&self) -> WasmProofEvaluations {
                    self.evals1.clone()
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
                pub fn set_evals0(&mut self, evals0: WasmProofEvaluations) {
                    self.evals0 = evals0
                }
                #[wasm_bindgen(setter)]
                pub fn set_evals1(&mut self, evals1: WasmProofEvaluations) {
                    self.evals1 = evals1
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
            }

            #[wasm_bindgen]
            pub fn [<$name:snake _create>](
                index: &$WasmIndex,
                witness: WasmVecVecF,
                prev_challenges: WasmFlatVector<$WasmF>,
                prev_sgs: WasmVector<$WasmG>,
            ) -> WasmProverProof {
                {
                    let ptr: &mut commitment_dlog::srs::SRS<GAffine> =
                        unsafe { &mut *(std::sync::Arc::as_ptr(&index.0.as_ref().srs) as *mut _) };
                    ptr.add_lagrange_basis(index.0.as_ref().cs.domain.d1);
                }
                let prev: Vec<(Vec<$F>, PolyComm<GAffine>)> = {
                    if prev_challenges.is_empty() {
                        Vec::new()
                    } else {
                        let challenges_per_sg = prev_challenges.len() / prev_sgs.len();
                        prev_sgs
                            .into_iter()
                            .map(Into::<GAffine>::into)
                            .enumerate()
                            .map(|(i, sg)| {
                                (
                                    prev_challenges[(i * challenges_per_sg)..(i + 1) * challenges_per_sg]
                                        .iter()
                                        .map(|a| a.clone().into())
                                        .collect(),
                                    PolyComm::<GAffine> {
                                        unshifted: vec![sg],
                                        shifted: None,
                                    },
                                )
                            })
                            .collect()
                    }
                };

                let witness: [Vec<_>; COLUMNS] = witness.0
                    .try_into()
                    .expect("the witness should be a column of 15 vectors");

                let index: &Index<$G> = &index.0.as_ref();


                // let mut vec = index.linearization.index_terms.iter().map(|i| format!("{:?}", i)).collect::<Vec<_>>();
                // vec.sort_by(|s, t| s.cmp(&t));
                // console_log(&format!("{:?}", vec));

                // print witness
                // for (i, w) in witness.iter().enumerate() {
                //     let st = w.iter().map(|f| format!("{}", f)).collect::<Vec<_>>().join("\n");
                //     console_log(&format!("witness {}\n{}\n", i, st));
                // }

                // verify witness
                // this seems to throw in general
                // console_log(&"verifying witness!");
                // index.cs.verify(&witness).expect("incorrect witness");
                // console_log(&"verifying witness ok");

                // Release the runtime lock so that other threads can run using it while we generate the proof.
                let group_map = GroupMap::<_>::setup();
                let maybe_proof = ProverProof::create::<
                    DefaultFqSponge<_, PlonkSpongeConstants15W>,
                    DefaultFrSponge<_, PlonkSpongeConstants15W>,
                >(&group_map, witness, index, prev);
                return match maybe_proof {
                    Ok(proof) => proof.into(),
                    Err(err) => {
                        log(&err.to_string());
                        panic!("thrown an error")
                    }
                }
            }

            #[wasm_bindgen]
            pub fn [<$name:snake _verify>](
                lgr_comm: WasmVector<$WasmPolyComm>,
                index: $WasmVerifierIndex,
                proof: WasmProverProof,
            ) -> bool {
                let lgr_comm = lgr_comm.into_iter().map(|x| x.into()).collect();

                let group_map = <$G as CommitmentCurve>::Map::setup();

                ProverProof::verify::<
                    DefaultFqSponge<_, PlonkSpongeConstants15W>,
                    DefaultFrSponge<_, PlonkSpongeConstants15W>,
                >(
                    &group_map,
                    &[(&index.into(), &lgr_comm, &proof.into())].to_vec(),
                )
                .is_ok()
            }

            #[wasm_bindgen]
            pub struct [<WasmVecVec $field_name:camel PolyComm>](Vec<Vec<PolyComm<$G>>>);
            type WasmVecVecPolyComm = [<WasmVecVec $field_name:camel PolyComm>];

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
                lgr_comms: WasmVecVecPolyComm,
                indexes: WasmVector<$WasmVerifierIndex>,
                proofs: WasmVector<WasmProverProof>,
            ) -> bool {
                let ts: Vec<_> = indexes
                    .into_iter()
                    .zip(lgr_comms.0.into_iter())
                    .zip(proofs.into_iter())
                    .map(|((i, l), p)| (i.into(), l.into_iter().map(Into::into).collect(), p.into()))
                    .collect();
                let ts: Vec<_> = ts.iter().map(|(i, l, p)| (i, l, p)).collect();
                let group_map = GroupMap::<_>::setup();

                ProverProof::<$G>::verify::<
                    DefaultFqSponge<_, PlonkSpongeConstants15W>,
                    DefaultFrSponge<_, PlonkSpongeConstants15W>,
                >(&group_map, &ts)
                .is_ok()
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

                let prev_challenges = vec![
                    (vec![$F::one(), $F::one()], comm()),
                    (vec![$F::one(), $F::one()], comm()),
                    (vec![$F::one(), $F::one()], comm()),
                ];

                let g = $G::prime_subgroup_generator();
                let proof = OpeningProof {
                    lr: vec![(g, g), (g, g), (g, g)],
                    z1: $F::one(),
                    z2: $F::one(),
                    delta: g,
                    sg: g,
                };
                let proof_evals = ProofEvaluations {
                    w: array_init(|_| vec![$F::one()]),
                    z: vec![$F::one()],
                    s: array_init(|_| vec![$F::one()]),
                    lookup: None,
                    generic_selector: vec![$F::one()],
                    poseidon_selector: vec![$F::one()],
                };
                let evals = [proof_evals.clone(), proof_evals];

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
                    public: vec![$F::one(), $F::one()],
                    prev_challenges,
                };

                dlogproof.into()
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
    use crate::srs::fp::WasmFpSrs as WasmSrs;
    use mina_curves::pasta::{fp::Fp, pallas::Affine as GAffineOther, vesta::Affine as GAffine};

    impl_proof!(
        caml_pasta_fp_plonk_proof,
        WasmGVesta,
        GAffine,
        WasmPastaFp,
        Fp,
        WasmPolyComm,
        WasmSrs,
        GAffineOther,
        oracle::pasta::fp_3,
        oracle::pasta::fq_3,
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
    use crate::srs::fq::WasmFqSrs as WasmSrs;
    use mina_curves::pasta::{fq::Fq, pallas::Affine as GAffine, vesta::Affine as GAffineOther};

    impl_proof!(
        caml_pasta_fq_plonk_proof,
        WasmGPallas,
        GAffine,
        WasmPastaFq,
        Fq,
        WasmPolyComm,
        WasmSrs,
        GAffineOther,
        oracle::pasta::fq_3,
        oracle::pasta::fp_3,
        WasmPastaFqPlonkIndex,
        WasmPlonkVerifierIndex,
        Fq
    );
}
