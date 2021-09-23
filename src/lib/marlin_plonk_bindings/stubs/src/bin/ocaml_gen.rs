#![feature(concat_idents)]

//
// run with `cargo +nightly run` due to the concat_idents feature
//

use commitment_dlog::commitment::caml::{CamlOpeningProof, CamlPolyComm};
use ocaml_gen::{decl_fake_generic, decl_func, decl_module, decl_type, Env, ToBinding, ToOcaml};
use oracle::sponge::caml::CamlScalarChallenge;
use plonk_circuits::scalars::caml::{CamlProofEvaluations, CamlRandomOracles};
use plonk_protocol_dlog::prover::caml::{CamlProverCommitments, CamlProverProof};

// we must import all here, to have access to the derived functions
use marlin_plonk_stubs::arkworks::bigint_256::*;
use marlin_plonk_stubs::arkworks::pasta_fp::*;

fn main() {
    println!("(* this file is generated automatically *)\n");
    let env = &mut Env::default();

    decl_fake_generic!(T1, 0);
    decl_fake_generic!(T2, 1);

    decl_module!(env, "Types", {
        decl_type!(env, CamlScalarChallenge::<T1> => "scalar_challenge");
        decl_type!(env, CamlRandomOracles::<T1> => "random_oracles");
        decl_type!(env, CamlProofEvaluations::<T1> => "proof_evaluations");
        decl_type!(env, CamlPolyComm::<T1> => "poly_comm");
        decl_type!(env, CamlOpeningProof::<T1, T2> => "opening_proof");
        decl_type!(env, CamlProverCommitments::<T1> => "prover_commitments");
        decl_type!(env, CamlProverProof<T1, T2> => "prover_proof");
    });

    decl_module!(env, "BigInt256", {
        decl_type!(env, CamlBigInteger256 => "t");
        decl_func!(env, caml_bigint_256_of_numeral => "of_numeral");
    });

    decl_module!(env, "Fp", {
        decl_type!(env, CamlFp => "t");
        decl_func!(env, caml_pasta_fp_size_in_bits => "size_in_bits");
        decl_func!(env, caml_pasta_fp_size);
        decl_func!(env, caml_pasta_fp_add);
        decl_func!(env, caml_pasta_fp_sub);
        decl_func!(env, caml_pasta_fp_negate);
        decl_func!(env, caml_pasta_fp_mul);
        decl_func!(env, caml_pasta_fp_div);
        decl_func!(env, caml_pasta_fp_inv);
        decl_func!(env, caml_pasta_fp_square);
        decl_func!(env, caml_pasta_fp_is_square);
        decl_func!(env, caml_pasta_fp_sqrt);
        decl_func!(env, caml_pasta_fp_of_int);
        decl_func!(env, caml_pasta_fp_to_string);
        decl_func!(env, caml_pasta_fp_of_string);
        decl_func!(env, caml_pasta_fp_print);
        decl_func!(env, caml_pasta_fp_copy);
        decl_func!(env, caml_pasta_fp_mut_add);
        decl_func!(env, caml_pasta_fp_mut_sub);
        decl_func!(env, caml_pasta_fp_mut_mul);
        decl_func!(env, caml_pasta_fp_mut_square);
        decl_func!(env, caml_pasta_fp_compare);
        decl_func!(env, caml_pasta_fp_equal);
        decl_func!(env, caml_pasta_fp_random);
        decl_func!(env, caml_pasta_fp_rng);
        decl_func!(env, caml_pasta_fp_to_bigint);
        decl_func!(env, caml_pasta_fp_of_bigint);
        decl_func!(env, caml_pasta_fp_two_adic_root_of_unity);
        decl_func!(env, caml_pasta_fp_domain_generator);
        decl_func!(env, caml_pasta_fp_to_bytes);
        decl_func!(env, caml_pasta_fp_of_bytes);
        decl_func!(env, caml_pasta_fp_deep_copy);
    });
}
