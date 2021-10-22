use wasm_bindgen::prelude::*;
use wasm_bindgen::JsValue;
use mina_curves::pasta::{
        pallas::{Affine as GAffine, PallasParameters},
        fq::Fq,
        fp::Fp,
};
use algebra::{
    curves::AffineCurve,
    One,
};

use plonk_circuits::scalars::ProofEvaluations as DlogProofEvaluations;

use oracle::{
    poseidon::PlonkSpongeConstants,
    sponge::{DefaultFqSponge, DefaultFrSponge},
};

use groupmap::GroupMap;

use commitment_dlog::commitment::{CommitmentCurve, OpeningProof, PolyComm};
use plonk_protocol_dlog::index::{Index as DlogIndex};
use plonk_protocol_dlog::prover::{ProverCommitments as DlogCommitments, ProverProof as DlogProof};

use crate::pasta_fq::WasmPastaFq;
use crate::pasta_fq_plonk_index::WasmPastaFqPlonkIndex;
use crate::pasta_fq_plonk_verifier_index::WasmPastaFqPlonkVerifierIndex;
use crate::wasm_flat_vector::WasmFlatVector;
use crate::wasm_vector::WasmVector;
use crate::pasta_pallas::WasmPallasGAffine;
use crate::pasta_pallas_poly_comm::WasmPastaPallasPolyComm;

#[wasm_bindgen]
#[derive(Clone)]
pub struct WasmPastaFqProofEvaluations {
    #[wasm_bindgen(skip)]
    pub l: WasmFlatVector<WasmPastaFq>,
    #[wasm_bindgen(skip)]
    pub r: WasmFlatVector<WasmPastaFq>,
    #[wasm_bindgen(skip)]
    pub o: WasmFlatVector<WasmPastaFq>,
    #[wasm_bindgen(skip)]
    pub z: WasmFlatVector<WasmPastaFq>,
    #[wasm_bindgen(skip)]
    pub t: WasmFlatVector<WasmPastaFq>,
    #[wasm_bindgen(skip)]
    pub f: WasmFlatVector<WasmPastaFq>,
    #[wasm_bindgen(skip)]
    pub sigma1: WasmFlatVector<WasmPastaFq>,
    #[wasm_bindgen(skip)]
    pub sigma2: WasmFlatVector<WasmPastaFq>,
}

#[wasm_bindgen]
impl WasmPastaFqProofEvaluations {
    #[wasm_bindgen(constructor)]
    pub fn new(
        l: WasmFlatVector<WasmPastaFq>,
        r: WasmFlatVector<WasmPastaFq>,
        o: WasmFlatVector<WasmPastaFq>,
        z: WasmFlatVector<WasmPastaFq>,
        t: WasmFlatVector<WasmPastaFq>,
        f: WasmFlatVector<WasmPastaFq>,
        sigma1: WasmFlatVector<WasmPastaFq>,
        sigma2: WasmFlatVector<WasmPastaFq>) -> Self {
        WasmPastaFqProofEvaluations { l, r, o, z, t, f, sigma1, sigma2 }
    }

