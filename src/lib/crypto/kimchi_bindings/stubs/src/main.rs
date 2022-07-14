use kimchi::proof::caml::CamlRecursionChallenge;
use ocaml_gen::{decl_fake_generic, decl_func, decl_module, decl_type, decl_type_alias, Env};
use std::fs::File;
use std::io::Write;
use wires_15_stubs::{
    // we must import all here, to have access to the derived functions
    arkworks::{
        bigint_256::*,
        fields::{fp::*, fq::*},
        group_affine::*,
        group_projective::*,
    },
    field_vector::{fp::*, fq::*},
    gate_vector::{fp::*, fq::*},
    oracles::{fp::*, fq::*, CamlOracles},
    pasta_fp_plonk_index::*,
    pasta_fp_plonk_proof::*,
    pasta_fp_plonk_verifier_index::*,
    pasta_fq_plonk_index::*,
    pasta_fq_plonk_proof::*,
    pasta_fq_plonk_verifier_index::*,
    plonk_verifier_index::{
        CamlLookupSelectors, CamlLookupVerifierIndex, CamlLookupsUsed, CamlPlonkDomain,
        CamlPlonkVerificationEvals, CamlPlonkVerifierIndex,
    },
    projective::{pallas::*, vesta::*},
    srs::{fp::*, fq::*},
    CamlCircuitGate,
    CamlLookupCommitments,
    CamlLookupEvaluations,
    CamlOpeningProof,
    CamlPolyComm,
    CamlProofEvaluations,
    CamlProverCommitments,
    CamlProverProof,
    CamlRandomOracles,
    CamlScalarChallenge,
    CamlWire,
    CurrOrNext,
    GateType,
};

fn main() {
    let args: Vec<String> = std::env::args().collect();

    let env = &mut Env::new();

    let header = "(* This file is generated automatically with ocaml_gen. *)\n";

    if let Some(kimchi_types) = args.get(1) {
        let mut file = File::create(kimchi_types).expect("could not create output file");
        write!(file, "{}", header).unwrap();
        let _ = env.new_module("Kimchi_types");
        generate_types_bindings(&mut file, env);
        let _ = env.parent();
    } else {
        let mut w = std::io::stdout();
        write!(w, "{}", header).unwrap();
        decl_module!(w, env, "Kimchi_types", {
            generate_types_bindings(&mut w, env);
        });
    };
    if let Some(pasta_bindings) = args.get(2) {
        let mut file = File::create(pasta_bindings).expect("could not create output file");
        write!(file, "{}", header).unwrap();
        let _ = env.new_module("Pasta_bindings");
        generate_pasta_bindings(&mut file, env);
        let _ = env.parent();
    } else {
        let mut w = std::io::stdout();
        write!(w, "{}", header).unwrap();
        decl_module!(w, env, "Pasta_bindings", {
            generate_pasta_bindings(&mut w, env);
        });
    }
    if let Some(kimchi_bindings) = args.get(3) {
        let mut file = File::create(kimchi_bindings).expect("could not create output file");
        write!(file, "{}", header).unwrap();
        let _ = env.new_module("Kimchi_bindings");
        generate_kimchi_bindings(&mut file, env);
        let _ = env.parent();
    } else {
        let mut w = std::io::stdout();
        write!(w, "{}", header).unwrap();
        decl_module!(w, env, "Kimchi_bindings", {
            generate_kimchi_bindings(&mut w, env);
        });
    }
}

