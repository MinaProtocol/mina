use algebra::{fields::PrimeField, One, UniformRand, VariableBaseMSM, Zero};

use commitment_dlog::{
    commitment::{b_poly_coefficients, CommitmentCurve},
    srs::SRS,
};
use rayon::prelude::*;
use wasm_bindgen::JsValue;

macro_rules! assert_equal {
    ($x: expr, $y: expr) => (
        let x = $x;
        let y = $y;
        if (x != y) {
            return Err(JsValue::from_str(format!("batch_dlog_accumulator_check {:?}:{:?}: {:?} != {:?}", file!(), line!(), x, y).as_str()))
        })
}

// TODO: Not compatible with variable rounds
pub fn batch_dlog_accumulator_check<G: CommitmentCurve>(
    urs: &SRS<G>,
    comms: &Vec<G>,
    chals: &Vec<G::ScalarField>,
) -> Result<bool, JsValue> {
    let k = comms.len();

    if k == 0 {
        assert_equal!(chals.len(), 0);
        return Ok(true);
    }

    let rounds = chals.len() / k;

    if rounds == 0 {
        return Err(JsValue::from_str(format!("batch_dlog_accumulator_check {:?}:{:?}: ({:?} / {:?}) = {:?} == 0", file!(), line!(), chals.len(), k, rounds).as_str()))
    }

    assert_equal!(chals.len() % rounds, 0);

    let rs = {
        let r = G::ScalarField::rand(&mut rand_core::OsRng);
        let mut rs = vec![G::ScalarField::one(); k];
        for i in 1..k {
            rs[i] = r * &rs[i - 1];
        }
        rs
    };

    let mut points = urs.g.clone();
    let n = points.len();
    points.extend(comms);

    let mut scalars = vec![G::ScalarField::zero(); n];
    scalars.extend(&rs[..]);

    let chal_invs = {
        let mut cs = chals.clone();
        algebra::fields::batch_inversion(&mut cs);
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
        assert_equal!(terms.len(), n);
        for i in 0..n {
            scalars[i] -= &terms[i];
        }
    }

    let scalars: Vec<_> = scalars.iter().map(|x| x.into_repr()).collect();
    Ok(VariableBaseMSM::multi_scalar_mul(&points, &scalars) == G::Projective::zero())
}
