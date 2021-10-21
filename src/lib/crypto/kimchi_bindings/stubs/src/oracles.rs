use plonk_15_wires_circuits::nolookup::scalars::caml::CamlRandomOracles;

#[derive(ocaml::IntoValue, ocaml::FromValue, ocaml_gen::Struct)]
pub struct CamlOracles<F> {
    pub o: CamlRandomOracles<F>,
    pub p_eval: (F, F),
    pub opening_prechallenges: Vec<F>,
    pub digest_before_evaluations: F,
}
