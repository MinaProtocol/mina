use crate::common::*;
use algebra::{
    tweedle::{
        dee::{Affine as GAffine, TweedledeeParameters},
        fp::Fp,
    },
};

use plonk_circuits::scalars::{ProofEvaluations as DlogProofEvaluations};
use plonk_circuits::constraints::ConstraintSystem;

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

// Fp index stubs
#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_index_domain_d1_size<'a>(
    i: *const DlogIndex<'a, GAffine>,
) -> usize {
    (unsafe { &*i }).cs.domain.d1.size()
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_index_domain_d4_size<'a>(
    i: *const DlogIndex<'a, GAffine>,
) -> usize {
    (unsafe { &*i }).cs.domain.d4.size()
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_index_domain_d8_size<'a>(
    i: *const DlogIndex<'a, GAffine>,
) -> usize {
    (unsafe { &*i }).cs.domain.d8.size()
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_index_create<'a>(
    cs: *mut ConstraintSystem<Fp>,
    max_poly_size: usize,
    srs: *mut SRS<GAffine>,
) -> *mut DlogIndex<'a, GAffine> {
    let cs = unsafe { &*cs };
    let srs = unsafe { &*srs };

    return Box::into_raw(Box::new(
        DlogIndex::<GAffine>::create(
            cs.clone(),
            max_poly_size,
            oracle::tweedle::fp::params(),
            oracle::tweedle::fq::params(),
            SRSSpec::Use(srs),
        )
    ));
}
#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_index_delete(x: *mut DlogIndex<GAffine>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_index_max_degree(index: *const DlogIndex<GAffine>) -> usize {
    let index = unsafe { &*index };
    index.srs.get_ref().max_degree()
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_index_public_inputs(index: *const DlogIndex<GAffine>) -> usize {
    let index = unsafe { &*index };
    index.cs.public
}

/*
#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_index_write<'a>(
    index: *const DlogIndex<'a, GAffine>,
    path: *const c_char,
) {
    // TODO
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_index_read<'a>(
    path: *const c_char,
) -> *const DlogIndex<'a, GAffine> {
    // TODO
}
*/

// Fp verifier index stubs
#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_create(
    index: *const DlogIndex<GAffine>,
) -> *const DlogVerifierIndex<GAffine> {
    Box::into_raw(Box::new(unsafe { &(*index) }.verifier_index()))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_urs<'a>(
    index: *const DlogVerifierIndex<'a, GAffine>,
) -> *const SRS<GAffine> {
    let index = unsafe { &*index };
    let urs = index.srs.get_ref().clone();
    Box::into_raw(Box::new(urs))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_make<'a>(
    domain: *const Domain<Fp>,
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
    r: *const Fp,
    o: *const Fp,
) -> *const DlogVerifierIndex<'a, GAffine> {
    let srs = unsafe { &*urs };
    let index = DlogVerifierIndex::<GAffine> {
        domain: Domain<Fp>::new(max_poly_size),
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
        fr_sponge_params: oracle::tweedle::fp::params(),
        fq_sponge_params: oracle::tweedle::fq::params(),
    };
    Box::into_raw(Box::new(index))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_delete(x: *mut DlogVerifierIndex<GAffine>) {
    let _box = unsafe { Box::from_raw(x) };
}

