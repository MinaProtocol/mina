use ark_ec::AffineCurve;
use commitment_dlog::{commitment::CommitmentCurve, PolyComm};
use kimchi::circuits::lookup::index::LookupSelectors;
use kimchi::circuits::lookup::lookups::{LookupInfo, LookupPattern, LookupsUsed};
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
pub struct CamlLookupSelectors<T> {
    pub lookup_gate: Option<T>,
}

impl<G, CamlPolyComm> From<LookupSelectors<PolyComm<G>>> for CamlLookupSelectors<CamlPolyComm>
where
    G: AffineCurve + CommitmentCurve,
    CamlPolyComm: From<PolyComm<G>>,
{
    fn from(val: LookupSelectors<PolyComm<G>>) -> Self {
        let LookupSelectors {
            xor: _,
            chacha_final: _,
            lookup_gate,
            range_check_gate: _,
            ffmul_gate: _,
        } = val;
        CamlLookupSelectors {
            lookup_gate: lookup_gate.map(From::from),
        }
    }
}

impl<G, CamlPolyComm> From<CamlLookupSelectors<CamlPolyComm>> for LookupSelectors<PolyComm<G>>
where
    G: AffineCurve + CommitmentCurve,
    PolyComm<G>: From<CamlPolyComm>,
{
    fn from(val: CamlLookupSelectors<CamlPolyComm>) -> Self {
        let CamlLookupSelectors { lookup_gate } = val;
        LookupSelectors {
            xor: None,
            chacha_final: None,
            lookup_gate: lookup_gate.map(From::from),
            range_check_gate: None,
            ffmul_gate: None,
        }
    }
}

#[derive(ocaml::IntoValue, ocaml::FromValue, ocaml_gen::Struct)]
pub struct CamlLookupInfo {
    /// A single lookup constraint is a vector of lookup constraints to be applied at a row.
    /// This is a vector of all the kinds of lookup constraints in this configuration.
    pub kinds: Vec<LookupPattern>,
    /// The maximum length of an element of `kinds`. This can be computed from `kinds`.
    pub max_per_row: ocaml::Int,
    /// The maximum joint size of any joint lookup in a constraint in `kinds`. This can be computed from `kinds`.
    pub max_joint_size: ocaml::Int,
    /// True if runtime lookup tables are used.
    pub uses_runtime_tables: bool,
}

impl From<LookupInfo> for CamlLookupInfo {
    fn from(li: LookupInfo) -> CamlLookupInfo {
        let LookupInfo {
            kinds,
            max_per_row,
            max_joint_size,
            uses_runtime_tables,
        } = li;
        CamlLookupInfo {
            kinds,
            max_per_row: max_per_row as ocaml::Int,
            max_joint_size: max_joint_size as ocaml::Int,
            uses_runtime_tables,
        }
    }
}

impl From<CamlLookupInfo> for LookupInfo {
    fn from(li: CamlLookupInfo) -> LookupInfo {
        let CamlLookupInfo {
            kinds,
            max_per_row,
            max_joint_size,
            uses_runtime_tables,
        } = li;
        LookupInfo {
            kinds,
            max_per_row: max_per_row as usize,
            max_joint_size: max_joint_size as u32,
            uses_runtime_tables,
        }
    }
}

#[derive(ocaml::IntoValue, ocaml::FromValue, ocaml_gen::Struct)]
pub struct CamlLookupVerifierIndex<PolyComm> {
    pub lookup_used: CamlLookupsUsed,
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
            lookup_used,
            lookup_table,
            lookup_selectors,
            table_ids,
            lookup_info,
            runtime_tables_selector,
        } = li;
        CamlLookupVerifierIndex {
            lookup_used: {
                match lookup_used {
                    LookupsUsed::Single => CamlLookupsUsed::Single,
                    LookupsUsed::Joint => CamlLookupsUsed::Joint,
                }
            },
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
            lookup_used,
            lookup_table,
            lookup_selectors,
            table_ids,
            lookup_info,
            runtime_tables_selector,
        } = li;
        LookupVerifierIndex {
            lookup_used: {
                match lookup_used {
                    CamlLookupsUsed::Single => LookupsUsed::Single,
                    CamlLookupsUsed::Joint => LookupsUsed::Joint,
                }
            },
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
    pub max_quot_size: ocaml::Int,
    pub public: ocaml::Int,
    pub prev_challenges: ocaml::Int,
    pub srs: SRS,
    pub evals: CamlPlonkVerificationEvals<PolyComm>,
    pub shifts: Vec<Fr>,
    pub lookup_index: Option<CamlLookupVerifierIndex<PolyComm>>,
}