fn generate_types_bindings(mut w: impl std::io::Write, env: &mut Env) {
    decl_fake_generic!(T1, 0);
    decl_fake_generic!(T2, 1);
    decl_fake_generic!(T3, 2);

    decl_type!(w, env, CamlGroupAffine<T1> => "or_infinity");
    decl_type!(w, env, CamlScalarChallenge::<T1> => "scalar_challenge");
    decl_type!(w, env, CamlRandomOracles::<T1> => "random_oracles");
    decl_type!(w, env, CamlLookupEvaluations<T1> => "lookup_evaluations");
    decl_type!(w, env, CamlProofEvaluations::<T1> => "proof_evaluations");
    decl_type!(w, env, CamlPolyComm::<T1> => "poly_comm");
    decl_type!(w, env, CamlRecursionChallenge::<T1, T2> => "recursion_challenge");
    decl_type!(w, env, CamlOpeningProof::<T1, T2> => "opening_proof");
    decl_type!(w, env, CamlLookupCommitments::<T1> => "lookup_commitments");
    decl_type!(w, env, CamlProverCommitments::<T1> => "prover_commitments");
    decl_type!(w, env, CamlProverProof<T1, T2> => "prover_proof");

    decl_type!(w, env, CamlWire => "wire");
    decl_type!(w, env, GateType => "gate_type");
    decl_type!(w, env, CamlCircuitGate<T1> => "circuit_gate");

    decl_type!(w, env, CurrOrNext => "curr_or_next");

    decl_type!(w, env, CamlOracles<T1> => "oracles");
    decl_module!(w, env, "VerifierIndex", {
        decl_module!(w, env, "Lookup", {
            decl_type!(w, env, CamlLookupsUsed => "lookups_used");
            decl_type!(w, env, CamlLookupSelectors<T1> => "lookup_selectors");
            decl_type!(w, env, CamlLookupVerifierIndex<T1> => "t");
        });
        decl_type!(w, env, CamlPlonkDomain<T1> => "domain");
        decl_type!(w, env, CamlPlonkVerificationEvals<T1> => "verification_evals");
        decl_type!(w, env, CamlPlonkVerifierIndex<T1, T2, T3> => "verifier_index");
    });
}

