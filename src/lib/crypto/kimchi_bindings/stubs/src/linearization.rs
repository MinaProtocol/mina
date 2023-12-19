use kimchi::{
    circuits::{
        constraints::FeatureFlags,
        expr::Linearization,
        lookup::lookups::{LookupFeatures, LookupPatterns},
    },
    linearization::{constraints_expr, linearization_columns},
};

/// Converts the linearization of the kimchi circuit polynomial into a printable string.
pub fn linearization_strings<F: ark_ff::PrimeField + ark_ff::SquareRootField>(
    uses_custom_gates: bool,
) -> (String, Vec<(String, String)>) {
    let features = if uses_custom_gates {
        None
    } else {
        Some(FeatureFlags {
            range_check0: false,
            range_check1: false,
            foreign_field_add: false,
            foreign_field_mul: false,
            xor: false,
            rot: false,
            lookup_features: LookupFeatures {
                patterns: LookupPatterns {
                    xor: false,
                    lookup: false,
                    range_check: false,
                    foreign_field_mul: false,
                },
                joint_lookup_used: false,
                uses_runtime_tables: false,
            },
        })
    };
    let evaluated_cols = linearization_columns::<F>(features.as_ref());
    let (linearization, _powers_of_alpha) = constraints_expr::<F>(features.as_ref(), true);

    let Linearization {
        constant_term,
        mut index_terms,
    } = linearization.linearize(evaluated_cols).unwrap();

    // HashMap deliberately uses an unstable order; here we sort to ensure that the output is
    // consistent when printing.
    index_terms.sort_by(|(x, _), (y, _)| x.cmp(y));

    let constant = constant_term.ocaml_str();
    let other_terms = index_terms
        .iter()
        .map(|(col, expr)| (format!("{:?}", col), expr.ocaml_str()))
        .collect();

    (constant, other_terms)
}

#[ocaml::func]
pub fn fp_linearization_strings() -> (String, Vec<(String, String)>) {
    linearization_strings::<mina_curves::pasta::Fp>(true)
}

#[ocaml::func]
pub fn fq_linearization_strings() -> (String, Vec<(String, String)>) {
    linearization_strings::<mina_curves::pasta::Fq>(false)
}
