#![feature(concat_idents)]

//
// run with `cargo +nightly run` due to the concat_idents feature
//

use ocaml_gen::{decl_fake_generic, decl_func, decl_module, decl_type, decl_type_alias, Env};
use std::fs::File;
use wires_15_stubs::{
    // we must import all here, to have access to the derived functions
    arkworks::{bigint_256::*, group_affine::*, group_projective::*, pasta_fp::*, pasta_fq::*},
    caml_pointer::CamlPointer,
    gate_vector::{fp::*, fq::*},
    pasta_fp_plonk_index::*,
    pasta_fp_plonk_oracles::*,
    pasta_fp_plonk_proof::*,
    pasta_fp_plonk_verifier_index::*,
    pasta_fp_vector::*,
    pasta_fq_plonk_index::*,
    pasta_fq_plonk_oracles::*,
    pasta_fq_plonk_proof::*,
    pasta_fq_plonk_verifier_index::*,
    pasta_fq_vector::*,
    pasta_pallas::*,
    pasta_vesta::*,
    plonk_verifier_index::{CamlPlonkDomain, CamlPlonkVerificationEvals, CamlPlonkVerifierIndex},
    srs::{fp::*, fq::*},
    CamlCircuitGate,
    CamlLookupEvaluations,
    CamlOpeningProof,
    CamlPolyComm,
    CamlProofEvaluations,
    CamlProverCommitments,
    CamlProverProof,
    CamlRandomOracles,
    CamlScalarChallenge,
    CamlWire,
    GateType,
};

fn main() {
    let args: Vec<String> = std::env::args().collect();

    if let Some(output_file) = args.get(1) {
        let mut file = File::create(output_file).expect("could not create output file");
        generate_bindings(&mut file);
    } else {
        let mut w = std::io::stdout();
        generate_bindings(&mut w);
    };
}

