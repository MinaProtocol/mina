use kimchi::{
    circuits::expr::Linearization,
    linearization::{constraints_expr, linearization_columns},
};

/// Converts the linearization of the kimchi circuit polynomial into a printable string.
pub fn linearization_strings<F: ark_ff::PrimeField + ark_ff::SquareRootField>(
) -> (String, Vec<(String, String)>) {
    let d1 = ark_poly::EvaluationDomain::<F>::new(1).unwrap();
    let evaluated_cols = linearization_columns::<F>(&None);
    let (linearization, _powers_of_alpha) = constraints_expr(d1, false, &None);

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

#[ocaml::func]
pub fn fp_linearization_strings() -> (String, Vec<(String, String)>) {
    linearization_strings::<mina_curves::pasta::Fp>()
}

#[ocaml::func]
pub fn fq_linearization_strings() -> (String, Vec<(String, String)>) {
    linearization_strings::<mina_curves::pasta::Fq>()
}