/*
#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_write<'a>(
    index: *const DlogVerifierIndex<GAffine>,
    path: *const c_char,
) {
    // TODO
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_read<'a>(
    path: *const c_char,
) -> *const DlogVerifierIndex<'a, GAffine> {
    // TODO
}
*/

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_sigma_comm_0(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).sigma_comm[0] }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_sigma_comm_1(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).sigma_comm[1] }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_sigma_comm_2(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).sigma_comm[2] }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_ql_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).ql_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_qr_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).qr_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_qo_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).qo_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_qm_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).qm_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_qc_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).qc_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_rcm_comm_0(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).rcm_comm[0] }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_rcm_comm_1(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).rcm_comm[1] }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_rcm_comm_2(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).rcm_comm[2] }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_psm_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).psm_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_add_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).add_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_mul1_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).mul1_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_mul2_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).mul2_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_emul1_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).emul1_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_emul2_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).emul2_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_emul3_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).emul3_comm }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_r(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const Fp {
    Box::into_raw(Box::new(
        (unsafe { &(*index).r }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_verifier_index_o(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const Fp {
    Box::into_raw(Box::new(
        (unsafe { &(*index).o }).clone(),
    ))
}

// Fp proof
#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_create(
    index: *const DlogIndex<GAffine>,
    primary_input: *const Vec<Fp>,
    auxiliary_input: *const Vec<Fp>,
) -> *const DlogProof<GAffine> {
    let index = unsafe { &(*index) };
    let primary_input = unsafe { &(*primary_input) };
    let auxiliary_input = unsafe { &(*auxiliary_input) };

    let witness = prepare_plonk_witness(primary_input, auxiliary_input);

    let map = <GAffine as CommitmentCurve>::Map::setup();
    let proof = DlogProof::create::<DefaultFqSponge<TweedledeeParameters, PlonkSpongeConstants>, DefaultFrSponge<Fp, PlonkSpongeConstants>>(
        &map, &witness, &index,
    )
    .unwrap();

    return Box::into_raw(Box::new(proof));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_verify(
    index: *const DlogVerifierIndex<GAffine>,
    proof: *const DlogProof<GAffine>,
) -> bool {
    let index = unsafe { &(*index) };
    let proof = unsafe { (*proof).clone() };
    let group_map = <GAffine as CommitmentCurve>::Map::setup();

    DlogProof::verify::<DefaultFqSponge<TweedledeeParameters, PlonkSpongeConstants>, DefaultFrSponge<Fp, PlonkSpongeConstants>>(
        &group_map,
        &[proof].to_vec(),
        &index,
    ).is_ok()
}

// TODO: Batch verify across different indexes
#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_batch_verify(
    index: *const DlogVerifierIndex<GAffine>,
    proofs: *const Vec<DlogProof<GAffine>>,
) -> bool {
    let index = unsafe { &(*index) };
    let proofs = unsafe { &(*proofs) };
    let group_map = <GAffine as CommitmentCurve>::Map::setup();

    DlogProof::<GAffine>::verify::<DefaultFqSponge<TweedledeeParameters, PlonkSpongeConstants>, DefaultFrSponge<Fp, PlonkSpongeConstants>>(
        &group_map,
        proofs,
        index,
    ).is_ok()
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_make(
    primary_input: *const Vec<Fp>,

    l_comm: *const PolyComm<GAffine>,
    r_comm: *const PolyComm<GAffine>,
    o_comm: *const PolyComm<GAffine>,
    z_comm: *const PolyComm<GAffine>,
    t_comm: *const PolyComm<GAffine>,

    lr: *const Vec<(GAffine, GAffine)>,
    z1: *const Fp,
    z2: *const Fp,
    delta: *const GAffine,
    sg: *const GAffine,

    evals0: *const DlogProofEvaluations<Vec<Fp>>,
    evals1: *const DlogProofEvaluations<Vec<Fp>>,
) -> *const DlogProof<GAffine> {
    let public = unsafe { &(*primary_input) }.clone();
    // public.resize(ceil_pow2(public.len()), Fp::zero());

    let res = DlogProof {
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
pub extern "C" fn zexe_tweedle_plonk_fp_proof_delete(x: *mut DlogProof<GAffine>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_l_comm(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &((*p).l_comm) }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_r_comm(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &((*p).r_comm) }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_o_comm(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &((*p).o_comm) }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_z_comm(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &((*p).z_comm) }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_t_comm(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &((*p).t_comm) }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_proof(
    p: *mut DlogProof<GAffine>,
) -> *const OpeningProof<GAffine> {
    let x = (unsafe { &(*p).proof }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_evals_nocopy(
    p: *mut DlogProof<GAffine>,
) -> *const [DlogProofEvaluations<Vec<Fp>>; 2] {
    let x = (unsafe { &(*p).evals }).clone();
    return Box::into_raw(Box::new(x));
}

// Fp proof vector

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_vector_create() -> *mut Vec<DlogProof<GAffine>> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_vector_length(v: *const Vec<DlogProof<GAffine>>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_vector_emplace_back(
    v: *mut Vec<DlogProof<GAffine>>,
    x: *const DlogProof<GAffine>,
) {
    let v_ = unsafe { &mut (*v) };
    let x_ = unsafe { &(*x) };
    v_.push(x_.clone());
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_vector_get(
    v: *mut Vec<DlogProof<GAffine>>,
    i: u32,
) -> *mut DlogProof<GAffine> {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new((*v_)[i as usize].clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_vector_delete(v: *mut Vec<DlogProof<GAffine>>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

// Fp opening proof
#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_opening_proof_delete(p: *mut OpeningProof<GAffine>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(p) };
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_opening_proof_sg(
    p: *const OpeningProof<GAffine>,
) -> *const GAffine {
    let x = (unsafe { &(*p).sg }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_opening_proof_lr(
    p: *const OpeningProof<GAffine>,
) -> *const Vec<(GAffine, GAffine)> {
    let x = (unsafe { &(*p).lr }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_opening_proof_z1(p: *const OpeningProof<GAffine>) -> *const Fp {
    let x = (unsafe { &(*p).z1 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_opening_proof_z2(p: *const OpeningProof<GAffine>) -> *const Fp {
    let x = (unsafe { &(*p).z2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_opening_proof_delta(
    p: *const OpeningProof<GAffine>,
) -> *const GAffine {
    let x = (unsafe { &(*p).delta }).clone();
    return Box::into_raw(Box::new(x));
}

// Fp proof evaluations

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_evaluations_l(
    e: *const DlogProofEvaluations<Fp>,
) -> *const Fp {
    let x = (unsafe { &(*e).l }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_evaluations_r(
    e: *const DlogProofEvaluations<Fp>,
) -> *const Fp {
    let x = (unsafe { &(*e).r }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_evaluations_o(
    e: *const DlogProofEvaluations<Fp>,
) -> *const Fp {
    let x = (unsafe { &(*e).o }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_evaluations_z(
    e: *const DlogProofEvaluations<Fp>,
) -> *const Fp {
    let x = (unsafe { &(*e).z }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_evaluations_t(
    e: *const DlogProofEvaluations<Fp>,
) -> *const Fp {
    let x = (unsafe { &(*e).t }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_evaluations_f(
    e: *const DlogProofEvaluations<Fp>,
) -> *const Fp {
    let x = (unsafe { &(*e).f }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_evaluations_sigma1(
    e: *const DlogProofEvaluations<Fp>,
) -> *const Fp {
    let x = (unsafe { &(*e).sigma1 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_evaluations_sigma2(
    e: *const DlogProofEvaluations<Fp>,
) -> *const Fp {
    let x = (unsafe { &(*e).sigma2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_evaluations_make(
    l: *const Fp,
    r: *const Fp,
    o: *const Fp,
    z: *const Fp,
    t: *const Fp,
    f: *const Fp,
    sigma1: *const Fp,
    sigma2: *const Fp,
) -> *const DlogProofEvaluations<Fp> {
    let res: DlogProofEvaluations<Fp> = DlogProofEvaluations {
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
pub extern "C" fn zexe_tweedle_plonk_fp_proof_evaluations_pair_0(
    e: *const [DlogProofEvaluations<Fp>; 2],
) -> *const DlogProofEvaluations<Fp> {
    let x = (unsafe { &(*e)[0] }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_proof_evaluations_pair_1(
    e: *const [DlogProofEvaluations<Fp>; 2],
) -> *const DlogProofEvaluations<Fp> {
    let x = (unsafe { &(*e)[1] }).clone();
    return Box::into_raw(Box::new(x));
}

// Fp oracles
pub struct FpOracles {
    o: plonk_circuits::scalars::RandomOracles<Fp>,
    p_eval: [Vec<Fp>; 2],
    opening_prechallenges: Vec<ScalarChallenge<Fp>>,
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_oracles_create(
    index: *const DlogVerifierIndex<GAffine>,
    proof: *const DlogProof<GAffine>,
) -> *const FpOracles {
    let index = unsafe { &(*index) };
    let proof = unsafe { &(*proof) };

    let p_comm = PolyComm::<GAffine>::multi_scalar_mul
      (&index.srs.get_ref().lgr_comm.iter().map(|l| l).collect(), &proof.public.iter().map(|s| -*s).collect());
    let mut p_eval = [Vec::<Fp>::new(), Vec::<Fp>::new()];

    let (mut sponge, mut o) = proof.setup_oracles::<DefaultFqSponge<TweedledeeParameters, PlonkSpongeConstants>, DefaultFrSponge<Fp, PlonkSpongeConstants>>(index, &p_comm);
    let cached_values = DlogProof::gen_cached_values(index, &o);
    proof.p_eval(index, &o, &cached_values, &mut p_eval);
    proof.finalize_oracles::<DefaultFqSponge<TweedledeeParameters, PlonkSpongeConstants>, DefaultFrSponge<Fp, PlonkSpongeConstants>>(index, &p_eval, &mut sponge, &mut o);

    let opening_prechallenges = proof.proof.prechallenges(&mut sponge);

    return Box::into_raw(Box::new(FpOracles {
        o,
        p_eval: p_eval,
        opening_prechallenges,
    }));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_oracles_opening_prechallenges(
    oracles: *const FpOracles,
) -> *const Vec<Fp> {
    return Box::into_raw(Box::new(
        (unsafe { &(*oracles) })
            .opening_prechallenges
            .iter()
            .map(|x| x.0)
            .collect(),
    ));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_oracles_p_eval1(oracles: *const FpOracles) -> *const Vec<Fp> {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).p_eval[0].clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_oracles_p_eval2(oracles: *const FpOracles) -> *const Vec<Fp> {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).p_eval[1].clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_oracles_alpha(oracles: *const FpOracles) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.alpha.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_oracles_beta(oracles: *const FpOracles) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.beta.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_oracles_gamma(oracles: *const FpOracles) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.gamma.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_oracles_zeta(oracles: *const FpOracles) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.zeta.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_oracles_v(oracles: *const FpOracles) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.v.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_oracles_u(oracles: *const FpOracles) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.u.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_plonk_fp_oracles_delete(x: *mut FpOracles) {
    let _box = unsafe { Box::from_raw(x) };
}