    #[wasm_bindgen(getter)]
    pub fn l(&self) -> WasmFlatVector<WasmPastaFq> {
        self.l.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn r(&self) -> WasmFlatVector<WasmPastaFq> {
        self.r.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn o(&self) -> WasmFlatVector<WasmPastaFq> {
        self.o.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn z(&self) -> WasmFlatVector<WasmPastaFq> {
        self.z.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn t(&self) -> WasmFlatVector<WasmPastaFq> {
        self.t.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn f(&self) -> WasmFlatVector<WasmPastaFq> {
        self.f.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn sigma1(&self) -> WasmFlatVector<WasmPastaFq> {
        self.sigma1.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn sigma2(&self) -> WasmFlatVector<WasmPastaFq> {
        self.sigma2.clone()
    }

    #[wasm_bindgen(setter)]
    pub fn set_l(&mut self, x: WasmFlatVector<WasmPastaFq>) {
        self.l = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_r(&mut self, x: WasmFlatVector<WasmPastaFq>) {
        self.r = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_o(&mut self, x: WasmFlatVector<WasmPastaFq>) {
        self.o = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_z(&mut self, x: WasmFlatVector<WasmPastaFq>) {
        self.z = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_t(&mut self, x: WasmFlatVector<WasmPastaFq>) {
        self.t = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_f(&mut self, x: WasmFlatVector<WasmPastaFq>) {
        self.f = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_sigma1(&mut self, x: WasmFlatVector<WasmPastaFq>) {
        self.sigma1 = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_sigma2(&mut self, x: WasmFlatVector<WasmPastaFq>) {
        self.sigma2 = x
    }
}

impl From<&WasmPastaFqProofEvaluations> for DlogProofEvaluations<Vec<Fq>> {
    fn from(x: &WasmPastaFqProofEvaluations) -> Self {
        DlogProofEvaluations {
            l: x.l.clone().into_iter().map(|x| { x.0 }).collect(),
            r: x.r.clone().into_iter().map(|x| { x.0 }).collect(),
            o: x.o.clone().into_iter().map(|x| { x.0 }).collect(),
            z: x.z.clone().into_iter().map(|x| { x.0 }).collect(),
            t: x.t.clone().into_iter().map(|x| { x.0 }).collect(),
            f: x.f.clone().into_iter().map(|x| { x.0 }).collect(),
            sigma1: x.sigma1.clone().into_iter().map(|x| { x.0 }).collect(),
            sigma2: x.sigma2.clone().into_iter().map(|x| { x.0 }).collect(),
        }
    }
}

impl From<WasmPastaFqProofEvaluations> for DlogProofEvaluations<Vec<Fq>> {
    fn from(x: WasmPastaFqProofEvaluations) -> Self {
        DlogProofEvaluations {
            l: x.l.into_iter().map(|x| { x.0 }).collect(),
            r: x.r.into_iter().map(|x| { x.0 }).collect(),
            o: x.o.into_iter().map(|x| { x.0 }).collect(),
            z: x.z.into_iter().map(|x| { x.0 }).collect(),
            t: x.t.into_iter().map(|x| { x.0 }).collect(),
            f: x.f.into_iter().map(|x| { x.0 }).collect(),
            sigma1: x.sigma1.into_iter().map(|x| { x.0 }).collect(),
            sigma2: x.sigma2.into_iter().map(|x| { x.0 }).collect(),
        }
    }
}

impl From<&DlogProofEvaluations<Vec<Fq>>> for WasmPastaFqProofEvaluations {
    fn from(x: &DlogProofEvaluations<Vec<Fq>>) -> Self {
        WasmPastaFqProofEvaluations {
            l: x.l.clone().into_iter().map(|x| { WasmPastaFq(x) }).collect(),
            r: x.r.clone().into_iter().map(|x| { WasmPastaFq(x) }).collect(),
            o: x.o.clone().into_iter().map(|x| { WasmPastaFq(x) }).collect(),
            z: x.z.clone().into_iter().map(|x| { WasmPastaFq(x) }).collect(),
            t: x.t.clone().into_iter().map(|x| { WasmPastaFq(x) }).collect(),
            f: x.f.clone().into_iter().map(|x| { WasmPastaFq(x) }).collect(),
            sigma1: x.sigma1.clone().into_iter().map(|x| { WasmPastaFq(x) }).collect(),
            sigma2: x.sigma2.clone().into_iter().map(|x| { WasmPastaFq(x) }).collect(),
        }
    }
}

impl From<DlogProofEvaluations<Vec<Fq>>> for WasmPastaFqProofEvaluations {
    fn from(x: DlogProofEvaluations<Vec<Fq>>) -> Self {
        WasmPastaFqProofEvaluations {
            l: x.l.into_iter().map(|x| { WasmPastaFq(x) }).collect(),
            r: x.r.into_iter().map(|x| { WasmPastaFq(x) }).collect(),
            o: x.o.into_iter().map(|x| { WasmPastaFq(x) }).collect(),
            z: x.z.into_iter().map(|x| { WasmPastaFq(x) }).collect(),
            t: x.t.into_iter().map(|x| { WasmPastaFq(x) }).collect(),
            f: x.f.into_iter().map(|x| { WasmPastaFq(x) }).collect(),
            sigma1: x.sigma1.into_iter().map(|x| { WasmPastaFq(x) }).collect(),
            sigma2: x.sigma2.into_iter().map(|x| { WasmPastaFq(x) }).collect(),
        }
    }
}

#[wasm_bindgen]
#[derive(Clone, Debug)]
pub struct WasmPastaFqOpeningProof {
    #[wasm_bindgen(skip)]
    pub lr_0: WasmVector<WasmPallasGAffine>, // vector of rounds of L commitments
    #[wasm_bindgen(skip)]
    pub lr_1: WasmVector<WasmPallasGAffine>, // vector of rounds of R commitments
    #[wasm_bindgen(skip)]
    pub delta: WasmPallasGAffine,
    pub z1: WasmPastaFq,
    pub z2: WasmPastaFq,
    #[wasm_bindgen(skip)]
    pub sg: WasmPallasGAffine,
}

#[wasm_bindgen]
impl WasmPastaFqOpeningProof {
    #[wasm_bindgen(constructor)]
    pub fn new(
        lr_0: WasmVector<WasmPallasGAffine>,
        lr_1: WasmVector<WasmPallasGAffine>,
        delta: WasmPallasGAffine,
        z1: WasmPastaFq,
        z2: WasmPastaFq,
        sg: WasmPallasGAffine) -> Self {
        WasmPastaFqOpeningProof { lr_0, lr_1, delta, z1, z2, sg }
    }

    #[wasm_bindgen(getter)]
    pub fn lr_0(&self) -> WasmVector<WasmPallasGAffine> {
        self.lr_0.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn lr_1(&self) -> WasmVector<WasmPallasGAffine> {
        self.lr_1.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn delta(&self) -> WasmPallasGAffine {
        self.delta.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn sg(&self) -> WasmPallasGAffine {
        self.sg.clone()
    }

    #[wasm_bindgen(setter)]
    pub fn set_lr_0(&mut self, lr_0: WasmVector<WasmPallasGAffine>) {
        self.lr_0 = lr_0
    }
    #[wasm_bindgen(setter)]
    pub fn set_lr_1(&mut self, lr_1: WasmVector<WasmPallasGAffine>) {
        self.lr_1 = lr_1
    }
    #[wasm_bindgen(setter)]
    pub fn set_delta(&mut self, delta: WasmPallasGAffine) {
        self.delta = delta
    }
    #[wasm_bindgen(setter)]
    pub fn set_sg(&mut self, sg: WasmPallasGAffine) {
        self.sg = sg
    }
}

impl From<&WasmPastaFqOpeningProof> for OpeningProof<GAffine> {
    fn from(x: &WasmPastaFqOpeningProof) -> Self {
        OpeningProof {
            lr: x.lr_0.clone().into_iter().zip(x.lr_1.clone().into_iter()).map(|(x, y)| (x.into(), y.into())).collect(),
            delta: x.delta.clone().into(),
            z1: x.z1.into(),
            z2: x.z2.into(),
            sg: x.sg.clone().into(),
        }
    }
}

impl From<WasmPastaFqOpeningProof> for OpeningProof<GAffine> {
    fn from(x: WasmPastaFqOpeningProof) -> Self {
        let WasmPastaFqOpeningProof {lr_0, lr_1, delta, z1, z2, sg} = x;
        OpeningProof {
            lr: lr_0.into_iter().zip(lr_1.into_iter()).map(|(x, y)| (x.into(), y.into())).collect(),
            delta: delta.into(),
            z1: z1.into(),
            z2: z2.into(),
            sg: sg.into(),
        }
    }
}

impl From<&OpeningProof<GAffine>> for WasmPastaFqOpeningProof {
    fn from(x: &OpeningProof<GAffine>) -> Self {
        let (lr_0, lr_1) = x.lr.clone().into_iter().map(|(x, y)| (x.into(), y.into())).unzip();
        WasmPastaFqOpeningProof {
            lr_0,
            lr_1,
            delta: x.delta.clone().into(),
            z1: x.z1.into(),
            z2: x.z2.into(),
            sg: x.sg.clone().into(),
        }
    }
}

impl From<OpeningProof<GAffine>> for WasmPastaFqOpeningProof {
    fn from(x: OpeningProof<GAffine>) -> Self {
        let (lr_0, lr_1) = x.lr.clone().into_iter().map(|(x, y)| (x.into(), y.into())).unzip();
        WasmPastaFqOpeningProof {
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
#[derive(Clone)]
pub struct WasmPastaFqProverCommitments
{
    #[wasm_bindgen(skip)]
    pub l_comm: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub r_comm: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub o_comm: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub z_comm: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub t_comm: WasmPastaPallasPolyComm,
}

#[wasm_bindgen]
impl WasmPastaFqProverCommitments {
    #[wasm_bindgen(constructor)]
    pub fn new(
        l_comm: WasmPastaPallasPolyComm,
        r_comm: WasmPastaPallasPolyComm,
        o_comm: WasmPastaPallasPolyComm,
        z_comm: WasmPastaPallasPolyComm,
        t_comm: WasmPastaPallasPolyComm) -> Self {
        WasmPastaFqProverCommitments { l_comm, r_comm, o_comm, z_comm, t_comm }
    }

    #[wasm_bindgen(getter)]
    pub fn l_comm(&self) -> WasmPastaPallasPolyComm {
        self.l_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn r_comm(&self) -> WasmPastaPallasPolyComm {
        self.r_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn o_comm(&self) -> WasmPastaPallasPolyComm {
        self.o_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn z_comm(&self) -> WasmPastaPallasPolyComm {
        self.z_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn t_comm(&self) -> WasmPastaPallasPolyComm {
        self.t_comm.clone()
    }

    #[wasm_bindgen(setter)]
    pub fn set_l_comm(&mut self, x: WasmPastaPallasPolyComm) {
        self.l_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_r_comm(&mut self, x: WasmPastaPallasPolyComm) {
        self.r_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_o_comm(&mut self, x: WasmPastaPallasPolyComm) {
        self.o_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_z_comm(&mut self, x: WasmPastaPallasPolyComm) {
        self.z_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_t_comm(&mut self, x: WasmPastaPallasPolyComm) {
        self.t_comm = x
    }
}

impl From<&DlogCommitments<GAffine>> for WasmPastaFqProverCommitments {
    fn from(x: &DlogCommitments<GAffine>) -> Self {
        WasmPastaFqProverCommitments {
            l_comm: x.l_comm.clone().into(),
            r_comm: x.r_comm.clone().into(),
            o_comm: x.o_comm.clone().into(),
            z_comm: x.z_comm.clone().into(),
            t_comm: x.t_comm.clone().into(),
        }
    }
}

impl From<DlogCommitments<GAffine>> for WasmPastaFqProverCommitments {
    fn from(x: DlogCommitments<GAffine>) -> Self {
        WasmPastaFqProverCommitments {
            l_comm: x.l_comm.into(),
            r_comm: x.r_comm.into(),
            o_comm: x.o_comm.into(),
            z_comm: x.z_comm.into(),
            t_comm: x.t_comm.into(),
        }
    }
}

impl From<&WasmPastaFqProverCommitments> for DlogCommitments<GAffine> {
    fn from(x: &WasmPastaFqProverCommitments) -> Self {
        DlogCommitments {
            l_comm: x.l_comm.clone().into(),
            r_comm: x.r_comm.clone().into(),
            o_comm: x.o_comm.clone().into(),
            z_comm: x.z_comm.clone().into(),
            t_comm: x.t_comm.clone().into(),
        }
    }
}

impl From<WasmPastaFqProverCommitments> for DlogCommitments<GAffine> {
    fn from(x: WasmPastaFqProverCommitments) -> Self {
        DlogCommitments {
            l_comm: x.l_comm.into(),
            r_comm: x.r_comm.into(),
            o_comm: x.o_comm.into(),
            z_comm: x.z_comm.into(),
            t_comm: x.t_comm.into(),
        }
    }
}

#[wasm_bindgen]
pub struct WasmVecVecPastaFq(Vec<Vec<Fq>>);

#[wasm_bindgen]
impl WasmVecVecPastaFq {
    #[wasm_bindgen(constructor)]
    pub fn create(n: i32) -> Self {
        WasmVecVecPastaFq(Vec::with_capacity(n as usize))
    }

    #[wasm_bindgen]
    pub fn push(&mut self, x: WasmFlatVector<WasmPastaFq>) {
        self.0.push(x.into_iter().map(Into::into).collect())
    }

    #[wasm_bindgen]
    pub fn get(&self, i: i32) -> WasmFlatVector<WasmPastaFq> {
        self.0[i as usize].clone().into_iter().map(Into::into).collect()
    }

    #[wasm_bindgen]
    pub fn set(&mut self, i: i32, x: WasmFlatVector<WasmPastaFq>) {
        self.0[i as usize] = x.into_iter().map(Into::into).collect()
    }
}

#[wasm_bindgen]
#[derive(Clone)]
pub struct WasmPastaFqProverProof
{
    #[wasm_bindgen(skip)]
    pub commitments: WasmPastaFqProverCommitments,
    #[wasm_bindgen(skip)]
    pub proof: WasmPastaFqOpeningProof,
    #[wasm_bindgen(skip)]
    pub evals0: WasmPastaFqProofEvaluations,
    #[wasm_bindgen(skip)]
    pub evals1: WasmPastaFqProofEvaluations,
    #[wasm_bindgen(skip)]
    pub public: WasmFlatVector<WasmPastaFq>,
    #[wasm_bindgen(skip)]
    pub prev_challenges_scalars: Vec<Vec<Fq>>,
    #[wasm_bindgen(skip)]
    pub prev_challenges_comms: WasmVector<WasmPastaPallasPolyComm>,
}

#[wasm_bindgen]
impl WasmPastaFqProverProof {
    #[wasm_bindgen(constructor)]
    pub fn new(
        commitments: WasmPastaFqProverCommitments,
        proof: WasmPastaFqOpeningProof,
        evals0: WasmPastaFqProofEvaluations,
        evals1: WasmPastaFqProofEvaluations,
        public_: WasmFlatVector<WasmPastaFq>,
        prev_challenges_scalars: WasmVecVecPastaFq,
        prev_challenges_comms: WasmVector<WasmPastaPallasPolyComm>) -> Self {
        WasmPastaFqProverProof {
            commitments,
            proof,
            evals0,
            evals1,
            public: public_,
            prev_challenges_scalars: prev_challenges_scalars.0,
            prev_challenges_comms,
        }
    }

    #[wasm_bindgen(getter)]
    pub fn commitments(&self) -> WasmPastaFqProverCommitments {
        self.commitments.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn proof(&self) -> WasmPastaFqOpeningProof {
        self.proof.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn evals0(&self) -> WasmPastaFqProofEvaluations {
        self.evals0.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn evals1(&self) -> WasmPastaFqProofEvaluations {
        self.evals1.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn public_(&self) -> WasmFlatVector<WasmPastaFq> {
        self.public.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn prev_challenges_scalars(&self) -> WasmVecVecPastaFq {
        WasmVecVecPastaFq(self.prev_challenges_scalars.clone())
    }
    #[wasm_bindgen(getter)]
    pub fn prev_challenges_comms(&self) -> WasmVector<WasmPastaPallasPolyComm> {
        self.prev_challenges_comms.clone()
    }

    #[wasm_bindgen(setter)]
    pub fn set_commitments(&mut self, commitments: WasmPastaFqProverCommitments) {
        self.commitments = commitments
    }
    #[wasm_bindgen(setter)]
    pub fn set_proof(&mut self, proof: WasmPastaFqOpeningProof) {
        self.proof = proof
    }
    #[wasm_bindgen(setter)]
    pub fn set_evals0(&mut self, evals0: WasmPastaFqProofEvaluations) {
        self.evals0 = evals0
    }
    #[wasm_bindgen(setter)]
    pub fn set_evals1(&mut self, evals1: WasmPastaFqProofEvaluations) {
        self.evals1 = evals1
    }
    #[wasm_bindgen(setter)]
    pub fn set_public_(&mut self, public_: WasmFlatVector<WasmPastaFq>) {
        self.public = public_
    }
    #[wasm_bindgen(setter)]
    pub fn set_prev_challenges_scalars(&mut self, prev_challenges_scalars: WasmVecVecPastaFq) {
        self.prev_challenges_scalars = prev_challenges_scalars.0
    }
    #[wasm_bindgen(setter)]
    pub fn set_prev_challenges_comms(&mut self, prev_challenges_comms: WasmVector<WasmPastaPallasPolyComm>) {
        self.prev_challenges_comms = prev_challenges_comms
    }
}

impl From<&DlogProof<GAffine>> for WasmPastaFqProverProof {
    fn from(x: &DlogProof<GAffine>) -> Self {
        let (scalars, comms) = x.prev_challenges.iter().map(|(x, y)| (x.clone().into(), y.into())).unzip();
        WasmPastaFqProverProof {
            commitments: x.commitments.clone().into(),
            proof: x.proof.clone().into(),
            evals0: x.evals[0].clone().into(),
            evals1: x.evals[1].clone().into(),
            public: x.public.clone().into_iter().map(Into::into).collect(),
            prev_challenges_scalars: scalars,
            prev_challenges_comms: comms,
        }
    }
}

impl From<DlogProof<GAffine>> for WasmPastaFqProverProof {
    fn from(x: DlogProof<GAffine>) -> Self {
        let DlogProof {commitments, proof, evals: [evals0, evals1], public, prev_challenges} = x;
        let (scalars, comms) = prev_challenges.into_iter().map(|(x, y)| (x.into(), y.into())).unzip();
        WasmPastaFqProverProof {
            commitments: commitments.into(),
            proof: proof.into(),
            evals0: evals0.into(),
            evals1: evals1.into(),
            public: public.into_iter().map(Into::into).collect(),
            prev_challenges_scalars: scalars,
            prev_challenges_comms: comms,
        }
    }
}

impl From<&WasmPastaFqProverProof> for DlogProof<GAffine> {
    fn from(x: &WasmPastaFqProverProof) -> Self {
        DlogProof {
            commitments: x.commitments.clone().into(),
            proof: x.proof.clone().into(),
            evals: [x.evals0.clone().into(), x.evals1.clone().into()],
            public: x.public.clone().into_iter().map(Into::into).collect(),
            prev_challenges: (&x.prev_challenges_scalars).into_iter().zip((&x.prev_challenges_comms).into_iter()).map(|(x, y)| { (x.clone().into(), y.into()) }).collect(),
        }
    }
}

impl From<WasmPastaFqProverProof> for DlogProof<GAffine> {
    fn from(x: WasmPastaFqProverProof) -> Self {
        DlogProof {
            commitments: x.commitments.into(),
            proof: x.proof.into(),
            evals: [x.evals0.into(), x.evals1.into()],
            public: x.public.into_iter().map(Into::into).collect(),
            prev_challenges: (x.prev_challenges_scalars).into_iter().zip((x.prev_challenges_comms).into_iter()).map(|(x, y)| { (x.into(), y.into()) }).collect(),
        }
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_proof_create(
    index: &WasmPastaFqPlonkIndex,
    primary_input: WasmFlatVector<WasmPastaFq>,
    auxiliary_input: WasmFlatVector<WasmPastaFq>,
    prev_challenges: WasmFlatVector<WasmPastaFq>,
    prev_sgs: WasmVector<WasmPallasGAffine>,
) -> Result<WasmPastaFqProverProof, JsValue> {
    // TODO: Should we be ignoring this?!
    let _primary_input = primary_input;

    let prev: Vec<(Vec<Fq>, PolyComm<GAffine>)> = {
        if prev_challenges.len() == 0 {
            Vec::new()
        } else {
            let challenges_per_sg = prev_challenges.len() / prev_sgs.len();
            prev_sgs
                .into_iter()
                .enumerate()
                .map(|(i, sg)| {
                    (
                        prev_challenges[(i * challenges_per_sg)..(i + 1) * challenges_per_sg]
                            .iter()
                            .map(|x| (*x).into())
                            .collect(),
                        PolyComm::<GAffine> {
                            unshifted: vec![sg.into()],
                            shifted: None,
                        },
                    )
                })
                .collect()
        }
    };

    let auxiliary_input: Vec<Fq> = auxiliary_input.into_iter().map(Into::into).collect();
    let index: &DlogIndex<GAffine> = &index.0;

    let map = GroupMap::<Fp>::setup();
    DlogProof::create::<
        DefaultFqSponge<PallasParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fq, PlonkSpongeConstants>,
    >(&map, &auxiliary_input, &index, prev)
    .map_err(|err| {
        let str =
            match err {
                oracle::rndoracle::ProofError::WitnessCsInconsistent => "caml_pasta_fq_plonk_proof_create: WitnessCsInconsistent",
                oracle::rndoracle::ProofError::DomainCreation => "caml_pasta_fq_plonk_proof_create: DomainCreation",
                oracle::rndoracle::ProofError::PolyDivision => "caml_pasta_fq_plonk_proof_create: PolyDivision",
                oracle::rndoracle::ProofError::PolyCommit => "caml_pasta_fq_plonk_proof_create: PolyCommit",
                oracle::rndoracle::ProofError::PolyCommitWithBound => "caml_pasta_fq_plonk_proof_create: PolyCommitWithBound",
                oracle::rndoracle::ProofError::PolyExponentiate => "caml_pasta_fq_plonk_proof_create: PolyExponentiate",
                oracle::rndoracle::ProofError::ProofCreation => "caml_pasta_fq_plonk_proof_create: ProofCreation",
                oracle::rndoracle::ProofError::ProofVerification => "caml_pasta_fq_plonk_proof_create: ProofVerification",
                oracle::rndoracle::ProofError::OpenProof => "caml_pasta_fq_plonk_proof_create: OpenProof",
                oracle::rndoracle::ProofError::SumCheck => "caml_pasta_fq_plonk_proof_create: SumCheck",
                oracle::rndoracle::ProofError::ConstraintInconsist => "caml_pasta_fq_plonk_proof_create: ConstraintInconsist",
                oracle::rndoracle::ProofError::EvaluationGroup => "caml_pasta_fq_plonk_proof_create: EvaluationGroup",
                oracle::rndoracle::ProofError::OracleCommit => "caml_pasta_fq_plonk_proof_create: OracleCommit",
                oracle::rndoracle::ProofError::RuntimeEnv => "caml_pasta_fq_plonk_proof_create: RuntimeEnv",
                oracle::rndoracle::ProofError::BadMultiScalarMul => "caml_pasta_fq_plonk_proof_create: BadMultiScalarMul",
                oracle::rndoracle::ProofError::BadSrsLength => "caml_pasta_fq_plonk_proof_create: BadSrsLength",
            };
        JsValue::from_str(str)
    })
    .map(Into::into)
}

pub fn proof_verify(
    lgr_comm: WasmVector<WasmPastaPallasPolyComm>,
    index: WasmPastaFqPlonkVerifierIndex,
    proof: WasmPastaFqProverProof,
) -> bool {
    let group_map = <GAffine as CommitmentCurve>::Map::setup();

    DlogProof::verify::<
        DefaultFqSponge<PallasParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fq, PlonkSpongeConstants>,
    >(
        &group_map,
        &[(
            &index.into(),
            &lgr_comm.into_iter().map(From::from).collect(),
            &proof.into(),
        )]
        .to_vec(),
    )
    .is_ok()
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_proof_verify(
    lgr_comm: WasmVector<WasmPastaPallasPolyComm>,
    index: WasmPastaFqPlonkVerifierIndex,
    proof: WasmPastaFqProverProof,
) -> bool {
    proof_verify(lgr_comm, index, proof)
}

#[wasm_bindgen]
pub struct WasmVecVecPallasPolyComm(Vec<Vec<PolyComm<GAffine>>>);

#[wasm_bindgen]
impl WasmVecVecPallasPolyComm {
    #[wasm_bindgen(constructor)]
    pub fn create(n: i32) -> Self {
        WasmVecVecPallasPolyComm(Vec::with_capacity(n as usize))
    }

    #[wasm_bindgen]
    pub fn push(&mut self, x: WasmVector<WasmPastaPallasPolyComm>) {
        self.0.push(x.into_iter().map(Into::into).collect())
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_proof_batch_verify(
    lgr_comms: WasmVecVecPallasPolyComm,
    indexes: WasmVector<WasmPastaFqPlonkVerifierIndex>,
    proofs: WasmVector<WasmPastaFqProverProof>,
) -> bool {
    let ts: Vec<_> = indexes
        .into_iter()
        .zip(lgr_comms.0.into_iter())
        .zip(proofs.into_iter())
        .map(|((i, l), p)| (i.into(), l.into_iter().map(From::from).collect(), p.into()))
        .collect();
    let ts: Vec<_> = ts.iter().map(|(i, l, p)| (i, l, p)).collect();
    let group_map = GroupMap::<Fp>::setup();

    DlogProof::<GAffine>::verify::<
        DefaultFqSponge<PallasParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fq, PlonkSpongeConstants>,
    >(&group_map, &ts)
    .is_ok()
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_proof_dummy() -> WasmPastaFqProverProof {
    let g = || GAffine::prime_subgroup_generator();
    let comm = || PolyComm {
        shifted: Some(g()),
        unshifted: vec![g(), g(), g()],
    };
    (DlogProof {
        prev_challenges: vec![
            (vec![Fq::one(), Fq::one()], comm()),
            (vec![Fq::one(), Fq::one()], comm()),
            (vec![Fq::one(), Fq::one()], comm()),
        ],
        proof: OpeningProof {
            lr: vec![(g(), g()), (g(), g()), (g(), g())],
            z1: Fq::one(),
            z2: Fq::one(),
            delta: g(),
            sg: g(),
        },
        commitments: DlogCommitments {
            l_comm: comm(),
            r_comm: comm(),
            o_comm: comm(),
            z_comm: comm(),
            t_comm: comm(),
        },
        public: vec![Fq::one(), Fq::one()],
        evals: {
            let evals = || vec![Fq::one(), Fq::one(), Fq::one(), Fq::one()];
            let evals = || DlogProofEvaluations {
                l: evals(),
                r: evals(),
                o: evals(),
                z: evals(),
                t: evals(),
                f: evals(),
                sigma1: evals(),
                sigma2: evals(),
            };
            [evals(), evals()]
        },
    }).into()
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_proof_deep_copy(x: WasmPastaFqProverProof) -> WasmPastaFqProverProof {
    x
}