fn generate_pasta_bindings(mut w: impl std::io::Write, env: &mut Env) {
    decl_fake_generic!(T1, 0);
    decl_fake_generic!(T2, 1);
    decl_fake_generic!(T3, 2);

    decl_module!(w, env, "BigInt256", {
        decl_type!(w, env, BigInteger256 => "t");

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

    decl_module!(w, env, "Vesta", {
        decl_module!(w, env, "BaseField", {
            decl_type_alias!(w, env, "t" => CamlFq);
        });

        decl_module!(w, env, "ScalarField", {
            decl_type_alias!(w, env, "t" => CamlFp);
        });

        decl_module!(w, env, "Affine", {
            decl_type_alias!(w, env, "t" => CamlGroupAffine<CamlFq>);
        });

        decl_type!(w, env, CamlGroupProjectiveVesta => "t");

        decl_func!(w, env, caml_vesta_one => "one");
        decl_func!(w, env, caml_vesta_add => "add");
        decl_func!(w, env, caml_vesta_sub => "sub");
        decl_func!(w, env, caml_vesta_negate => "negate");
        decl_func!(w, env, caml_vesta_double => "double");
        decl_func!(w, env, caml_vesta_scale => "scale");
        decl_func!(w, env, caml_vesta_random => "random");
        decl_func!(w, env, caml_vesta_rng => "rng");
        decl_func!(w, env, caml_vesta_endo_base => "endo_base");
        decl_func!(w, env, caml_vesta_endo_scalar => "endo_scalar");
        decl_func!(w, env, caml_vesta_to_affine => "to_affine");
        decl_func!(w, env, caml_vesta_of_affine => "of_affine");
        decl_func!(w, env, caml_vesta_of_affine_coordinates => "of_affine_coordinates");
        decl_func!(w, env, caml_vesta_affine_deep_copy => "deep_copy");
    });

    decl_module!(w, env, "Pallas", {
        decl_module!(w, env, "BaseField", {
            decl_type_alias!(w, env, "t" => CamlFp);
        });

        decl_module!(w, env, "ScalarField", {
            decl_type_alias!(w, env, "t" => CamlFq);
        });

        decl_module!(w, env, "Affine", {
            decl_type_alias!(w, env, "t" => CamlGroupAffine<CamlFp>);
        });

        decl_type!(w, env, CamlGroupProjectivePallas => "t");

        decl_func!(w, env, caml_pallas_one => "one");
        decl_func!(w, env, caml_pallas_add => "add");
        decl_func!(w, env, caml_pallas_sub => "sub");
        decl_func!(w, env, caml_pallas_negate => "negate");
        decl_func!(w, env, caml_pallas_double => "double");
        decl_func!(w, env, caml_pallas_scale => "scale");
        decl_func!(w, env, caml_pallas_random => "random");
        decl_func!(w, env, caml_pallas_rng => "rng");
        decl_func!(w, env, caml_pallas_endo_base => "endo_base");
        decl_func!(w, env, caml_pallas_endo_scalar => "endo_scalar");
        decl_func!(w, env, caml_pallas_to_affine => "to_affine");
        decl_func!(w, env, caml_pallas_of_affine => "of_affine");
        decl_func!(w, env, caml_pallas_of_affine_coordinates => "of_affine_coordinates");
        decl_func!(w, env, caml_pallas_affine_deep_copy => "deep_copy");
    });
}

fn generate_kimchi_bindings(mut w: impl std::io::Write, env: &mut Env) {
    decl_module!(w, env, "FieldVectors", {
        decl_module!(w, env, "Fp", {
            decl_type!(w, env, CamlFpVector => "t");
            decl_type_alias!(w, env, "elt" => CamlFp);

            decl_func!(w, env, caml_fp_vector_create => "create");
            decl_func!(w, env, caml_fp_vector_length => "length");
            decl_func!(w, env, caml_fp_vector_emplace_back => "emplace_back");
            decl_func!(w, env, caml_fp_vector_get => "get");
            decl_func!(w, env, caml_fp_vector_set => "set");
        });

        decl_module!(w, env, "Fq", {
            decl_type!(w, env, CamlFqVector => "t");
            decl_type_alias!(w, env, "elt" => CamlFq);

            decl_func!(w, env, caml_fq_vector_create => "create");
            decl_func!(w, env, caml_fq_vector_length => "length");
            decl_func!(w, env, caml_fq_vector_emplace_back => "emplace_back");
            decl_func!(w, env, caml_fq_vector_get => "get");
            decl_func!(w, env, caml_fq_vector_set => "set");
        });
    });

    decl_module!(w, env, "Protocol", {
        decl_module!(w, env, "Gates", {
            decl_module!(w, env, "Vector", {
                decl_module!(w, env, "Fp", {
                    decl_type!(w, env, CamlPastaFpPlonkGateVector => "t");
                    decl_type_alias!(w, env, "elt" => CamlCircuitGate<CamlFp>);

                    decl_func!(w, env, caml_pasta_fp_plonk_gate_vector_create => "create");
                    decl_func!(w, env, caml_pasta_fp_plonk_gate_vector_add => "add");
                    decl_func!(w, env, caml_pasta_fp_plonk_gate_vector_get => "get");
                    decl_func!(w, env, caml_pasta_fp_plonk_gate_vector_wrap => "wrap");
                    decl_func!(w, env, caml_pasta_fp_plonk_gate_vector_digest => "digest");
                });
                decl_module!(w, env, "Fq", {
                    decl_type!(w, env, CamlPastaFqPlonkGateVector => "t");
                    decl_type_alias!(w, env, "elt" => CamlCircuitGate<CamlFq>);

                    decl_func!(w, env, caml_pasta_fq_plonk_gate_vector_create => "create");
                    decl_func!(w, env, caml_pasta_fq_plonk_gate_vector_add => "add");
                    decl_func!(w, env, caml_pasta_fq_plonk_gate_vector_get => "get");
                    decl_func!(w, env, caml_pasta_fq_plonk_gate_vector_wrap => "wrap");
                    decl_func!(w, env, caml_pasta_fq_plonk_gate_vector_digest => "digest");
                });
            });
        });

        decl_module!(w, env, "SRS", {
            decl_module!(w, env, "Fp", {
                decl_type!(w, env, CamlFpSrs => "t");

                decl_module!(w, env, "Poly_comm", {
                    decl_type_alias!(w, env, "t" => CamlPolyComm<CamlGroupAffine<CamlFp>>);
                });

                decl_func!(w, env, caml_fp_srs_create => "create");
                decl_func!(w, env, caml_fp_srs_write => "write");
                decl_func!(w, env, caml_fp_srs_read => "read");
                decl_func!(w, env, caml_fp_srs_lagrange_commitment => "lagrange_commitment");
                decl_func!(w, env, caml_fp_srs_add_lagrange_basis=> "add_lagrange_basis");
                decl_func!(w, env, caml_fp_srs_commit_evaluations => "commit_evaluations");
                decl_func!(w, env, caml_fp_srs_b_poly_commitment => "b_poly_commitment");
                decl_func!(w, env, caml_fp_srs_batch_accumulator_check => "batch_accumulator_check");
                decl_func!(w, env, caml_fp_srs_batch_accumulator_generate => "batch_accumulator_generate");
                decl_func!(w, env, caml_fp_srs_h => "urs_h");
            });

            decl_module!(w, env, "Fq", {
                decl_type!(w, env, CamlFqSrs => "t");

                decl_func!(w, env, caml_fq_srs_create => "create");
                decl_func!(w, env, caml_fq_srs_write => "write");
                decl_func!(w, env, caml_fq_srs_read => "read");
                decl_func!(w, env, caml_fq_srs_lagrange_commitment => "lagrange_commitment");
                decl_func!(w, env, caml_fq_srs_add_lagrange_basis=> "add_lagrange_basis");
                decl_func!(w, env, caml_fq_srs_commit_evaluations => "commit_evaluations");
                decl_func!(w, env, caml_fq_srs_b_poly_commitment => "b_poly_commitment");
                decl_func!(w, env, caml_fq_srs_batch_accumulator_check => "batch_accumulator_check");
                decl_func!(w, env, caml_fq_srs_batch_accumulator_generate => "batch_accumulator_generate");
                decl_func!(w, env, caml_fq_srs_h => "urs_h");
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

        decl_module!(w, env, "VerifierIndex", {
            decl_module!(w, env, "Fp", {
                decl_type_alias!(w, env, "t" => CamlPlonkVerifierIndex<CamlFp, CamlFpSrs, CamlPolyComm<CamlGVesta>>);

                decl_func!(w, env, caml_pasta_fp_plonk_verifier_index_create => "create");
                decl_func!(w, env, caml_pasta_fp_plonk_verifier_index_read => "read");
                decl_func!(w, env, caml_pasta_fp_plonk_verifier_index_write => "write");
                decl_func!(w, env, caml_pasta_fp_plonk_verifier_index_shifts => "shifts");
                decl_func!(w, env, caml_pasta_fp_plonk_verifier_index_dummy => "dummy");
                decl_func!(w, env, caml_pasta_fp_plonk_verifier_index_deep_copy => "deep_copy");
            });

            decl_module!(w, env, "Fq", {
                decl_type_alias!(w, env, "t" => CamlPlonkVerifierIndex<CamlFq, CamlFqSrs, CamlPolyComm<CamlGPallas>>);

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
                decl_type_alias!(w, env, "t" => CamlOracles<CamlFp>);

                decl_func!(w, env, fp_oracles_create => "create");
                decl_func!(w, env, fp_oracles_dummy => "dummy");
                decl_func!(w, env, fp_oracles_deep_copy => "deep_copy");
            });

            decl_module!(w, env, "Fq", {
                decl_type_alias!(w, env, "t" => CamlOracles<CamlFq>);

                decl_func!(w, env, fq_oracles_create => "create");
                decl_func!(w, env, fq_oracles_dummy => "dummy");
                decl_func!(w, env, fq_oracles_deep_copy => "deep_copy");
            });
        });

        decl_module!(w, env, "Proof", {
            decl_module!(w, env, "Fp", {
                decl_func!(w, env, caml_pasta_fp_plonk_proof_create => "create");
                decl_func!(w, env, caml_pasta_fp_plonk_proof_example_with_lookup => "example_with_lookup");
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
