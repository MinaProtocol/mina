use ocaml_gen::OcamlGen;

#[derive(ocaml::IntoValue, ocaml::FromValue, OcamlGen)]
pub struct CamlPlonkDomain<Fr> {
    pub log_size_of_group: ocaml::Int,
    pub group_gen: Fr,
}

#[derive(ocaml::IntoValue, ocaml::FromValue, OcamlGen)]
pub struct CamlPlonkVerificationEvals<PolyComm> {
    pub sigma_comm: Vec<PolyComm>,
    pub coefficients_comm: Vec<PolyComm>,
    pub generic_comm: PolyComm,
    pub psm_comm: PolyComm,
    pub add_comm: PolyComm,
    pub double_comm: PolyComm,
    pub mul_comm: PolyComm,
    pub emul_comm: PolyComm,
}

#[derive(ocaml::IntoValue, ocaml::FromValue, OcamlGen)]
pub struct CamlPlonkVerifierIndex<Fr, SRS, PolyComm> {
    pub domain: CamlPlonkDomain<Fr>,
    pub max_poly_size: ocaml::Int,
    pub max_quot_size: ocaml::Int,
    pub srs: SRS,
    pub evals: CamlPlonkVerificationEvals<PolyComm>,
    pub shifts: Vec<Fr>,
}
