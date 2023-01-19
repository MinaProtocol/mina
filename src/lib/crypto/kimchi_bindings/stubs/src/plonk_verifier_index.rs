use ark_ec::AffineCurve;
use kimchi::circuits::lookup::index::LookupSelectors;
use kimchi::circuits::lookup::lookups::{LookupFeatures, LookupInfo};
use kimchi::verifier_index::LookupVerifierIndex;
use poly_commitment::{commitment::CommitmentCurve, PolyComm};

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
    pub xor_comm: Option<PolyComm>,
    pub range_check0_comm: Option<PolyComm>,
    pub range_check1_comm: Option<PolyComm>,
    pub foreign_field_add_comm: Option<PolyComm>,
    pub foreign_field_mul_comm: Option<PolyComm>,
    pub rot_comm: Option<PolyComm>,
    pub lookup_gate_comm: Option<PolyComm>,
    pub runtime_tables_comm: Option<PolyComm>,
}

#[derive(ocaml::IntoValue, ocaml::FromValue, ocaml_gen::Enum)]
pub enum CamlLookupsUsed {
    Single,
    Joint,
}

#[derive(ocaml::IntoValue, ocaml::FromValue, ocaml_gen::Struct)]
pub struct CamlLookupSelectors<T> {
    pub lookup: Option<T>,
}

impl<G, CamlPolyComm> From<LookupSelectors<PolyComm<G>>> for CamlLookupSelectors<CamlPolyComm>
where
    G: AffineCurve + CommitmentCurve,
    CamlPolyComm: From<PolyComm<G>>,
{
    fn from(val: LookupSelectors<PolyComm<G>>) -> Self {
        let LookupSelectors {
            xor: _,
            lookup,
            range_check: _,
            ffmul: _,
        } = val;
        CamlLookupSelectors {
            lookup: lookup.map(From::from),
        }
    }
}

impl<G, CamlPolyComm> From<CamlLookupSelectors<CamlPolyComm>> for LookupSelectors<PolyComm<G>>
where
    G: AffineCurve + CommitmentCurve,
    PolyComm<G>: From<CamlPolyComm>,
{
    fn from(val: CamlLookupSelectors<CamlPolyComm>) -> Self {
        let CamlLookupSelectors { lookup } = val;
        LookupSelectors {
            xor: None,
            lookup: lookup.map(From::from),
            range_check: None,
            ffmul: None,
        }
    }
}

#[derive(ocaml::IntoValue, ocaml::FromValue, ocaml_gen::Struct)]
pub struct CamlLookupInfo {
    /// The maximum length of an element of `kinds`. This can be computed from `kinds`.
    pub max_per_row: ocaml::Int,
    /// The maximum joint size of any joint lookup in a constraint in `kinds`. This can be computed from `kinds`.
    pub max_joint_size: ocaml::Int,
    pub features: LookupFeatures,
}

impl From<LookupInfo> for CamlLookupInfo {
    fn from(li: LookupInfo) -> CamlLookupInfo {
        let LookupInfo {
            features,
            max_per_row,
            max_joint_size,
        } = li;
        CamlLookupInfo {
            features,
            max_per_row: max_per_row as ocaml::Int,
            max_joint_size: max_joint_size as ocaml::Int,
        }
    }
}

impl From<CamlLookupInfo> for LookupInfo {
    fn from(li: CamlLookupInfo) -> LookupInfo {
        let CamlLookupInfo {
            features,
            max_per_row,
            max_joint_size,
        } = li;
        LookupInfo {
            features,
            max_per_row: max_per_row as usize,
            max_joint_size: max_joint_size as u32,
        }
    }
}

#[derive(ocaml::IntoValue, ocaml::FromValue, ocaml_gen::Struct)]
pub struct CamlLookupVerifierIndex<PolyComm> {
    pub joint_lookup_used: bool,
    pub lookup_table: Vec<PolyComm>,
    pub lookup_selectors: CamlLookupSelectors<PolyComm>,
    pub table_ids: Option<PolyComm>,
    pub lookup_info: CamlLookupInfo,
    pub runtime_tables_selector: Option<PolyComm>,
}

impl<G, CamlPolyComm> From<LookupVerifierIndex<G>> for CamlLookupVerifierIndex<CamlPolyComm>
where
    G: AffineCurve + CommitmentCurve,
    CamlPolyComm: From<PolyComm<G>>,
{
    fn from(li: LookupVerifierIndex<G>) -> Self {
        let LookupVerifierIndex {
            joint_lookup_used,
            lookup_table,
            lookup_selectors,
            table_ids,
            lookup_info,
            runtime_tables_selector,
        } = li;
        CamlLookupVerifierIndex {
            joint_lookup_used,
            lookup_table: lookup_table.into_iter().map(From::from).collect(),

            lookup_selectors: lookup_selectors.into(),
            table_ids: table_ids.map(From::from),
            lookup_info: lookup_info.into(),
            runtime_tables_selector: runtime_tables_selector.map(From::from),
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
            joint_lookup_used,
            lookup_table,
            lookup_selectors,
            table_ids,
            lookup_info,
            runtime_tables_selector,
        } = li;
        LookupVerifierIndex {
            joint_lookup_used,
            lookup_table: lookup_table.into_iter().map(From::from).collect(),
            lookup_selectors: lookup_selectors.into(),
            table_ids: table_ids.map(From::from),
            lookup_info: lookup_info.into(),
            runtime_tables_selector: runtime_tables_selector.map(From::from),
        }
    }
}

#[derive(ocaml::IntoValue, ocaml::FromValue, ocaml_gen::Struct)]
pub struct CamlPlonkVerifierIndex<Fr, SRS, PolyComm> {
    pub domain: CamlPlonkDomain<Fr>,
    pub max_poly_size: ocaml::Int,
    pub public: ocaml::Int,
    pub prev_challenges: ocaml::Int,
    pub srs: SRS,
    pub evals: CamlPlonkVerificationEvals<PolyComm>,
    pub shifts: Vec<Fr>,
    pub lookup_index: Option<CamlLookupVerifierIndex<PolyComm>>,
}
