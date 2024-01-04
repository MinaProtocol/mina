use kimchi::{
    circuits::{
        gate::GateType,
        constraints::FeatureFlags,
        expr::{Linearization, PolishToken},
        lookup::lookups::{LookupFeatures, LookupPatterns},
    },
    linearization::{constraints_expr, linearization_columns},
};

/// Converts the linearization of the kimchi circuit polynomial into a printable string.
pub fn linearization_strings<F: ark_ff::PrimeField + ark_ff::SquareRootField>(
    // omit_custom_gate: bool,
    custom_gate_type: Option<&Vec<PolishToken<F>>>,
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
    let (linearization, _powers_of_alpha) =
        constraints_expr::<F>(/* omit_custom_gate */ false, custom_gate_type, features.as_ref(), true);

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
pub fn fp_linearization_strings_plus() -> (String, Vec<(String, String)>) {
    // Define conditional gate in RPN
    //     w(0) = w(1) * w(3) + (1 - w(3)) * w(2)
    use kimchi::circuits::expr::{PolishToken::*, *};
    use kimchi::circuits::gate::CurrOrNext::Curr;
    let conditional_gate = Some(vec![
        Cell(Variable {
            col: Column::Index(GateType::ForeignFieldAdd),
            row: Curr,
        }),
        Cell(Variable {
            col: Column::Witness(3),
            row: Curr,
        }),
        Dup,
        Mul,
        Cell(Variable {
            col: Column::Witness(3),
            row: Curr,
        }),
        Sub,
        Alpha,
        Pow(1),
        Cell(Variable {
            col: Column::Witness(0),
            row: Curr,
        }),
        Cell(Variable {
            col: Column::Witness(3),
            row: Curr,
        }),
        Cell(Variable {
            col: Column::Witness(1),
            row: Curr,
        }),
        Mul,
        Literal(mina_curves::pasta::Fp::from(1u32)),
        Cell(Variable {
            col: Column::Witness(3),
            row: Curr,
        }),
        Sub,
        Cell(Variable {
            col: Column::Witness(2),
            row: Curr,
        }),
        Mul,
        Add,
        Sub,
        Mul,
        Add,
        Mul,
    ]);

    linearization_strings::<mina_curves::pasta::Fp>(conditional_gate.as_ref(), true)
}

#[ocaml::func]
pub fn fq_linearization_strings_plus() -> (String, Vec<(String, String)>) {
    linearization_strings::<mina_curves::pasta::Fq>(None, false)
}


#[ocaml::func]
pub fn fp_linearization_strings_minus() -> (String, Vec<(String, String)>) {
    // linearization_strings::<mina_curves::pasta::Fp>(true, true)
    linearization_strings::<mina_curves::pasta::Fp>(None, true)
}

#[ocaml::func]
pub fn fq_linearization_strings_minus() -> (String, Vec<(String, String)>) {
    // linearization_strings::<mina_curves::pasta::Fq>(true, false)
    linearization_strings::<mina_curves::pasta::Fq>(None, false)
}

#[ocaml::func]
pub fn fp_linearization_strings() -> (String, Vec<(String, String)>) {
    // linearization_strings::<mina_curves::pasta::Fp>(false, true)
    linearization_strings::<mina_curves::pasta::Fp>(None, true)
}

#[ocaml::func]
pub fn fq_linearization_strings() -> (String, Vec<(String, String)>) {
    // linearization_strings::<mina_curves::pasta::Fq>(false, false)
    linearization_strings::<mina_curves::pasta::Fq>(None, false)
}
