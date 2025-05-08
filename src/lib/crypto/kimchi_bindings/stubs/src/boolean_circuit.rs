use ark_ff::{Field, Zero};
use ark_poly::{
    univariate::DensePolynomial, EvaluationDomain, Evaluations, Polynomial, Radix2EvaluationDomain,
};
use kimchi::mina_poseidon::FqSponge;
use kimchi::plonk_sponge::FrSponge;
use kimchi::{
    circuits::domains::EvaluationDomains,
    curve::KimchiCurve,
    mina_poseidon::{
        constants::PlonkSpongeConstantsKimchi,
        sponge::{DefaultFqSponge, DefaultFrSponge},
    },
    poly_commitment::{
        commitment::{BatchEvaluationProof, CommitmentCurve, Evaluation},
        ipa::{OpeningProof, SRS},
        utils::DensePolynomialOrEvaluations,
        PolyComm, SRS as _,
    },
};
use kimchi_stubs::arkworks::CamlFp;
use mina_curves::pasta::{Fp, Vesta, VestaParameters};
use poly_commitment::commitment::combined_inner_product;
use rand::{CryptoRng, RngCore};

pub struct BooleanCircuit {
    pub vals: Vec<Fp>,
}

impl From<CamlBooleanCircuit> for BooleanCircuit {
    fn from(circuit: CamlBooleanCircuit) -> Self {
        Self {
            vals: circuit.vals.into_iter().map(Fp::from).collect(),
        }
    }
}

#[derive(ocaml::IntoValue, ocaml::FromValue, ocaml_gen::Struct)]
pub struct CamlBooleanCircuit {
    vals: Vec<CamlFp>,
}

impl From<BooleanCircuit> for CamlBooleanCircuit {
    fn from(circuit: BooleanCircuit) -> Self {
        Self {
            vals: circuit.vals.into_iter().map(CamlFp::from).collect(),
        }
    }
}

type VestaFqSponge = DefaultFqSponge<VestaParameters, PlonkSpongeConstantsKimchi>;

type VestaFrSponge = DefaultFrSponge<Fp, PlonkSpongeConstantsKimchi>;

struct Proof {
    poly_commitment: Vesta,
    quotient_commitment: Vesta,
    evaluation: Fp,
    opening_proof: OpeningProof<Vesta>,
}

fn prove<RNG>(
    domain: EvaluationDomains<Fp>,
    srs: &SRS<Vesta>,
    group_map: &<Vesta as CommitmentCurve>::Map,
    rng: &mut RNG,
    boolean_circuit: &BooleanCircuit,
) -> Proof
where
    RNG: RngCore + CryptoRng,
{
    let mut fq_sponge: VestaFqSponge = DefaultFqSponge::new(Vesta::other_curve_sponge_params());
    let evals_d1 = Evaluations::from_vec_and_domain(boolean_circuit.vals.to_vec(), domain.d1);
    let p: DensePolynomial<Fp> = evals_d1.interpolate_by_ref();
    let comm_p = srs.commit_non_hiding(&p, 1).chunks[0];

    fq_sponge.absorb_g(&[comm_p]);

    let quotient_poly: DensePolynomial<Fp> = {
        let evals_d2 = p.evaluate_over_domain_by_ref(domain.d2);

        // q×d - a
        let numerator_eval: Evaluations<Fp, Radix2EvaluationDomain<Fp>> =
            &(&evals_d2 * &evals_d2) - &evals_d2;

        let numerator_eval_interpolated = numerator_eval.interpolate();

        let fail_final_q_division = || {
            panic!("Division by vanishing poly must not fail at this point, we checked it before")
        };
        // We compute the polynomial t(X) by dividing the constraints polynomial
        // by the vanishing polynomial, i.e. Z_H(X).
        let (quotient, res) = numerator_eval_interpolated
            .divide_by_vanishing_poly(domain.d1)
            .unwrap_or_else(fail_final_q_division);
        // As the constraints must be verified on H, the rest of the division
        // must be equal to 0 as the constraints polynomial and Z_H(X) are both
        // equal on H.
        if !res.is_zero() {
            fail_final_q_division();
        }

        quotient
    };

    let comm_quotient = srs.commit_non_hiding(&quotient_poly, 1).chunks[0];
    fq_sponge.absorb_g(&[comm_quotient]);

    let evaluation_point = fq_sponge.challenge();

    let mut fr_sponge = VestaFrSponge::new(Vesta::sponge_params());
    fr_sponge.absorb(&fq_sponge.clone().digest());

    let eval_p = p.evaluate(&evaluation_point);
    let eval_quotient = quotient_poly.evaluate(&evaluation_point);

    for eval in [eval_p, eval_quotient].into_iter() {
        fr_sponge.absorb(&eval);
    }

    let (_, endo_r) = Vesta::endos();
    // Generate scalars used as combiners for sub-statements within our IPA opening proof.
    let polyscale = fr_sponge.challenge().to_field(endo_r);
    let evalscale = fr_sponge.challenge().to_field(endo_r);

    // Creating the polynomials for the batch proof
    // Gathering all polynomials to use in the opening proof
    let opening_proof_inputs: Vec<_> = {
        let coefficients_form =
            DensePolynomialOrEvaluations::<_, Radix2EvaluationDomain<Fp>>::DensePolynomial;
        let non_hiding = |n_chunks| PolyComm {
            chunks: vec![Fp::zero(); n_chunks],
        };

        vec![
            (coefficients_form(&p), non_hiding(1)),
            (coefficients_form(&quotient_poly), non_hiding(1)),
        ]
    };

    let opening_proof = srs.open(
        group_map,
        opening_proof_inputs.as_slice(),
        &[evaluation_point],
        polyscale,
        evalscale,
        fq_sponge,
        rng,
    );

    Proof {
        poly_commitment: comm_p,
        quotient_commitment: comm_quotient,
        evaluation: eval_p,
        opening_proof,
    }
}

