use ark_ec::{msm::VariableBaseMSM, ProjectiveCurve};
use ark_ff::{batch_inversion, One, PrimeField, UniformRand, Zero};
use poly_commitment::{
    commitment::{b_poly_coefficients, CommitmentCurve},
    srs::SRS,
};
use rayon::prelude::*;

// TODO: Not compatible with variable rounds
pub fn batch_dlog_accumulator_check<G: CommitmentCurve>(
    urs: &SRS<G>,
    comms: &[G],
    chals: &[G::ScalarField],
) -> bool {
    let k = comms.len();

    if k == 0 {
        assert_eq!(chals.len(), 0);
        return true;
    }

    let rounds = chals.len() / k;
    assert_eq!(chals.len() % rounds, 0);

    let rs = {
        let r = G::ScalarField::rand(&mut rand::rngs::OsRng);
        let mut rs = vec![G::ScalarField::one(); k];
        for i in 1..k {
            rs[i] = r * rs[i - 1];
        }
        rs
    };

    let mut points = urs.g.clone();
    let n = points.len();
    points.extend(comms);

    let mut scalars = vec![G::ScalarField::zero(); n];
    scalars.extend(&rs[..]);

    let chal_invs = {
        let mut cs = chals.to_vec();
        batch_inversion(&mut cs);
        cs
    };

    let termss: Vec<_> = chals
        .par_iter()
        .zip(chal_invs)
        .chunks(rounds)
        .zip(rs)
        .map(|(chunk, r)| {
            let chals: Vec<_> = chunk.iter().map(|(c, _)| **c).collect();
            let mut s = b_poly_coefficients(&chals);
            s.iter_mut().for_each(|c| *c *= &r);
            s
        })
        .collect();

    for terms in termss {
        assert_eq!(terms.len(), n);
        for i in 0..n {
            scalars[i] -= &terms[i];
        }
    }

    let scalars: Vec<_> = scalars.iter().map(|x| x.into_repr()).collect();
    VariableBaseMSM::multi_scalar_mul(&points, &scalars) == G::Projective::zero()
}

pub fn batch_dlog_accumulator_generate<G: CommitmentCurve>(
    urs: &SRS<G>,
    num_comms: usize,
    chals: &Vec<G::ScalarField>,
) -> Vec<G> {
    let k = num_comms;

    if k == 0 {
        assert_eq!(chals.len(), 0);
        return vec![];
    }

    let rounds = chals.len() / k;
    assert_eq!(chals.len() % rounds, 0);

    let comms: Vec<_> = chals
        .into_par_iter()
        .chunks(rounds)
        .map(|chals| {
            let chals: Vec<G::ScalarField> = chals.into_iter().copied().collect();
            let scalars: Vec<_> = b_poly_coefficients(&chals)
                .into_iter()
                .map(|x| x.into_repr())
                .collect();
            let points: Vec<_> = urs.g.clone();
            VariableBaseMSM::multi_scalar_mul(&points, &scalars).into_affine()
        })
        .collect();

    comms
}
