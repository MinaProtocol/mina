use wasm_bindgen::prelude::*;
use wasm_bindgen::JsValue;
use mina_curves::pasta::{
        vesta::{Affine as GAffine, VestaParameters},
        fp::Fp,
        fq::Fq,
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

use crate::pasta_fp::WasmPastaFp;
use crate::pasta_fp_plonk_index::WasmPastaFpPlonkIndex;
use crate::pasta_fp_plonk_verifier_index::WasmPastaFpPlonkVerifierIndex;
use crate::wasm_flat_vector::WasmFlatVector;
use crate::wasm_vector::WasmVector;
use crate::pasta_vesta::WasmVestaGAffine;
use crate::pasta_vesta_poly_comm::WasmPastaVestaPolyComm;

#[wasm_bindgen]
#[derive(Clone)]
pub struct WasmPastaFpProofEvaluations {
    #[wasm_bindgen(skip)]
    pub l: WasmFlatVector<WasmPastaFp>,
    #[wasm_bindgen(skip)]
    pub r: WasmFlatVector<WasmPastaFp>,
    #[wasm_bindgen(skip)]
    pub o: WasmFlatVector<WasmPastaFp>,
    #[wasm_bindgen(skip)]
    pub z: WasmFlatVector<WasmPastaFp>,
    #[wasm_bindgen(skip)]
    pub t: WasmFlatVector<WasmPastaFp>,
    #[wasm_bindgen(skip)]
    pub f: WasmFlatVector<WasmPastaFp>,
    #[wasm_bindgen(skip)]
    pub sigma1: WasmFlatVector<WasmPastaFp>,
    #[wasm_bindgen(skip)]
    pub sigma2: WasmFlatVector<WasmPastaFp>,
}

#[wasm_bindgen]
impl WasmPastaFpProofEvaluations {
    #[wasm_bindgen(constructor)]
    pub fn new(
        l: WasmFlatVector<WasmPastaFp>,
        r: WasmFlatVector<WasmPastaFp>,
        o: WasmFlatVector<WasmPastaFp>,
        z: WasmFlatVector<WasmPastaFp>,
        t: WasmFlatVector<WasmPastaFp>,
        f: WasmFlatVector<WasmPastaFp>,
        sigma1: WasmFlatVector<WasmPastaFp>,
        sigma2: WasmFlatVector<WasmPastaFp>) -> Self {
        WasmPastaFpProofEvaluations { l, r, o, z, t, f, sigma1, sigma2 }
    }

    #[wasm_bindgen(getter)]
    pub fn l(&self) -> WasmFlatVector<WasmPastaFp> {
        self.l.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn r(&self) -> WasmFlatVector<WasmPastaFp> {
        self.r.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn o(&self) -> WasmFlatVector<WasmPastaFp> {
        self.o.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn z(&self) -> WasmFlatVector<WasmPastaFp> {
        self.z.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn t(&self) -> WasmFlatVector<WasmPastaFp> {
        self.t.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn f(&self) -> WasmFlatVector<WasmPastaFp> {
        self.f.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn sigma1(&self) -> WasmFlatVector<WasmPastaFp> {
        self.sigma1.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn sigma2(&self) -> WasmFlatVector<WasmPastaFp> {
        self.sigma2.clone()
    }

    #[wasm_bindgen(setter)]
    pub fn set_l(&mut self, x: WasmFlatVector<WasmPastaFp>) {
        self.l = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_r(&mut self, x: WasmFlatVector<WasmPastaFp>) {
        self.r = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_o(&mut self, x: WasmFlatVector<WasmPastaFp>) {
        self.o = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_z(&mut self, x: WasmFlatVector<WasmPastaFp>) {
        self.z = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_t(&mut self, x: WasmFlatVector<WasmPastaFp>) {
        self.t = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_f(&mut self, x: WasmFlatVector<WasmPastaFp>) {
        self.f = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_sigma1(&mut self, x: WasmFlatVector<WasmPastaFp>) {
        self.sigma1 = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_sigma2(&mut self, x: WasmFlatVector<WasmPastaFp>) {
        self.sigma2 = x
    }
}

impl From<&WasmPastaFpProofEvaluations> for DlogProofEvaluations<Vec<Fp>> {
    fn from(x: &WasmPastaFpProofEvaluations) -> Self {
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

impl From<WasmPastaFpProofEvaluations> for DlogProofEvaluations<Vec<Fp>> {
    fn from(x: WasmPastaFpProofEvaluations) -> Self {
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

impl From<&DlogProofEvaluations<Vec<Fp>>> for WasmPastaFpProofEvaluations {
    fn from(x: &DlogProofEvaluations<Vec<Fp>>) -> Self {
        WasmPastaFpProofEvaluations {
            l: x.l.clone().into_iter().map(|x| { WasmPastaFp(x) }).collect(),
            r: x.r.clone().into_iter().map(|x| { WasmPastaFp(x) }).collect(),
            o: x.o.clone().into_iter().map(|x| { WasmPastaFp(x) }).collect(),
            z: x.z.clone().into_iter().map(|x| { WasmPastaFp(x) }).collect(),
            t: x.t.clone().into_iter().map(|x| { WasmPastaFp(x) }).collect(),
            f: x.f.clone().into_iter().map(|x| { WasmPastaFp(x) }).collect(),
            sigma1: x.sigma1.clone().into_iter().map(|x| { WasmPastaFp(x) }).collect(),
            sigma2: x.sigma2.clone().into_iter().map(|x| { WasmPastaFp(x) }).collect(),
        }
    }
}

impl From<DlogProofEvaluations<Vec<Fp>>> for WasmPastaFpProofEvaluations {
    fn from(x: DlogProofEvaluations<Vec<Fp>>) -> Self {
        WasmPastaFpProofEvaluations {
            l: x.l.into_iter().map(|x| { WasmPastaFp(x) }).collect(),
            r: x.r.into_iter().map(|x| { WasmPastaFp(x) }).collect(),
            o: x.o.into_iter().map(|x| { WasmPastaFp(x) }).collect(),
            z: x.z.into_iter().map(|x| { WasmPastaFp(x) }).collect(),
            t: x.t.into_iter().map(|x| { WasmPastaFp(x) }).collect(),
            f: x.f.into_iter().map(|x| { WasmPastaFp(x) }).collect(),
            sigma1: x.sigma1.into_iter().map(|x| { WasmPastaFp(x) }).collect(),
            sigma2: x.sigma2.into_iter().map(|x| { WasmPastaFp(x) }).collect(),
        }
    }
}

#[wasm_bindgen]
#[derive(Clone, Debug)]
pub struct WasmPastaFpOpeningProof {
    #[wasm_bindgen(skip)]
    pub lr_0: WasmVector<WasmVestaGAffine>, // vector of rounds of L commitments
    #[wasm_bindgen(skip)]
    pub lr_1: WasmVector<WasmVestaGAffine>, // vector of rounds of R commitments
    #[wasm_bindgen(skip)]
    pub delta: WasmVestaGAffine,
    pub z1: WasmPastaFp,
    pub z2: WasmPastaFp,
    #[wasm_bindgen(skip)]
    pub sg: WasmVestaGAffine,
}

#[wasm_bindgen]
impl WasmPastaFpOpeningProof {
    #[wasm_bindgen(constructor)]
    pub fn new(
        lr_0: WasmVector<WasmVestaGAffine>,
        lr_1: WasmVector<WasmVestaGAffine>,
        delta: WasmVestaGAffine,
        z1: WasmPastaFp,
        z2: WasmPastaFp,
        sg: WasmVestaGAffine) -> Self {
        WasmPastaFpOpeningProof { lr_0, lr_1, delta, z1, z2, sg }
    }

    #[wasm_bindgen(getter)]
    pub fn lr_0(&self) -> WasmVector<WasmVestaGAffine> {
        self.lr_0.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn lr_1(&self) -> WasmVector<WasmVestaGAffine> {
        self.lr_1.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn delta(&self) -> WasmVestaGAffine {
        self.delta.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn sg(&self) -> WasmVestaGAffine {
        self.sg.clone()
    }

    #[wasm_bindgen(setter)]
    pub fn set_lr_0(&mut self, lr_0: WasmVector<WasmVestaGAffine>) {
        self.lr_0 = lr_0
    }
    #[wasm_bindgen(setter)]
    pub fn set_lr_1(&mut self, lr_1: WasmVector<WasmVestaGAffine>) {
        self.lr_1 = lr_1
    }
    #[wasm_bindgen(setter)]
    pub fn set_delta(&mut self, delta: WasmVestaGAffine) {
        self.delta = delta
    }
    #[wasm_bindgen(setter)]
    pub fn set_sg(&mut self, sg: WasmVestaGAffine) {
        self.sg = sg
    }
}

impl From<&WasmPastaFpOpeningProof> for OpeningProof<GAffine> {
    fn from(x: &WasmPastaFpOpeningProof) -> Self {
        OpeningProof {
            lr: x.lr_0.clone().into_iter().zip(x.lr_1.clone().into_iter()).map(|(x, y)| (x.into(), y.into())).collect(),
            delta: x.delta.clone().into(),
            z1: x.z1.into(),
            z2: x.z2.into(),
            sg: x.sg.clone().into(),
        }
    }
}

impl From<WasmPastaFpOpeningProof> for OpeningProof<GAffine> {
    fn from(x: WasmPastaFpOpeningProof) -> Self {
        let WasmPastaFpOpeningProof {lr_0, lr_1, delta, z1, z2, sg} = x;
        OpeningProof {
            lr: lr_0.into_iter().zip(lr_1.into_iter()).map(|(x, y)| (x.into(), y.into())).collect(),
            delta: delta.into(),
            z1: z1.into(),
            z2: z2.into(),
            sg: sg.into(),
        }
    }
}

impl From<&OpeningProof<GAffine>> for WasmPastaFpOpeningProof {
    fn from(x: &OpeningProof<GAffine>) -> Self {
        let (lr_0, lr_1) = x.lr.clone().into_iter().map(|(x, y)| (x.into(), y.into())).unzip();
        WasmPastaFpOpeningProof {
            lr_0,
            lr_1,
            delta: x.delta.clone().into(),
            z1: x.z1.into(),
            z2: x.z2.into(),
            sg: x.sg.clone().into(),
        }
    }
}

impl From<OpeningProof<GAffine>> for WasmPastaFpOpeningProof {
    fn from(x: OpeningProof<GAffine>) -> Self {
        let (lr_0, lr_1) = x.lr.clone().into_iter().map(|(x, y)| (x.into(), y.into())).unzip();
        WasmPastaFpOpeningProof {
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
pub struct WasmPastaFpProverCommitments
{
    #[wasm_bindgen(skip)]
    pub l_comm: WasmPastaVestaPolyComm,
    #[wasm_bindgen(skip)]
    pub r_comm: WasmPastaVestaPolyComm,
    #[wasm_bindgen(skip)]
    pub o_comm: WasmPastaVestaPolyComm,
    #[wasm_bindgen(skip)]
    pub z_comm: WasmPastaVestaPolyComm,
    #[wasm_bindgen(skip)]
    pub t_comm: WasmPastaVestaPolyComm,
}

#[wasm_bindgen]
impl WasmPastaFpProverCommitments {
    #[wasm_bindgen(constructor)]
    pub fn new(
        l_comm: WasmPastaVestaPolyComm,
        r_comm: WasmPastaVestaPolyComm,
        o_comm: WasmPastaVestaPolyComm,
        z_comm: WasmPastaVestaPolyComm,
        t_comm: WasmPastaVestaPolyComm) -> Self {
        WasmPastaFpProverCommitments { l_comm, r_comm, o_comm, z_comm, t_comm }
    }

    #[wasm_bindgen(getter)]
    pub fn l_comm(&self) -> WasmPastaVestaPolyComm {
        self.l_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn r_comm(&self) -> WasmPastaVestaPolyComm {
        self.r_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn o_comm(&self) -> WasmPastaVestaPolyComm {
        self.o_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn z_comm(&self) -> WasmPastaVestaPolyComm {
        self.z_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn t_comm(&self) -> WasmPastaVestaPolyComm {
        self.t_comm.clone()
    }

    #[wasm_bindgen(setter)]
    pub fn set_l_comm(&mut self, x: WasmPastaVestaPolyComm) {
        self.l_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_r_comm(&mut self, x: WasmPastaVestaPolyComm) {
        self.r_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_o_comm(&mut self, x: WasmPastaVestaPolyComm) {
        self.o_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_z_comm(&mut self, x: WasmPastaVestaPolyComm) {
        self.z_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_t_comm(&mut self, x: WasmPastaVestaPolyComm) {
        self.t_comm = x
    }
}

impl From<&DlogCommitments<GAffine>> for WasmPastaFpProverCommitments {
    fn from(x: &DlogCommitments<GAffine>) -> Self {
        WasmPastaFpProverCommitments {
            l_comm: x.l_comm.clone().into(),
            r_comm: x.r_comm.clone().into(),
            o_comm: x.o_comm.clone().into(),
            z_comm: x.z_comm.clone().into(),
            t_comm: x.t_comm.clone().into(),
        }
    }
}

impl From<DlogCommitments<GAffine>> for WasmPastaFpProverCommitments {
    fn from(x: DlogCommitments<GAffine>) -> Self {
        WasmPastaFpProverCommitments {
            l_comm: x.l_comm.into(),
            r_comm: x.r_comm.into(),
            o_comm: x.o_comm.into(),
            z_comm: x.z_comm.into(),
            t_comm: x.t_comm.into(),
        }
    }
}

impl From<&WasmPastaFpProverCommitments> for DlogCommitments<GAffine> {
    fn from(x: &WasmPastaFpProverCommitments) -> Self {
        DlogCommitments {
            l_comm: x.l_comm.clone().into(),
            r_comm: x.r_comm.clone().into(),
            o_comm: x.o_comm.clone().into(),
            z_comm: x.z_comm.clone().into(),
            t_comm: x.t_comm.clone().into(),
        }
    }
}

impl From<WasmPastaFpProverCommitments> for DlogCommitments<GAffine> {
    fn from(x: WasmPastaFpProverCommitments) -> Self {
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
pub struct WasmVecVecPastaFp(Vec<Vec<Fp>>);

#[wasm_bindgen]
impl WasmVecVecPastaFp {
    #[wasm_bindgen(constructor)]
    pub fn create(n: i32) -> Self {
        WasmVecVecPastaFp(Vec::with_capacity(n as usize))
    }

    #[wasm_bindgen]
    pub fn push(&mut self, x: WasmFlatVector<WasmPastaFp>) {
        self.0.push(x.into_iter().map(Into::into).collect())
    }

    #[wasm_bindgen]
    pub fn get(&self, i: i32) -> WasmFlatVector<WasmPastaFp> {
        self.0[i as usize].clone().into_iter().map(Into::into).collect()
    }

    #[wasm_bindgen]
    pub fn set(&mut self, i: i32, x: WasmFlatVector<WasmPastaFp>) {
        self.0[i as usize] = x.into_iter().map(Into::into).collect()
    }
}

#[wasm_bindgen]
#[derive(Clone)]
pub struct WasmPastaFpProverProof
{
    #[wasm_bindgen(skip)]
    pub commitments: WasmPastaFpProverCommitments,
    #[wasm_bindgen(skip)]
    pub proof: WasmPastaFpOpeningProof,
    #[wasm_bindgen(skip)]
    pub evals0: WasmPastaFpProofEvaluations,
    #[wasm_bindgen(skip)]
    pub evals1: WasmPastaFpProofEvaluations,
    #[wasm_bindgen(skip)]
    pub public: WasmFlatVector<WasmPastaFp>,
    #[wasm_bindgen(skip)]
    pub prev_challenges_scalars: Vec<Vec<Fp>>,
    #[wasm_bindgen(skip)]
    pub prev_challenges_comms: WasmVector<WasmPastaVestaPolyComm>,
}

#[wasm_bindgen]
impl WasmPastaFpProverProof {
    #[wasm_bindgen(constructor)]
    pub fn new(
        commitments: WasmPastaFpProverCommitments,
        proof: WasmPastaFpOpeningProof,
        evals0: WasmPastaFpProofEvaluations,
        evals1: WasmPastaFpProofEvaluations,
        public_: WasmFlatVector<WasmPastaFp>,
        prev_challenges_scalars: WasmVecVecPastaFp,
        prev_challenges_comms: WasmVector<WasmPastaVestaPolyComm>) -> Self {
        WasmPastaFpProverProof {
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
    pub fn commitments(&self) -> WasmPastaFpProverCommitments {
        self.commitments.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn proof(&self) -> WasmPastaFpOpeningProof {
        self.proof.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn evals0(&self) -> WasmPastaFpProofEvaluations {
        self.evals0.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn evals1(&self) -> WasmPastaFpProofEvaluations {
        self.evals1.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn public_(&self) -> WasmFlatVector<WasmPastaFp> {
        self.public.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn prev_challenges_scalars(&self) -> WasmVecVecPastaFp {
        WasmVecVecPastaFp(self.prev_challenges_scalars.clone())
    }
    #[wasm_bindgen(getter)]
    pub fn prev_challenges_comms(&self) -> WasmVector<WasmPastaVestaPolyComm> {
        self.prev_challenges_comms.clone()
    }

    #[wasm_bindgen(setter)]
    pub fn set_commitments(&mut self, commitments: WasmPastaFpProverCommitments) {
        self.commitments = commitments
    }
    #[wasm_bindgen(setter)]
    pub fn set_proof(&mut self, proof: WasmPastaFpOpeningProof) {
        self.proof = proof
    }
    #[wasm_bindgen(setter)]
    pub fn set_evals0(&mut self, evals0: WasmPastaFpProofEvaluations) {
        self.evals0 = evals0
    }
    #[wasm_bindgen(setter)]
    pub fn set_evals1(&mut self, evals1: WasmPastaFpProofEvaluations) {
        self.evals1 = evals1
    }
    #[wasm_bindgen(setter)]
    pub fn set_public_(&mut self, public_: WasmFlatVector<WasmPastaFp>) {
        self.public = public_
    }
    #[wasm_bindgen(setter)]
    pub fn set_prev_challenges_scalars(&mut self, prev_challenges_scalars: WasmVecVecPastaFp) {
        self.prev_challenges_scalars = prev_challenges_scalars.0
    }
    #[wasm_bindgen(setter)]
    pub fn set_prev_challenges_comms(&mut self, prev_challenges_comms: WasmVector<WasmPastaVestaPolyComm>) {
        self.prev_challenges_comms = prev_challenges_comms
    }
}

impl From<&DlogProof<GAffine>> for WasmPastaFpProverProof {
    fn from(x: &DlogProof<GAffine>) -> Self {
        let (scalars, comms) = x.prev_challenges.iter().map(|(x, y)| (x.clone().into(), y.into())).unzip();
        WasmPastaFpProverProof {
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

impl From<DlogProof<GAffine>> for WasmPastaFpProverProof {
    fn from(x: DlogProof<GAffine>) -> Self {
        let DlogProof {commitments, proof, evals: [evals0, evals1], public, prev_challenges} = x;
        let (scalars, comms) = prev_challenges.into_iter().map(|(x, y)| (x.into(), y.into())).unzip();
        WasmPastaFpProverProof {
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

impl From<&WasmPastaFpProverProof> for DlogProof<GAffine> {
    fn from(x: &WasmPastaFpProverProof) -> Self {
        DlogProof {
            commitments: x.commitments.clone().into(),
            proof: x.proof.clone().into(),
            evals: [x.evals0.clone().into(), x.evals1.clone().into()],
            public: x.public.clone().into_iter().map(Into::into).collect(),
            prev_challenges: (&x.prev_challenges_scalars).into_iter().zip((&x.prev_challenges_comms).into_iter()).map(|(x, y)| { (x.clone().into(), y.into()) }).collect(),
        }
    }
}

impl From<WasmPastaFpProverProof> for DlogProof<GAffine> {
    fn from(x: WasmPastaFpProverProof) -> Self {
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
pub fn caml_pasta_fp_plonk_proof_create(
    index: &WasmPastaFpPlonkIndex,
    primary_input: WasmFlatVector<WasmPastaFp>,
    auxiliary_input: WasmFlatVector<WasmPastaFp>,
    prev_challenges: WasmFlatVector<WasmPastaFp>,
    prev_sgs: WasmVector<WasmVestaGAffine>,
) -> Result<WasmPastaFpProverProof, JsValue> {
    // TODO: Should we be ignoring this?!
    let _primary_input = primary_input;

    let prev: Vec<(Vec<Fp>, PolyComm<GAffine>)> = {
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

    let auxiliary_input: Vec<Fp> = auxiliary_input.into_iter().map(Into::into).collect();
    let index: &DlogIndex<GAffine> = &index.0;

    let map = GroupMap::<Fq>::setup();
    DlogProof::create::<
        DefaultFqSponge<VestaParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fp, PlonkSpongeConstants>,
    >(&map, &auxiliary_input, &index, prev)
    .map_err(|err| {
        let str =
            match err {
                oracle::rndoracle::ProofError::WitnessCsInconsistent => "caml_pasta_fp_plonk_proof_create: WitnessCsInconsistent",
                oracle::rndoracle::ProofError::DomainCreation => "caml_pasta_fp_plonk_proof_create: DomainCreation",
                oracle::rndoracle::ProofError::PolyDivision => "caml_pasta_fp_plonk_proof_create: PolyDivision",
                oracle::rndoracle::ProofError::PolyCommit => "caml_pasta_fp_plonk_proof_create: PolyCommit",
                oracle::rndoracle::ProofError::PolyCommitWithBound => "caml_pasta_fp_plonk_proof_create: PolyCommitWithBound",
                oracle::rndoracle::ProofError::PolyExponentiate => "caml_pasta_fp_plonk_proof_create: PolyExponentiate",
                oracle::rndoracle::ProofError::ProofCreation => "caml_pasta_fp_plonk_proof_create: ProofCreation",
                oracle::rndoracle::ProofError::ProofVerification => "caml_pasta_fp_plonk_proof_create: ProofVerification",
                oracle::rndoracle::ProofError::OpenProof => "caml_pasta_fp_plonk_proof_create: OpenProof",
                oracle::rndoracle::ProofError::SumCheck => "caml_pasta_fp_plonk_proof_create: SumCheck",
                oracle::rndoracle::ProofError::ConstraintInconsist => "caml_pasta_fp_plonk_proof_create: ConstraintInconsist",
                oracle::rndoracle::ProofError::EvaluationGroup => "caml_pasta_fp_plonk_proof_create: EvaluationGroup",
                oracle::rndoracle::ProofError::OracleCommit => "caml_pasta_fp_plonk_proof_create: OracleCommit",
                oracle::rndoracle::ProofError::RuntimeEnv => "caml_pasta_fp_plonk_proof_create: RuntimeEnv",
                oracle::rndoracle::ProofError::BadMultiScalarMul => "caml_pasta_fp_plonk_proof_create: BadMultiScalarMul",
                oracle::rndoracle::ProofError::BadSrsLength => "caml_pasta_fp_plonk_proof_create: BadSrsLength",
            };
        JsValue::from_str(str)
    })
    .map(Into::into)
}

pub fn proof_verify(
    lgr_comm: WasmVector<WasmPastaVestaPolyComm>,
    index: WasmPastaFpPlonkVerifierIndex,
    proof: WasmPastaFpProverProof,
) -> bool {
    let group_map = <GAffine as CommitmentCurve>::Map::setup();

    DlogProof::verify::<
        DefaultFqSponge<VestaParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fp, PlonkSpongeConstants>,
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
pub fn caml_pasta_fp_plonk_proof_verify(
    lgr_comm: WasmVector<WasmPastaVestaPolyComm>,
    index: WasmPastaFpPlonkVerifierIndex,
    proof: WasmPastaFpProverProof,
) -> bool {
    proof_verify(lgr_comm, index, proof)
}

#[wasm_bindgen]
pub struct WasmVecVecVestaPolyComm(Vec<Vec<PolyComm<GAffine>>>);

#[wasm_bindgen]
impl WasmVecVecVestaPolyComm {
    #[wasm_bindgen(constructor)]
    pub fn create(n: i32) -> Self {
        WasmVecVecVestaPolyComm(Vec::with_capacity(n as usize))
    }

    #[wasm_bindgen]
    pub fn push(&mut self, x: WasmVector<WasmPastaVestaPolyComm>) {
        self.0.push(x.into_iter().map(Into::into).collect())
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_proof_batch_verify(
    lgr_comms: WasmVecVecVestaPolyComm,
    indexes: WasmVector<WasmPastaFpPlonkVerifierIndex>,
    proofs: WasmVector<WasmPastaFpProverProof>,
) -> bool {
    let ts: Vec<_> = indexes
        .into_iter()
        .zip(lgr_comms.0.into_iter())
        .zip(proofs.into_iter())
        .map(|((i, l), p)| (i.into(), l.into_iter().map(From::from).collect(), p.into()))
        .collect();
    let ts: Vec<_> = ts.iter().map(|(i, l, p)| (i, l, p)).collect();
    let group_map = GroupMap::<Fq>::setup();

    DlogProof::<GAffine>::verify::<
        DefaultFqSponge<VestaParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fp, PlonkSpongeConstants>,
    >(&group_map, &ts)
    .is_ok()
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_proof_dummy() -> WasmPastaFpProverProof {
    let g = || GAffine::prime_subgroup_generator();
    let comm = || PolyComm {
        shifted: Some(g()),
        unshifted: vec![g(), g(), g()],
    };
    (DlogProof {
        prev_challenges: vec![
            (vec![Fp::one(), Fp::one()], comm()),
            (vec![Fp::one(), Fp::one()], comm()),
            (vec![Fp::one(), Fp::one()], comm()),
        ],
        proof: OpeningProof {
            lr: vec![(g(), g()), (g(), g()), (g(), g())],
            z1: Fp::one(),
            z2: Fp::one(),
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
        public: vec![Fp::one(), Fp::one()],
        evals: {
            let evals = || vec![Fp::one(), Fp::one(), Fp::one(), Fp::one()];
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
pub fn caml_pasta_fp_plonk_proof_deep_copy(x: WasmPastaFpProverProof) -> WasmPastaFpProverProof {
    x
}