fn verify<RNG>(
    domain: EvaluationDomains<Fp>,
    srs: &SRS<Vesta>,
    group_map: &<Vesta as CommitmentCurve>::Map,
    rng: &mut RNG,
    proof: &Proof,
) -> bool
where
    RNG: RngCore + CryptoRng,
{
    let mut fq_sponge = VestaFqSponge::new(Vesta::other_curve_sponge_params());
    fq_sponge.absorb_g(&[proof.poly_commitment, proof.quotient_commitment]);

    let evaluation_point = fq_sponge.challenge();

    let mut fr_sponge = VestaFrSponge::new(Vesta::sponge_params());
    fr_sponge.absorb(&fq_sponge.clone().digest());

    let vanishing_poly_at_zeta = domain.d1.vanishing_polynomial().evaluate(&evaluation_point);
    let quotient_eval = {
        (proof.evaluation * proof.evaluation - proof.evaluation)
            * vanishing_poly_at_zeta
                .inverse()
                .unwrap_or_else(|| panic!("Inverse fails only with negligible probability"))
    };

    for eval in [proof.evaluation, quotient_eval].into_iter() {
        fr_sponge.absorb(&eval);
    }

    let (_, endo_r) = Vesta::endos();
    // Generate scalars used as combiners for sub-statements within our IPA opening proof.
    let polyscale = fr_sponge.challenge().to_field(endo_r);
    let evalscale = fr_sponge.challenge().to_field(endo_r);

    let coms_and_evaluations = vec![
        Evaluation {
            commitment: PolyComm {
                chunks: vec![proof.poly_commitment],
            },
            evaluations: vec![vec![proof.evaluation]],
        },
        Evaluation {
            commitment: PolyComm {
                chunks: vec![proof.quotient_commitment],
            },
            evaluations: vec![vec![quotient_eval]],
        },
    ];
    let combined_inner_product = {
        let evaluations: Vec<_> = coms_and_evaluations
            .iter()
            .map(|Evaluation { evaluations, .. }| evaluations.clone())
            .collect();

        combined_inner_product(&polyscale, &evalscale, evaluations.as_slice())
    };

    srs.verify(
        group_map,
        &mut [BatchEvaluationProof {
            sponge: fq_sponge,
            evaluation_points: vec![evaluation_point],
            polyscale,
            evalscale,
            evaluations: coms_and_evaluations,
            opening: &proof.opening_proof,
            combined_inner_product,
        }],
        rng,
    )
}

mod tests {

    use super::*;
    use ark_ff::One;
    use kimchi::groupmap::GroupMap;
    use once_cell::sync::Lazy;
    use rand::thread_rng;
    use rand::Rng;

    const SRS_SIZE: usize = 1 << 16;

    static GROUP_MAP: Lazy<<Vesta as CommitmentCurve>::Map> =
        Lazy::new(<Vesta as CommitmentCurve>::Map::setup);

    static DOMAIN: Lazy<EvaluationDomains<Fp>> =
        Lazy::new(|| EvaluationDomains::<Fp>::create(SRS_SIZE).unwrap());

    static SRS: Lazy<SRS<Vesta>> = Lazy::new(|| SRS::create(SRS_SIZE));

    #[test]
    fn test_prove_verify() {
        let mut rng = thread_rng();
        let boolean_circuit = {
            let mut vals = Vec::with_capacity(SRS_SIZE);
            for _ in 0..SRS_SIZE {
                let b: bool = rng.gen();
                let v = if b { Fp::one() } else { Fp::zero() };
                vals.push(v);
            }
            BooleanCircuit { vals }
        };
        let proof = prove(*DOMAIN, &SRS, &GROUP_MAP, &mut rng, &boolean_circuit);
        assert!(
            verify(*DOMAIN, &SRS, &GROUP_MAP, &mut rng, &proof),
            "Proof verification failed"
        );
    }

    #[test]
    #[should_panic(
        expected = "Division by vanishing poly must not fail at this point, we checked it before"
    )]
    fn test_prove_fails_if_not_boolean_values() {
        let mut rng = thread_rng();
        let boolean_circuit = {
            let mut vals = Vec::with_capacity(SRS_SIZE);
            for _ in 0..SRS_SIZE {
                let b: u32 = rng.gen();
                let v = Fp::from(b);
                vals.push(v);
            }
            BooleanCircuit { vals }
        };
        prove(*DOMAIN, &SRS, &GROUP_MAP, &mut rng, &boolean_circuit);
    }
}
