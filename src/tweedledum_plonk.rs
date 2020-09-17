use crate::common::*;
use algebra::{
    tweedle::{
        dum::{Affine as GAffine, TweedledumParameters},
        fq::Fq,
    },
};

use plonk_circuits::scalars::{ProofEvaluations as DlogProofEvaluations};
use plonk_circuits::constraints::ConstraintSystem;
use plonk_circuits::gate::{CircuitGate, Gate, GateType, GateType::{*}};
use plonk_circuits::wires::{GateWires, Wire, Wires, Col};

use ff_fft::{EvaluationDomain, Radix2EvaluationDomain as Domain};

use oracle::{
    self,
    sponge::{DefaultFqSponge, DefaultFrSponge, ScalarChallenge},
    poseidon::{PlonkSpongeConstants},
};

use groupmap::GroupMap;

use plonk_protocol_dlog::index::{
    Index as DlogIndex, SRSSpec, SRSValue, VerifierIndex as DlogVerifierIndex,
};
use commitment_dlog::{
    commitment::{CommitmentCurve, OpeningProof, PolyComm},
    srs::SRS,
};
use plonk_protocol_dlog::prover::{ProverProof as DlogProof};

// Fq index stubs
#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_index_domain_d1_size<'a>(
    i: *const DlogIndex<'a, GAffine>,
) -> usize {
    (unsafe { &*i }).cs.domain.d1.size()
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_index_domain_d4_size<'a>(
    i: *const DlogIndex<'a, GAffine>,
) -> usize {
    (unsafe { &*i }).cs.domain.d4.size()
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_index_domain_d8_size<'a>(
    i: *const DlogIndex<'a, GAffine>,
) -> usize {
    (unsafe { &*i }).cs.domain.d8.size()
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_index_create<'a>(
    gates: *const Vec<Gate<Fq>>,
    max_poly_size: usize,
    srs: *mut SRS<GAffine>,
) -> *mut DlogIndex<'a, GAffine> {
    let gates = unsafe { &*gates };
    let srs = unsafe { &*srs };

    let n = Domain::<Fq>::compute_size_of_domain(gates.len()).unwrap();
    let gates = gates.iter().map
    (
        |gate|
        CircuitGate
        {
            typ: gate.typ.clone(),
            wires: GateWires
            {
                l: (gate.wires.row, gate.wires.row),
                r: (gate.wires.row + n, gate.wires.row),
                o: (gate.wires.row + 2*n, gate.wires.row),
            },
            c: gate.c.clone()
        }
    ).collect();

    return Box::into_raw(Box::new(
        DlogIndex::<GAffine>::create(
            ConstraintSystem::<Fq>::create(gates, oracle::tweedle::fq::params(), 0).unwrap(),
            max_poly_size,
            oracle::tweedle::fp::params(),
            SRSSpec::Use(srs),
        )
    ));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_index_delete(x: *mut DlogIndex<GAffine>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_index_max_degree(index: *const DlogIndex<GAffine>) -> usize {
    let index = unsafe { &*index };
    index.srs.get_ref().max_degree()
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_index_public_inputs(index: *const DlogIndex<GAffine>) -> usize {
    let index = unsafe { &*index };
    index.cs.public
}

/*
#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_index_write<'a>(
    index: *const DlogIndex<'a, GAffine>,
    path: *const c_char,
) {
    // TODO
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_index_read<'a>(
    path: *const c_char,
) -> *const DlogIndex<'a, GAffine> {
    // TODO
}
*/

// Fq verifier index stubs
#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_create(
    index: *const DlogIndex<GAffine>,
) -> *const DlogVerifierIndex<GAffine> {
    Box::into_raw(Box::new(unsafe { &(*index) }.verifier_index()))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_urs<'a>(
    index: *const DlogVerifierIndex<'a, GAffine>,
) -> *const SRS<GAffine> {
    let index = unsafe { &*index };
    let urs = index.srs.get_ref().clone();
    Box::into_raw(Box::new(urs))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_make<'a>(
    max_poly_size: usize,
    max_quot_size: usize,
    urs: *const SRS<GAffine>,
    sigma_comm0: *const PolyComm<GAffine>,
    sigma_comm1: *const PolyComm<GAffine>,
    sigma_comm2: *const PolyComm<GAffine>,
    ql_comm: *const PolyComm<GAffine>,
    qr_comm: *const PolyComm<GAffine>,
    qo_comm: *const PolyComm<GAffine>,
    qm_comm: *const PolyComm<GAffine>,
    qc_comm: *const PolyComm<GAffine>,
    rcm_comm0: *const PolyComm<GAffine>,
    rcm_comm1: *const PolyComm<GAffine>,
    rcm_comm2: *const PolyComm<GAffine>,
    psm_comm: *const PolyComm<GAffine>,
    add_comm: *const PolyComm<GAffine>,
    mul1_comm: *const PolyComm<GAffine>,
    mul2_comm: *const PolyComm<GAffine>,
    emul1_comm: *const PolyComm<GAffine>,
    emul2_comm: *const PolyComm<GAffine>,
    emul3_comm: *const PolyComm<GAffine>,
    r: *const Fq,
    o: *const Fq,
) -> *const DlogVerifierIndex<'a, GAffine> {
    let srs = unsafe { &*urs };
    let index = DlogVerifierIndex::<GAffine> {
        domain: Domain::<Fq>::new(max_poly_size).unwrap(),
        max_poly_size,
        max_quot_size,
        srs: SRSValue::Ref(srs),
        sigma_comm: [
            (unsafe { &*sigma_comm0 }).clone(),
            (unsafe { &*sigma_comm1 }).clone(),
            (unsafe { &*sigma_comm2 }).clone(),
        ],
        ql_comm: (unsafe { &*ql_comm }).clone(),
        qr_comm: (unsafe { &*qr_comm }).clone(),
        qo_comm: (unsafe { &*qo_comm }).clone(),
        qm_comm: (unsafe { &*qm_comm }).clone(),
        qc_comm: (unsafe { &*qc_comm }).clone(),
        rcm_comm: [
            (unsafe { &*rcm_comm0 }).clone(),
            (unsafe { &*rcm_comm1 }).clone(),
            (unsafe { &*rcm_comm2 }).clone(),
        ],
        psm_comm: (unsafe { &*psm_comm }).clone(),
        add_comm: (unsafe { &*add_comm }).clone(),
        mul1_comm: (unsafe { &*mul1_comm }).clone(),
        mul2_comm: (unsafe { &*mul2_comm }).clone(),
        emul1_comm: (unsafe { &*emul1_comm }).clone(),
        emul2_comm: (unsafe { &*emul2_comm }).clone(),
        emul3_comm: (unsafe { &*emul3_comm }).clone(),
        r: (unsafe { &*r }).clone(),
        o: (unsafe { &*o }).clone(),
        fq_sponge_params: oracle::tweedle::fp::params(),
        fr_sponge_params: oracle::tweedle::fq::params(),
    };
    Box::into_raw(Box::new(index))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_delete(x: *mut DlogVerifierIndex<GAffine>) {
    let _box = unsafe { Box::from_raw(x) };
}

/*
#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_write<'a>(
    index: *const DlogVerifierIndex<GAffine>,
    path: *const c_char,
) {
    // TODO
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_read<'a>(
    path: *const c_char,
) -> *const DlogVerifierIndex<'a, GAffine> {
    // TODO
}
*/

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_sigma_comm_0(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).sigma_comm[0] }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_sigma_comm_1(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).sigma_comm[1] }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_sigma_comm_2(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).sigma_comm[2] }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_ql_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).ql_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_qr_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).qr_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_qo_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).qo_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_qm_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).qm_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_qc_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).qc_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_rcm_comm_0(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).rcm_comm[0] }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_rcm_comm_1(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).rcm_comm[1] }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_rcm_comm_2(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).rcm_comm[2] }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_psm_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).psm_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_add_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).add_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_mul1_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).mul1_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_mul2_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).mul2_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_emul1_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).emul1_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_emul2_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).emul2_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_emul3_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).emul3_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_r(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const Fq {
    Box::into_raw(Box::new(
        (unsafe { &(*index).r }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_verifier_index_o(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const Fq {
    Box::into_raw(Box::new(
        (unsafe { &(*index).o }).clone(),
    ))
}

// Fq proof
#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_create(
    index: *const DlogIndex<GAffine>,
    primary_input: *const Vec<Fq>,
    auxiliary_input: *const Vec<Fq>,
    prev_challenges: *const Vec<Fq>,
    prev_sgs: *const Vec<GAffine>,
) -> *const DlogProof<GAffine> {
    let index = unsafe { &(*index) };
    let primary_input = unsafe { &(*primary_input) };
    let auxiliary_input = unsafe { &(*auxiliary_input) };

    let witness = prepare_plonk_witness(primary_input, auxiliary_input);

    let prev: Vec<(Vec<Fq>, PolyComm<GAffine>)> = {
        let prev_challenges = unsafe { &*prev_challenges };
        let prev_sgs = unsafe { &*prev_sgs };
        if prev_challenges.len() == 0 {
            Vec::new()
        } else {
            let challenges_per_sg = prev_challenges.len() / prev_sgs.len();
            prev_sgs
                .iter()
                .enumerate()
                .map(|(i, sg)| {
                    (
                        prev_challenges[(i * challenges_per_sg)..(i + 1) * challenges_per_sg]
                            .iter()
                            .map(|x| *x)
                            .collect(),
                        PolyComm::<GAffine> {
                            unshifted: vec![sg.clone()],
                            shifted: None,
                        },
                    )
                })
                .collect()
        }
    };

    let map = <GAffine as CommitmentCurve>::Map::setup();
    let proof = DlogProof::create::<DefaultFqSponge<TweedledumParameters, PlonkSpongeConstants>, DefaultFrSponge<Fq, PlonkSpongeConstants>>(
        &map, &witness, &index, prev,
    )
    .unwrap();

    return Box::into_raw(Box::new(proof));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_verify(
    index: *const DlogVerifierIndex<GAffine>,
    proof: *const DlogProof<GAffine>,
) -> bool {
    let index = unsafe { &(*index) };
    let proof = unsafe { (*proof).clone() };
    let group_map = <GAffine as CommitmentCurve>::Map::setup();

    DlogProof::verify::<DefaultFqSponge<TweedledumParameters, PlonkSpongeConstants>, DefaultFrSponge<Fq, PlonkSpongeConstants>>(
        &group_map,
        &[proof].to_vec(),
        &index,
    ).is_ok()
}

// TODO: Batch verify across different indexes
#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_batch_verify(
    index: *const DlogVerifierIndex<GAffine>,
    proofs: *const Vec<DlogProof<GAffine>>,
) -> bool {
    let index = unsafe { &(*index) };
    let proofs = unsafe { &(*proofs) };
    let group_map = <GAffine as CommitmentCurve>::Map::setup();

    DlogProof::<GAffine>::verify::<DefaultFqSponge<TweedledumParameters, PlonkSpongeConstants>, DefaultFrSponge<Fq, PlonkSpongeConstants>>(
        &group_map,
        proofs,
        index,
    ).is_ok()
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_make(
    primary_input: *const Vec<Fq>,

    l_comm: *const PolyComm<GAffine>,
    r_comm: *const PolyComm<GAffine>,
    o_comm: *const PolyComm<GAffine>,
    z_comm: *const PolyComm<GAffine>,
    t_comm: *const PolyComm<GAffine>,

    lr: *const Vec<(GAffine, GAffine)>,
    z1: *const Fq,
    z2: *const Fq,
    delta: *const GAffine,
    sg: *const GAffine,

    evals0: *const DlogProofEvaluations<Vec<Fq>>,
    evals1: *const DlogProofEvaluations<Vec<Fq>>,

    prev_challenges: *const Vec<Fq>,
    prev_sgs: *const Vec<GAffine>,
) -> *const DlogProof<GAffine> {
    let public = unsafe { &(*primary_input) }.clone();
    // public.resize(ceil_pow2(public.len()), Fq::zero());

    let prev: Vec<(Vec<Fq>, PolyComm<GAffine>)> = {
        let prev_challenges = unsafe { &*prev_challenges };
        let prev_sgs = unsafe { &*prev_sgs };
        if prev_challenges.len() == 0 {
            Vec::new()
        } else {
            let challenges_per_sg = prev_challenges.len() / prev_sgs.len();
            prev_sgs
                .iter()
                .enumerate()
                .map(|(i, sg)| {
                    (
                        prev_challenges[(i * challenges_per_sg)..(i + 1) * challenges_per_sg]
                            .iter()
                            .map(|x| *x)
                            .collect(),
                        PolyComm::<GAffine> {
                            unshifted: vec![sg.clone()],
                            shifted: None,
                        },
                    )
                })
                .collect()
        }
    };

    let res = DlogProof {
        prev_challenges: prev,
        proof: OpeningProof {
            lr: (unsafe { &*lr }).clone(),
            z1: (unsafe { *z1 }).clone(),
            z2: (unsafe { *z2 }).clone(),
            delta: (unsafe { *delta }).clone(),
            sg: (unsafe { *sg }).clone(),
        },
        l_comm: (unsafe { &*l_comm }).clone(),
        r_comm: (unsafe { &*r_comm }).clone(),
        o_comm: (unsafe { &*o_comm }).clone(),
        z_comm: (unsafe { &*z_comm }).clone(),
        t_comm: (unsafe { &*t_comm }).clone(),

        public,
        evals: [
            (unsafe { &*evals0 }).clone(),
            (unsafe { &*evals1 }).clone(),
        ],
    };
    return Box::into_raw(Box::new(res));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_delete(x: *mut DlogProof<GAffine>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_l_comm(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &((*p).l_comm) }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_r_comm(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &((*p).r_comm) }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_o_comm(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &((*p).o_comm) }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_z_comm(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &((*p).z_comm) }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_t_comm(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &((*p).t_comm) }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_proof(
    p: *mut DlogProof<GAffine>,
) -> *const OpeningProof<GAffine> {
    let x = (unsafe { &(*p).proof }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_evals_nocopy(
    p: *mut DlogProof<GAffine>,
) -> *const [DlogProofEvaluations<Vec<Fq>>; 2] {
    let x = (unsafe { &(*p).evals }).clone();
    return Box::into_raw(Box::new(x));
}

// Fq proof vector

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_vector_create() -> *mut Vec<DlogProof<GAffine>> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_vector_length(v: *const Vec<DlogProof<GAffine>>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_vector_emplace_back(
    v: *mut Vec<DlogProof<GAffine>>,
    x: *const DlogProof<GAffine>,
) {
    let v_ = unsafe { &mut (*v) };
    let x_ = unsafe { &(*x) };
    v_.push(x_.clone());
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_vector_get(
    v: *mut Vec<DlogProof<GAffine>>,
    i: u32,
) -> *mut DlogProof<GAffine> {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new((*v_)[i as usize].clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_vector_delete(v: *mut Vec<DlogProof<GAffine>>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

// Fq opening proof
#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_opening_proof_delete(p: *mut OpeningProof<GAffine>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(p) };
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_opening_proof_sg(
    p: *const OpeningProof<GAffine>,
) -> *const GAffine {
    let x = (unsafe { &(*p).sg }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_opening_proof_lr(
    p: *const OpeningProof<GAffine>,
) -> *const Vec<(GAffine, GAffine)> {
    let x = (unsafe { &(*p).lr }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_opening_proof_z1(p: *const OpeningProof<GAffine>) -> *const Fq {
    let x = (unsafe { &(*p).z1 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_opening_proof_z2(p: *const OpeningProof<GAffine>) -> *const Fq {
    let x = (unsafe { &(*p).z2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_opening_proof_delta(
    p: *const OpeningProof<GAffine>,
) -> *const GAffine {
    let x = (unsafe { &(*p).delta }).clone();
    return Box::into_raw(Box::new(x));
}

// Fq proof evaluations

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_evaluations_l(
    e: *const DlogProofEvaluations<Vec<Fq>>,
) -> *const Vec<Fq> {
    let x = (unsafe { &(*e).l }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_evaluations_r(
    e: *const DlogProofEvaluations<Vec<Fq>>,
) -> *const Vec<Fq> {
    let x = (unsafe { &(*e).r }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_evaluations_o(
    e: *const DlogProofEvaluations<Vec<Fq>>,
) -> *const Vec<Fq> {
    let x = (unsafe { &(*e).o }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_evaluations_z(
    e: *const DlogProofEvaluations<Vec<Fq>>,
) -> *const Vec<Fq> {
    let x = (unsafe { &(*e).z }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_evaluations_t(
    e: *const DlogProofEvaluations<Vec<Fq>>,
) -> *const Vec<Fq> {
    let x = (unsafe { &(*e).t }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_evaluations_f(
    e: *const DlogProofEvaluations<Vec<Fq>>,
) -> *const Vec<Fq> {
    let x = (unsafe { &(*e).f }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_evaluations_sigma1(
    e: *const DlogProofEvaluations<Vec<Fq>>,
) -> *const Vec<Fq> {
    let x = (unsafe { &(*e).sigma1 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_evaluations_sigma2(
    e: *const DlogProofEvaluations<Vec<Fq>>,
) -> *const Vec<Fq> {
    let x = (unsafe { &(*e).sigma2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_evaluations_make(
    l: *const Vec<Fq>,
    r: *const Vec<Fq>,
    o: *const Vec<Fq>,
    z: *const Vec<Fq>,
    t: *const Vec<Fq>,
    f: *const Vec<Fq>,
    sigma1: *const Vec<Fq>,
    sigma2: *const Vec<Fq>,
) -> *const DlogProofEvaluations<Vec<Fq>> {
    let res: DlogProofEvaluations<Vec<Fq>> = DlogProofEvaluations {
        l: (unsafe { &*l }).clone(),
        r: (unsafe { &*r }).clone(),
        o: (unsafe { &*o }).clone(),
        z: (unsafe { &*z }).clone(),
        t: (unsafe { &*t }).clone(),
        f: (unsafe { &*f }).clone(),
        sigma1: (unsafe { &*sigma1 }).clone(),
        sigma2: (unsafe { &*sigma2 }).clone(),
    };

    return Box::into_raw(Box::new(res));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_evaluations_delete(x: *mut DlogProofEvaluations<Vec<Fq>>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_evaluations_pair_0(
    e: *const [DlogProofEvaluations<Vec<Fq>>; 2],
) -> *const DlogProofEvaluations<Vec<Fq>> {
    let x = (unsafe { &(*e)[0] }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_evaluations_pair_1(
    e: *const [DlogProofEvaluations<Vec<Fq>>; 2],
) -> *const DlogProofEvaluations<Vec<Fq>> {
    let x = (unsafe { &(*e)[1] }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_proof_evaluations_pair_delete(x: *mut [DlogProofEvaluations<Vec<Fq>>; 2]) {
    let _box = unsafe { Box::from_raw(x) };
}

// Fq oracles
pub struct FqOracles {
    o: plonk_circuits::scalars::RandomOracles<Fq>,
    p_eval: [Vec<Fq>; 2],
    opening_prechallenges: Vec<ScalarChallenge<Fq>>,
    digest_before_evaluations: Fq,
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_oracles_create(
    index: *const DlogVerifierIndex<GAffine>,
    proof: *const DlogProof<GAffine>,
) -> *const FqOracles {
    let index = unsafe { &(*index) };
    let proof = unsafe { &(*proof) };

    let p_comm = PolyComm::<GAffine>::multi_scalar_mul
      (&index.srs.get_ref().lgr_comm.iter().map(|l| l).collect(), &proof.public.iter().map(|s| -*s).collect());
    let (mut sponge, digest_before_evaluations, o, _, p_eval, _, _) =
        proof.oracles::<DefaultFqSponge<TweedledumParameters, PlonkSpongeConstants>, DefaultFrSponge<Fq, PlonkSpongeConstants>>(index, &p_comm);

    return Box::into_raw(Box::new(FqOracles {
        o,
        p_eval,
        opening_prechallenges: proof.proof.prechallenges(&mut sponge),
        digest_before_evaluations,
    }));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_oracles_opening_prechallenges(
    oracles: *const FqOracles,
) -> *const Vec<Fq> {
    return Box::into_raw(Box::new(
        (unsafe { &(*oracles) })
            .opening_prechallenges
            .iter()
            .map(|x| x.0)
            .collect(),
    ));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_oracles_digest_before_evaluations(
    oracles: *const FqOracles,
) -> *const Fq {
    return Box::into_raw(Box::new(
        (unsafe { &(*oracles) }).digest_before_evaluations.clone(),
    ));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_oracles_p_eval1(oracles: *const FqOracles) -> *const Vec<Fq> {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).p_eval[0].clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_oracles_p_eval2(oracles: *const FqOracles) -> *const Vec<Fq> {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).p_eval[1].clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_oracles_alpha(oracles: *const FqOracles) -> *const Fq {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.alpha.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_oracles_beta(oracles: *const FqOracles) -> *const Fq {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.beta.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_oracles_gamma(oracles: *const FqOracles) -> *const Fq {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.gamma.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_oracles_zeta(oracles: *const FqOracles) -> *const Fq {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.zeta.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_oracles_v(oracles: *const FqOracles) -> *const Fq {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.v.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_oracles_u(oracles: *const FqOracles) -> *const Fq {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.u.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_oracles_delete(x: *mut FqOracles) {
    let _box = unsafe { Box::from_raw(x) };
}

// Fq circuit gate vector
#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_gate_vector_create() -> *mut Vec<Gate<Fq>> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_gate_vector_length(v: *const Vec<Gate<Fq>>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_gate_vector_add(
    v: *mut Vec<Gate<Fq>>,
    typ: GateType,
    row: usize,
    lrow: usize,
    lcol: Col,
    rrow: usize,
    rcol: Col,
    orow: usize,
    ocol: Col,
    c: *const Vec<Fq>,
) {
    let v_ = unsafe { &mut (*v) };
    let c_ = unsafe { &(*c) };
    v_.push
    (
        Gate
        {
            typ,
            wires: Wires
            {
                row,
                l: Wire {row: lrow, col: lcol},
                r: Wire {row: rrow, col: rcol},
                o: Wire {row: orow, col: ocol},
            },
            c: c_.clone(),
        }
    )
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_gate_vector_add_zero(
    v: *mut Vec<Gate<Fq>>,
    row: usize,
    lrow: usize,
    lcol: Col,
    rrow: usize,
    rcol: Col,
    orow: usize,
    ocol: Col,
    c: *const Vec<Fq>,
) {
    zexe_tweedle_plonk_fq_gate_vector_add(v, Zero, row, lrow, lcol, rrow, rcol, orow, ocol, c);
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_gate_vector_add_generic(
    v: *mut Vec<Gate<Fq>>,
    row: usize,
    lrow: usize,
    lcol: Col,
    rrow: usize,
    rcol: Col,
    orow: usize,
    ocol: Col,
    c: *const Vec<Fq>,
) {
    zexe_tweedle_plonk_fq_gate_vector_add(v, Generic, row, lrow, lcol, rrow, rcol, orow, ocol, c);
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_gate_vector_add_poseidon(
    v: *mut Vec<Gate<Fq>>,
    row: usize,
    lrow: usize,
    lcol: Col,
    rrow: usize,
    rcol: Col,
    orow: usize,
    ocol: Col,
    c: *const Vec<Fq>,
) {
    zexe_tweedle_plonk_fq_gate_vector_add(v, Poseidon, row, lrow, lcol, rrow, rcol, orow, ocol, c);
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_gate_vector_add_add1(
    v: *mut Vec<Gate<Fq>>,
    row: usize,
    lrow: usize,
    lcol: Col,
    rrow: usize,
    rcol: Col,
    orow: usize,
    ocol: Col,
    c: *const Vec<Fq>,
) {
    zexe_tweedle_plonk_fq_gate_vector_add(v, Add1, row, lrow, lcol, rrow, rcol, orow, ocol, c);
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_gate_vector_add_add2(
    v: *mut Vec<Gate<Fq>>,
    row: usize,
    lrow: usize,
    lcol: Col,
    rrow: usize,
    rcol: Col,
    orow: usize,
    ocol: Col,
    c: *const Vec<Fq>,
) {
    zexe_tweedle_plonk_fq_gate_vector_add(v, Add2, row, lrow, lcol, rrow, rcol, orow, ocol, c);
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_gate_vector_add_vbmul1(
    v: *mut Vec<Gate<Fq>>,
    row: usize,
    lrow: usize,
    lcol: Col,
    rrow: usize,
    rcol: Col,
    orow: usize,
    ocol: Col,
    c: *const Vec<Fq>,
) {
    zexe_tweedle_plonk_fq_gate_vector_add(v, Vbmul1, row, lrow, lcol, rrow, rcol, orow, ocol, c);
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_gate_vector_add_vbmul2(
    v: *mut Vec<Gate<Fq>>,
    row: usize,
    lrow: usize,
    lcol: Col,
    rrow: usize,
    rcol: Col,
    orow: usize,
    ocol: Col,
    c: *const Vec<Fq>,
) {
    zexe_tweedle_plonk_fq_gate_vector_add(v, Vbmul2, row, lrow, lcol, rrow, rcol, orow, ocol, c);
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_gate_vector_add_vbmul3(
    v: *mut Vec<Gate<Fq>>,
    row: usize,
    lrow: usize,
    lcol: Col,
    rrow: usize,
    rcol: Col,
    orow: usize,
    ocol: Col,
    c: *const Vec<Fq>,
) {
    zexe_tweedle_plonk_fq_gate_vector_add(v, Vbmul3, row, lrow, lcol, rrow, rcol, orow, ocol, c);
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_gate_vector_add_endomul1(
    v: *mut Vec<Gate<Fq>>,
    row: usize,
    lrow: usize,
    lcol: Col,
    rrow: usize,
    rcol: Col,
    orow: usize,
    ocol: Col,
    c: *const Vec<Fq>,
) {
    zexe_tweedle_plonk_fq_gate_vector_add(v, Endomul1, row, lrow, lcol, rrow, rcol, orow, ocol, c);
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_gate_vector_add_endomul2(
    v: *mut Vec<Gate<Fq>>,
    row: usize,
    lrow: usize,
    lcol: Col,
    rrow: usize,
    rcol: Col,
    orow: usize,
    ocol: Col,
    c: *const Vec<Fq>,
) {
    zexe_tweedle_plonk_fq_gate_vector_add(v, Endomul2, row, lrow, lcol, rrow, rcol, orow, ocol, c);
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_gate_vector_add_endomul3(
    v: *mut Vec<Gate<Fq>>,
    row: usize,
    lrow: usize,
    lcol: Col,
    rrow: usize,
    rcol: Col,
    orow: usize,
    ocol: Col,
    c: *const Vec<Fq>,
) {
    zexe_tweedle_plonk_fq_gate_vector_add(v, Endomul3, row, lrow, lcol, rrow, rcol, orow, ocol, c);
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_gate_vector_add_endomul4(
    v: *mut Vec<Gate<Fq>>,
    row: usize,
    lrow: usize,
    lcol: Col,
    rrow: usize,
    rcol: Col,
    orow: usize,
    ocol: Col,
    c: *const Vec<Fq>,
) {
    zexe_tweedle_plonk_fq_gate_vector_add(v, Endomul4, row, lrow, lcol, rrow, rcol, orow, ocol, c);
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_gate_vector_delete(v: *mut Vec<CircuitGate<Fq>>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

// Fq constraint system
#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_constraint_system_create(v: *mut Vec<CircuitGate<Fq>>, public: usize) -> *mut ConstraintSystem<Fq> {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new(ConstraintSystem::<Fq>::create(v_.clone(), oracle::tweedle::fq::params(), public).unwrap()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fq_constraint_system_delete(v: *mut ConstraintSystem<Fq>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}
