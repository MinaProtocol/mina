use num_bigint::BigUint;

use ff::PrimeField;
use pairing::{Engine};
use group::CurveProjective;

type Bytes = Vec<u8>;

struct Proof<E: Engine> {
    a: E::G1,
    b: E::G2,
    c: E::G1,
    delta_prime: E::G2,
    z: E::G1,
}

struct VerificationKey<E: Engine> {
    alpha_beta: E::Fqk,
    delta: <<E as pairing::Engine>::G2Affine as pairing::PairingCurveAffine>::Prepared,
    query: Vec<E::G1>,
}

enum VerificationError {
    InputLengthWrong,
    ProofNotWellFormed,
}

impl<E: Engine> VerificationKey<E> {
    fn verify(&self, message: &[bool], input: &[E::Fr], proof: &Proof<E>) -> Result<(), VerificationError> {
        use VerificationError::*;

        if input.len() != self.query.len() - 1 {
            return Err(InputLengthWrong);
        }

        if !proof.is_well_formed() {
            return Err(ProofNotWellFormed);
        }

        let input_acc = input.iter().zip(self.query.iter().skip(1)).fold(self.query[0].clone(), |mut acc, (input_elt, query_elt)| {
            let mut query_elt = query_elt.clone();

            query_elt.mul_assign(input_elt.into_repr());

            acc.add_assign(&query_elt);
            acc
        });

        let delta_prime_prepared = proof.delta_prime.prepare();

        let test1 = {
            let l = proof.a.pairing_with(&proof.b);
            let r1 = self.alpha_beta.clone();
            let r2 = E::miller_loop([(&input_acc.)])
        };

        Ok(())
    }
}

impl<E: Engine> Proof<E> {
    fn is_well_formed(&self) -> bool {
        false
    }
}