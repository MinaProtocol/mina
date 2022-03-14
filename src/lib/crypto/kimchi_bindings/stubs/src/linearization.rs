use kimchi::{
    circuits::{
        expr::Linearization,
        lookup::constraints::LookupConfiguration,
        lookup::lookups::{JointLookup, LookupsUsed},
    },
    linearization::{constraints_expr, linearization_columns},
};

/// Converts the linearization of the kimchi circuit polynomial into a printable string.
pub fn linearization_strings<F: ark_ff::PrimeField + ark_ff::SquareRootField>(
    lookup_configuration: Option<&LookupConfiguration<F>>,
) -> (String, Vec<(String, String)>) {
    let d1 = ark_poly::EvaluationDomain::<F>::new(1).unwrap();
    let evaluated_cols = linearization_columns::<F>(lookup_configuration);
    let (linearization, _powers_of_alpha) = constraints_expr(d1, false, lookup_configuration);

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
        .map(|(col, expr)| (format!("{:?}", col), format!("{}", expr.ocaml_str())))
        .collect();

    (constant, other_terms)
}

pub fn lookup_gate_config<F: ark_ff::PrimeField + ark_ff::SquareRootField>(
) -> LookupConfiguration<F> {
    LookupConfiguration {
        lookup_used: LookupsUsed::Joint,

        max_lookups_per_row: 4,
        max_joint_size: 2,

        dummy_lookup: JointLookup {
            table_id: F::zero(),
            entry: vec![],
        },
    }
}

#[ocaml::func]
pub fn fp_linearization_strings() -> (String, Vec<(String, String)>) {
    linearization_strings::<mina_curves::pasta::Fp>(None)
}

#[ocaml::func]
pub fn fq_linearization_strings() -> (String, Vec<(String, String)>) {
    linearization_strings::<mina_curves::pasta::Fq>(None)
}

#[ocaml::func]
pub fn fp_lookup_gate_linearization_strings() -> (String, Vec<(String, String)>) {
    linearization_strings::<mina_curves::pasta::Fp>(Some(&lookup_gate_config()))
}

#[ocaml::func]
pub fn fq_lookup_gate_linearization_strings() -> (String, Vec<(String, String)>) {
    linearization_strings::<mina_curves::pasta::Fq>(Some(&lookup_gate_config()))
}
