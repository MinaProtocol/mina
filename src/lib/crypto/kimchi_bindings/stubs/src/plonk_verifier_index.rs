use ark_ec::AffineCurve;
use commitment_dlog::{commitment::CommitmentCurve, PolyComm};
use kimchi::circuits::gate::LookupsUsed;
use kimchi::verifier_index::LookupVerifierIndex;

#[derive(ocaml::IntoValue, ocaml::FromValue, ocaml_gen::Struct)]
pub struct CamlPlonkDomain<Fr> {
    pub log_size_of_group: ocaml::Int,
    pub group_gen: Fr,
}

#[derive(ocaml::IntoValue, ocaml::FromValue, ocaml_gen::Struct)]
pub struct CamlPlonkVerificationEvals<PolyComm> {
    pub sigma_comm: Vec<PolyComm>,
    pub coefficients_comm: Vec<PolyComm>,
    pub generic_comm: PolyComm,
    pub psm_comm: PolyComm,
    pub complete_add_comm: PolyComm,
    pub mul_comm: PolyComm,
    pub emul_comm: PolyComm,
    pub endomul_scalar_comm: PolyComm,
    pub chacha_comm: Option<Vec<PolyComm>>,
}

#[derive(ocaml::IntoValue, ocaml::FromValue, ocaml_gen::Enum)]
pub enum CamlLookupsUsed {
    Single,
    Joint,
}

#[derive(ocaml::IntoValue, ocaml::FromValue, ocaml_gen::Struct)]
pub struct CamlLookupVerifierIndex<PolyComm> {
    pub lookup_used: CamlLookupsUsed,
    pub lookup_tables: Vec<Vec<PolyComm>>,
    pub lookup_selectors: Vec<PolyComm>,
}

impl<G, CamlPolyComm> From<LookupVerifierIndex<G>> for CamlLookupVerifierIndex<CamlPolyComm>
where
    G: AffineCurve + CommitmentCurve,
    CamlPolyComm: From<PolyComm<G>>,
{
    fn from(li: LookupVerifierIndex<G>) -> Self {
        let LookupVerifierIndex {
            lookup_used,
            lookup_tables,
            lookup_selectors,
        } = li;
        CamlLookupVerifierIndex {
            lookup_used: {
                match lookup_used {
                    LookupsUsed::Single => CamlLookupsUsed::Single,
                    LookupsUsed::Joint => CamlLookupsUsed::Joint,
                }
            },
            lookup_tables: lookup_tables
                .into_iter()
                .map(|tbl| tbl.into_iter().map(From::from).collect())
                .collect(),
            lookup_selectors: lookup_selectors.into_iter().map(From::from).collect(),
        }
    }
}

impl<G, CamlPolyComm> From<CamlLookupVerifierIndex<CamlPolyComm>> for LookupVerifierIndex<G>
where
    G: AffineCurve + CommitmentCurve,
    PolyComm<G>: From<CamlPolyComm>,
{
    fn from(li: CamlLookupVerifierIndex<CamlPolyComm>) -> Self {
        let CamlLookupVerifierIndex {
            lookup_used,
            lookup_tables,
            lookup_selectors,
        } = li;
        LookupVerifierIndex {
            lookup_used: {
                match lookup_used {
                    CamlLookupsUsed::Single => LookupsUsed::Single,
                    CamlLookupsUsed::Joint => LookupsUsed::Joint,
                }
            },
            lookup_tables: lookup_tables
                .into_iter()
                .map(|tbl| tbl.into_iter().map(From::from).collect())
                .collect(),
            lookup_selectors: lookup_selectors.into_iter().map(From::from).collect(),
        }
    }
}

#[derive(ocaml::IntoValue, ocaml::FromValue, ocaml_gen::Struct)]
pub struct CamlPlonkVerifierIndex<Fr, SRS, PolyComm> {
    pub domain: CamlPlonkDomain<Fr>,
    pub max_poly_size: ocaml::Int,
    pub max_quot_size: ocaml::Int,
    pub srs: SRS,
    pub evals: CamlPlonkVerificationEvals<PolyComm>,
    pub shifts: Vec<Fr>,
    pub lookup_index: Option<CamlLookupVerifierIndex<PolyComm>>,
}
