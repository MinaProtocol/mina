//! The Marlin_plonk_stubs crate exports some functionalities
//! and structures from the following the Rust crates to OCaml:
//!
//! * [Proof-systems](https://github.com/o1-labs/proof-systems),
//!   a PLONK implementation.
//! * [Arkworks](http://arkworks.rs/),
//!   a math library that Proof-systems builds on top of.
//!

extern crate libc;

/// Caml helpers
#[macro_use]
pub mod caml;

/// Arkworks types
pub mod arkworks;

/// Utils
pub mod urs_utils; // TODO: move this logic to proof-systems

/// Vectors
pub mod field_vector;
pub mod gate_vector;

/// Curves
pub mod projective;

/// SRS
pub mod srs;

/// Indexes
pub mod pasta_fp_plonk_index;
pub mod pasta_fq_plonk_index;

/// Verifier indexes/keys
pub mod plonk_verifier_index;

pub mod pasta_fp_plonk_verifier_index;
pub mod pasta_fq_plonk_verifier_index;

/// Oracles
pub mod oracles;

/// Proofs
pub mod pasta_fp_plonk_proof;
pub mod pasta_fq_plonk_proof;

/// Poseidon
pub mod pasta_fp_poseidon;
pub mod pasta_fq_poseidon;

/// Linearization helpers
pub mod linearization {

    pub fn linearization_strings<F: ark_ff::PrimeField + ark_ff::SquareRootField>(
    ) -> (String, Vec<(String, String)>) {
        let d1 = ark_poly::EvaluationDomain::<F>::new(1).unwrap();
        let evaluated_cols = kimchi::index::linearization_columns::<F>();
        let kimchi::circuits::expr::Linearization {
            constant_term,
            mut index_terms,
        } = kimchi::index::constraints_expr(d1, false, None)
            .linearize(evaluated_cols)
            .unwrap();
        // HashMap deliberately uses an unstable order; here we sort to ensure that the output is
        // consistent when printing.
        index_terms.sort_by(|(x, _), (y, _)| x.cmp(y));
        (
            format!("{}", constant_term),
            index_terms
                .iter()
                .map(|(col, expr)| (format!("{:?}", col), format!("{}", expr)))
                .collect(),
        )
    }

    #[ocaml::func]
    pub fn fp_linearization_strings() -> (String, Vec<(String, String)>) {
        linearization_strings::<mina_curves::pasta::Fp>()
    }

    #[ocaml::func]
    pub fn fq_linearization_strings() -> (String, Vec<(String, String)>) {
        linearization_strings::<mina_curves::pasta::Fq>()
    }
}

/// Handy re-exports
pub use {
    commitment_dlog::commitment::caml::{CamlOpeningProof, CamlPolyComm},
    kimchi::circuits::{
        gate::{caml::CamlCircuitGate, CurrOrNext, GateType},
        scalars::caml::{CamlLookupEvaluations, CamlProofEvaluations, CamlRandomOracles},
        wires::caml::CamlWire,
    },
    kimchi::prover::caml::{CamlProverCommitments, CamlProverProof},
    oracle::sponge::caml::CamlScalarChallenge,
};