fn generate_bindings(mut w: impl std::io::Write) {
    let env = &mut Env::default();

    decl_fake_generic!(T1, 0);
    decl_fake_generic!(T2, 1);
    decl_fake_generic!(T3, 2);

    write!(
        w,
        "(* This file is generated automatically with ocaml_gen. *)\n"
    )
    .unwrap();

    decl_module!(w, env, "Foundations", {
        decl_module!(w, env, "BigInt256", {
            decl_type!(w, env, CamlBigInteger256 => "t");

            decl_func!(w, env, caml_bigint_256_of_numeral => "of_numeral");
            decl_func!(w, env, caml_bigint_256_of_decimal_string => "of_decimal_string");
            decl_func!(w, env, caml_bigint_256_num_limbs => "num_limbs");
            decl_func!(w, env, caml_bigint_256_bytes_per_limb => "bytes_per_limb");
            decl_func!(w, env, caml_bigint_256_div => "div");
            decl_func!(w, env, caml_bigint_256_compare => "compare");
            decl_func!(w, env, caml_bigint_256_print => "print");
            decl_func!(w, env, caml_bigint_256_to_string => "to_string");
            decl_func!(w, env, caml_bigint_256_test_bit => "test_bit");
            decl_func!(w, env, caml_bigint_256_to_bytes => "to_bytes");
            decl_func!(w, env, caml_bigint_256_of_bytes => "of_bytes");
            decl_func!(w, env, caml_bigint_256_deep_copy => "deep_copy");
        });

        decl_module!(w, env, "Fp", {
            decl_type!(w, env, CamlFp => "t");

            decl_func!(w, env, caml_pasta_fp_size_in_bits => "size_in_bits");
            decl_func!(w, env, caml_pasta_fp_size => "size");
            decl_func!(w, env, caml_pasta_fp_add => "add");
            decl_func!(w, env, caml_pasta_fp_sub => "sub");
            decl_func!(w, env, caml_pasta_fp_negate => "negate");
            decl_func!(w, env, caml_pasta_fp_mul => "mul");
            decl_func!(w, env, caml_pasta_fp_div => "div");
            decl_func!(w, env, caml_pasta_fp_inv => "inv");
            decl_func!(w, env, caml_pasta_fp_square => "square");
            decl_func!(w, env, caml_pasta_fp_is_square => "is_square");
            decl_func!(w, env, caml_pasta_fp_sqrt => "sqrt");
            decl_func!(w, env, caml_pasta_fp_of_int => "of_int");
            decl_func!(w, env, caml_pasta_fp_to_string => "to_string");
            decl_func!(w, env, caml_pasta_fp_of_string => "of_string");
            decl_func!(w, env, caml_pasta_fp_print => "print");
            decl_func!(w, env, caml_pasta_fp_copy => "copy");
            decl_func!(w, env, caml_pasta_fp_mut_add => "mut_add");
            decl_func!(w, env, caml_pasta_fp_mut_sub => "mut_sub");
            decl_func!(w, env, caml_pasta_fp_mut_mul => "mut_mul");
            decl_func!(w, env, caml_pasta_fp_mut_square => "mut_square");
            decl_func!(w, env, caml_pasta_fp_compare => "compare");
            decl_func!(w, env, caml_pasta_fp_equal => "equal");
            decl_func!(w, env, caml_pasta_fp_random => "random");
            decl_func!(w, env, caml_pasta_fp_rng => "rng");
            decl_func!(w, env, caml_pasta_fp_to_bigint => "to_bigint");
            decl_func!(w, env, caml_pasta_fp_of_bigint => "of_bigint");
            decl_func!(w, env, caml_pasta_fp_two_adic_root_of_unity => "two_adic_root_of_unity");
            decl_func!(w, env, caml_pasta_fp_domain_generator => "domain_generator");
            decl_func!(w, env, caml_pasta_fp_to_bytes => "to_bytes");
            decl_func!(w, env, caml_pasta_fp_of_bytes => "of_bytes");
            decl_func!(w, env, caml_pasta_fp_deep_copy => "deep_copy");
        });

        decl_module!(w, env, "Fq", {
            decl_type!(w, env, CamlFq => "t");

            decl_func!(w, env, caml_pasta_fq_size_in_bits => "size_in_bits");
            decl_func!(w, env, caml_pasta_fq_size => "size");
            decl_func!(w, env, caml_pasta_fq_add => "add");
            decl_func!(w, env, caml_pasta_fq_sub => "sub");
            decl_func!(w, env, caml_pasta_fq_negate => "negate");
            decl_func!(w, env, caml_pasta_fq_mul => "mul");
            decl_func!(w, env, caml_pasta_fq_div => "div");
            decl_func!(w, env, caml_pasta_fq_inv => "inv");
            decl_func!(w, env, caml_pasta_fq_square => "square");
            decl_func!(w, env, caml_pasta_fq_is_square => "is_square");
            decl_func!(w, env, caml_pasta_fq_sqrt => "sqrt");
            decl_func!(w, env, caml_pasta_fq_of_int => "of_int");
            decl_func!(w, env, caml_pasta_fq_to_string => "to_string");
            decl_func!(w, env, caml_pasta_fq_of_string => "of_string");
            decl_func!(w, env, caml_pasta_fq_print => "print");
            decl_func!(w, env, caml_pasta_fq_copy => "copy");
            decl_func!(w, env, caml_pasta_fq_mut_add => "mut_add");
            decl_func!(w, env, caml_pasta_fq_mut_sub => "mut_sub");
            decl_func!(w, env, caml_pasta_fq_mut_mul => "mut_mul");
            decl_func!(w, env, caml_pasta_fq_mut_square => "mut_square");
            decl_func!(w, env, caml_pasta_fq_compare => "compare");
            decl_func!(w, env, caml_pasta_fq_equal => "equal");
            decl_func!(w, env, caml_pasta_fq_random => "random");
            decl_func!(w, env, caml_pasta_fq_rng => "rng");
            decl_func!(w, env, caml_pasta_fq_to_bigint => "to_bigint");
            decl_func!(w, env, caml_pasta_fq_of_bigint => "of_bigint");
            decl_func!(w, env, caml_pasta_fq_two_adic_root_of_unity => "two_adic_root_of_unity");
            decl_func!(w, env, caml_pasta_fq_domain_generator => "domain_generator");
            decl_func!(w, env, caml_pasta_fq_to_bytes => "to_bytes");
            decl_func!(w, env, caml_pasta_fq_of_bytes => "of_bytes");
            decl_func!(w, env, caml_pasta_fq_deep_copy => "deep_copy");
        });

        decl_type!(w, env, CamlGroupAffine<T1> => "or_infinity");
    });

    decl_module!(w, env, "FieldVectors", {
        decl_module!(w, env, "Fp", {
            decl_type!(w, env, CamlPointer<T1> => "t");
            decl_type_alias!(w, env, "elt" => CamlFp);

            decl_func!(w, env, caml_pasta_fp_vector_create => "create");
            decl_func!(w, env, caml_pasta_fp_vector_length => "length");
            decl_func!(w, env, caml_pasta_fp_vector_emplace_back => "emplace_back");
            decl_func!(w, env, caml_pasta_fp_vector_get => "get");
        });

        decl_module!(w, env, "Fq", {
            decl_type!(w, env, CamlPointer<T1> => "t");
            decl_type_alias!(w, env, "elt" => CamlFq);

            decl_func!(w, env, caml_pasta_fq_vector_create => "create");
            decl_func!(w, env, caml_pasta_fq_vector_length => "length");
            decl_func!(w, env, caml_pasta_fq_vector_emplace_back => "emplace_back");
            decl_func!(w, env, caml_pasta_fq_vector_get => "get");
        });
    });

    decl_module!(w, env, "Vesta", {
        decl_type!(w, env, CamlGroupProjectiveVesta => "t");

        decl_module!(w, env, "Affine", {
            decl_type_alias!(w, env, "t" => CamlGroupAffine<CamlFq>);
        });

        decl_func!(w, env, caml_pasta_vesta_one => "one");
        decl_func!(w, env, caml_pasta_vesta_add => "add");
        decl_func!(w, env, caml_pasta_vesta_sub => "sub");
        decl_func!(w, env, caml_pasta_vesta_negate => "negate");
        decl_func!(w, env, caml_pasta_vesta_double => "double");
        decl_func!(w, env, caml_pasta_vesta_scale => "scale");
        decl_func!(w, env, caml_pasta_vesta_random => "random");
        decl_func!(w, env, caml_pasta_vesta_rng => "rng");
        decl_func!(w, env, caml_pasta_vesta_endo_base => "endo_base");
        decl_func!(w, env, caml_pasta_vesta_endo_scalar => "endo_scalar");
        decl_func!(w, env, caml_pasta_vesta_to_affine => "to_affine");
        decl_func!(w, env, caml_pasta_vesta_of_affine => "of_affine");
        decl_func!(w, env, caml_pasta_vesta_of_affine_coordinates => "of_affine_coordinates");
        decl_func!(w, env, caml_pasta_vesta_affine_deep_copy => "deep_copy");
    });

    decl_module!(w, env, "Pallas", {
        decl_type!(w, env, CamlGroupProjectivePallas => "t");

        decl_module!(w, env, "Affine", {
            decl_type_alias!(w, env, "t" => CamlGroupAffine<CamlFp>);
        });

        decl_func!(w, env, caml_pasta_pallas_one => "one");
        decl_func!(w, env, caml_pasta_pallas_add => "add");
        decl_func!(w, env, caml_pasta_pallas_sub => "sub");
        decl_func!(w, env, caml_pasta_pallas_negate => "negate");
        decl_func!(w, env, caml_pasta_pallas_double => "double");
        decl_func!(w, env, caml_pasta_pallas_scale => "scale");
        decl_func!(w, env, caml_pasta_pallas_random => "random");
        decl_func!(w, env, caml_pasta_pallas_rng => "rng");
        decl_func!(w, env, caml_pasta_pallas_endo_base => "endo_base");
        decl_func!(w, env, caml_pasta_pallas_endo_scalar => "endo_scalar");
        decl_func!(w, env, caml_pasta_pallas_to_affine => "to_affine");
        decl_func!(w, env, caml_pasta_pallas_of_affine => "of_affine");
        decl_func!(w, env, caml_pasta_pallas_of_affine_coordinates => "of_affine_coordinates");
        decl_func!(w, env, caml_pasta_pallas_affine_deep_copy => "deep_copy");
    });

    decl_module!(w, env, "Protocol", {
        decl_type!(w, env, CamlScalarChallenge::<T1> => "scalar_challenge");
        decl_type!(w, env, CamlRandomOracles::<T1> => "random_oracles");
        decl_type!(w, env, CamlLookupEvaluations<T1> => "lookup_evaluations");
        decl_type!(w, env, CamlProofEvaluations::<T1> => "proof_evaluations");
        decl_type!(w, env, CamlPolyComm::<T1> => "poly_comm");
        decl_type!(w, env, CamlOpeningProof::<T1, T2> => "opening_proof");
        decl_type!(w, env, CamlProverCommitments::<T1> => "prover_commitments");
        decl_type!(w, env, CamlProverProof<T1, T2> => "prover_proof");

        decl_type!(w, env, CamlWire => "wire");
        decl_type!(w, env, GateType => "gate_type");
        decl_type!(w, env, CamlCircuitGate<T1> => "circuit_gate");

        decl_module!(w, env, "Gates", {
            decl_module!(w, env, "Vector", {
                decl_module!(w, env, "Fp", {
                    decl_type!(w, env, CamlPastaFpPlonkGateVector => "t");
                    decl_type_alias!(w, env, "elt" => CamlCircuitGate<CamlFp>);

                    decl_func!(w, env, caml_pasta_fp_plonk_gate_vector_create => "create");
                    decl_func!(w, env, caml_pasta_fp_plonk_gate_vector_add => "add");
                    decl_func!(w, env, caml_pasta_fp_plonk_gate_vector_get => "get");
                    decl_func!(w, env, caml_pasta_fp_plonk_gate_vector_wrap => "wrap");
                });
                decl_module!(w, env, "Fq", {
                    decl_type!(w, env, CamlPastaFqPlonkGateVector => "t");
                    decl_type_alias!(w, env, "elt" => CamlCircuitGate<CamlFp>);

                    decl_func!(w, env, caml_pasta_fq_plonk_gate_vector_create => "create");
                    decl_func!(w, env, caml_pasta_fq_plonk_gate_vector_add => "add");
                    decl_func!(w, env, caml_pasta_fq_plonk_gate_vector_get => "get");
                    decl_func!(w, env, caml_pasta_fq_plonk_gate_vector_wrap => "wrap");
                });
            });
        });

        decl_module!(w, env, "Index", {
            decl_module!(w, env, "Fp", {
                decl_type!(w, env, CamlPastaFpPlonkIndex => "t");

                decl_func!(w, env, caml_pasta_fp_plonk_index_create => "create");
                decl_func!(w, env, caml_pasta_fp_plonk_index_max_degree => "max_degree");
                decl_func!(w, env, caml_pasta_fp_plonk_index_public_inputs => "public_inputs");
                decl_func!(w, env, caml_pasta_fp_plonk_index_domain_d1_size => "domain_d1_size");
                decl_func!(w, env, caml_pasta_fp_plonk_index_domain_d4_size => "domain_d4_size");
                decl_func!(w, env, caml_pasta_fp_plonk_index_domain_d8_size => "domain_d8_size");
                decl_func!(w, env, caml_pasta_fp_plonk_index_read => "read");
                decl_func!(w, env, caml_pasta_fp_plonk_index_write => "write");
            });

            decl_module!(w, env, "Fq", {
                decl_type!(w, env, CamlPastaFqPlonkIndex => "t");

                decl_func!(w, env, caml_pasta_fq_plonk_index_create => "create");
                decl_func!(w, env, caml_pasta_fq_plonk_index_max_degree => "max_degree");
                decl_func!(w, env, caml_pasta_fq_plonk_index_public_inputs => "public_inputs");
                decl_func!(w, env, caml_pasta_fq_plonk_index_domain_d1_size => "domain_d1_size");
                decl_func!(w, env, caml_pasta_fq_plonk_index_domain_d4_size => "domain_d4_size");
                decl_func!(w, env, caml_pasta_fq_plonk_index_domain_d8_size => "domain_d8_size");
                decl_func!(w, env, caml_pasta_fq_plonk_index_read => "read");
                decl_func!(w, env, caml_pasta_fq_plonk_index_write => "write");
            });
        });

        decl_module!(w, env, "Srs", {
            decl_module!(w, env, "Fp", {
                decl_type!(w, env, CamlPointer<T1> => "t");

                decl_module!(w, env, "Poly_comm", {
                    decl_type_alias!(w, env, "t" => CamlPolyComm<CamlGroupAffine<CamlFp>>);
                });

                decl_func!(w, env, caml_pasta_fp_urs_create => "create");
                decl_func!(w, env, caml_pasta_fp_urs_write => "write");
                decl_func!(w, env, caml_pasta_fp_urs_read => "read");
                decl_func!(w, env, caml_pasta_fp_urs_lagrange_commitment => "lagrange_commitment");
                decl_func!(w, env, caml_pasta_fp_urs_commit_evaluations => "commit_evaluations");
                decl_func!(w, env, caml_pasta_fp_urs_b_poly_commitment => "b_poly_commitment");
                decl_func!(w, env, caml_pasta_fp_urs_batch_accumulator_check => "batch_accumulator_check");
                decl_func!(w, env, caml_pasta_fp_urs_h => "urs_h");
            });

            decl_module!(w, env, "Fq", {
                decl_type!(w, env, CamlPointer<T1> => "t");

                decl_func!(w, env, caml_pasta_fq_urs_create => "create");
                decl_func!(w, env, caml_pasta_fq_urs_write => "write");
                decl_func!(w, env, caml_pasta_fq_urs_read => "read");
                decl_func!(w, env, caml_pasta_fq_urs_lagrange_commitment => "lagrange_commitment");
                decl_func!(w, env, caml_pasta_fq_urs_commit_evaluations => "commit_evaluations");
                decl_func!(w, env, caml_pasta_fq_urs_b_poly_commitment => "b_poly_commitment");
                decl_func!(w, env, caml_pasta_fq_urs_batch_accumulator_check => "batch_accumulator_check");
                decl_func!(w, env, caml_pasta_fq_urs_h => "urs_h");
            });
        });

        decl_module!(w, env, "VerifierIndex", {
            decl_type!(w, env, CamlPlonkDomain<T1> => "domain");
            decl_type!(w, env, CamlPlonkVerificationEvals<T1> => "verification_evals");
            decl_type!(w, env, CamlPlonkVerifierIndex<T1, T2, T3> => "t");

            decl_module!(w, env, "Fp", {
                decl_func!(w, env, caml_pasta_fp_plonk_verifier_index_create => "create");
                decl_func!(w, env, caml_pasta_fp_plonk_verifier_index_read => "read");
                decl_func!(w, env, caml_pasta_fp_plonk_verifier_index_write => "write");
                decl_func!(w, env, caml_pasta_fp_plonk_verifier_index_shifts => "shifts");
                decl_func!(w, env, caml_pasta_fp_plonk_verifier_index_dummy => "dummy");
                decl_func!(w, env, caml_pasta_fp_plonk_verifier_index_deep_copy => "deep_copy");
            });

            decl_module!(w, env, "Fq", {
                decl_func!(w, env, caml_pasta_fq_plonk_verifier_index_create => "create");
                decl_func!(w, env, caml_pasta_fq_plonk_verifier_index_read => "read");
                decl_func!(w, env, caml_pasta_fq_plonk_verifier_index_write => "write");
                decl_func!(w, env, caml_pasta_fq_plonk_verifier_index_shifts => "shifts");
                decl_func!(w, env, caml_pasta_fq_plonk_verifier_index_dummy => "dummy");
                decl_func!(w, env, caml_pasta_fq_plonk_verifier_index_deep_copy => "deep_copy");
            });
        });

        decl_module!(w, env, "Oracles", {
            decl_module!(w, env, "Fp", {
                decl_type!(w, env, CamlPastaFpPlonkOracles => "t");

                decl_func!(w, env, caml_pasta_fp_plonk_oracles_create => "create");
                decl_func!(w, env, caml_pasta_fp_plonk_oracles_dummy => "dummy");
                decl_func!(w, env, caml_pasta_fp_plonk_oracles_deep_copy => "deep_copy");
            });

            decl_module!(w, env, "Fq", {
                decl_type!(w, env, CamlPastaFqPlonkOracles => "t");

                decl_func!(w, env, caml_pasta_fq_plonk_oracles_create => "create");
                decl_func!(w, env, caml_pasta_fq_plonk_oracles_dummy => "dummy");
                decl_func!(w, env, caml_pasta_fq_plonk_oracles_deep_copy => "deep_copy");
            });
        });

        decl_module!(w, env, "Proof", {
            decl_module!(w, env, "Fp", {
                decl_func!(w, env, caml_pasta_fp_plonk_proof_create => "create");
                decl_func!(w, env, caml_pasta_fp_plonk_proof_verify => "verify");
                decl_func!(w, env, caml_pasta_fp_plonk_proof_batch_verify => "batch_verify");
                decl_func!(w, env, caml_pasta_fp_plonk_proof_dummy => "dummy");
                decl_func!(w, env, caml_pasta_fp_plonk_proof_deep_copy => "deep_copy");
            });

            decl_module!(w, env, "Fq", {
                decl_func!(w, env, caml_pasta_fq_plonk_proof_create => "create");
                decl_func!(w, env, caml_pasta_fq_plonk_proof_verify => "verify");
                decl_func!(w, env, caml_pasta_fq_plonk_proof_batch_verify => "batch_verify");
                decl_func!(w, env, caml_pasta_fq_plonk_proof_dummy => "dummy");
                decl_func!(w, env, caml_pasta_fq_plonk_proof_deep_copy => "deep_copy");
            });
        });
    });
}
