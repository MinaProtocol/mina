use crate::wasm_vector::WasmVector;
use ark_ec::AffineCurve;
use ark_ff::One;
use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use array_init::array_init;
use kimchi::circuits::{
    constraints::FeatureFlags,
    lookup::index::LookupSelectors,
    lookup::lookups::{LookupFeatures, LookupInfo, LookupPatterns},
    polynomials::permutation::Shifts,
    polynomials::permutation::{zk_polynomial, zk_w3},
    wires::{COLUMNS, PERMUTS},
};
use kimchi::linearization::expr_linearization;
use kimchi::verifier_index::{LookupVerifierIndex, VerifierIndex as DlogVerifierIndex};
use paste::paste;
use poly_commitment::srs::SRS;
use poly_commitment::commitment::PolyComm;
use std::path::Path;
use std::sync::Arc;
use wasm_bindgen::prelude::*;

macro_rules! impl_verification_key {
    (
     $name: ident,
     $WasmG: ty,
     $G: ty,
     $WasmF: ty,
     $F: ty,
     $WasmPolyComm: ty,
     $WasmSrs: ty,
     $GOther: ty,
     $FrSpongeParams: path,
     $FqSpongeParams: path,
     $WasmIndex: ty,
     $field_name: ident
     ) => {
        paste! {
            #[wasm_bindgen]
            #[derive(Clone, Copy)]
            pub struct [<Wasm $field_name:camel Domain>] {
                pub log_size_of_group: i32,
                pub group_gen: $WasmF,
            }
            type WasmDomain = [<Wasm $field_name:camel Domain>];

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel Domain>]{
                #[wasm_bindgen(constructor)]
                pub fn new(log_size_of_group: i32, group_gen: $WasmF) -> Self {
                    WasmDomain {log_size_of_group, group_gen}
                }
            }

            #[wasm_bindgen]
            #[derive(Clone)]
            pub struct [<Wasm $field_name:camel PlonkVerificationEvals>] {
                #[wasm_bindgen(skip)]
                pub sigma_comm: WasmVector<$WasmPolyComm>,
                #[wasm_bindgen(skip)]
                pub coefficients_comm: WasmVector<$WasmPolyComm>,
                #[wasm_bindgen(skip)]
                pub generic_comm: $WasmPolyComm,
                #[wasm_bindgen(skip)]
                pub psm_comm: $WasmPolyComm,
                #[wasm_bindgen(skip)]
                pub complete_add_comm: $WasmPolyComm,
                #[wasm_bindgen(skip)]
                pub mul_comm: $WasmPolyComm,
                #[wasm_bindgen(skip)]
                pub emul_comm: $WasmPolyComm,
                #[wasm_bindgen(skip)]
                pub endomul_scalar_comm: $WasmPolyComm,
            }
            type WasmPlonkVerificationEvals = [<Wasm $field_name:camel PlonkVerificationEvals>];

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel PlonkVerificationEvals>] {
                #[wasm_bindgen(constructor)]
                pub fn new(
                    sigma_comm: WasmVector<$WasmPolyComm>,
                    coefficients_comm: WasmVector<$WasmPolyComm>,
                    generic_comm: &$WasmPolyComm,
                    psm_comm: &$WasmPolyComm,
                    complete_add_comm: &$WasmPolyComm,
                    mul_comm: &$WasmPolyComm,
                    emul_comm: &$WasmPolyComm,
                    endomul_scalar_comm: &$WasmPolyComm,
                    ) -> Self {
                    WasmPlonkVerificationEvals {
                        sigma_comm: sigma_comm.clone(),
                        coefficients_comm: coefficients_comm.clone(),
                        generic_comm: generic_comm.clone(),
                        psm_comm: psm_comm.clone(),
                        complete_add_comm: complete_add_comm.clone(),
                        mul_comm: mul_comm.clone(),
                        emul_comm: emul_comm.clone(),
                        endomul_scalar_comm: endomul_scalar_comm.clone(),
                    }
                }

                #[wasm_bindgen(getter)]
                pub fn sigma_comm(&self) -> WasmVector<$WasmPolyComm> {
                    self.sigma_comm.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_sigma_comm(&mut self, x: WasmVector<$WasmPolyComm>) {
                    self.sigma_comm = x;
                }

                #[wasm_bindgen(getter)]
                pub fn coefficients_comm(&self) -> WasmVector<$WasmPolyComm> {
                    self.coefficients_comm.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_coefficients_comm(&mut self, x: WasmVector<$WasmPolyComm>) {
                    self.coefficients_comm = x;
                }

                #[wasm_bindgen(getter)]
                pub fn generic_comm(&self) -> $WasmPolyComm {
                    self.generic_comm.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_generic_comm(&mut self, x: $WasmPolyComm) {
                    self.generic_comm = x;
                }

                #[wasm_bindgen(getter)]
                pub fn psm_comm(&self) -> $WasmPolyComm {
                    self.psm_comm.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_psm_comm(&mut self, x: $WasmPolyComm) {
                    self.psm_comm = x;
                }

                #[wasm_bindgen(getter)]
                pub fn complete_add_comm(&self) -> $WasmPolyComm {
                    self.complete_add_comm.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_complete_add_comm(&mut self, x: $WasmPolyComm) {
                    self.complete_add_comm = x;
                }

                #[wasm_bindgen(getter)]
                pub fn mul_comm(&self) -> $WasmPolyComm {
                    self.mul_comm.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_mul_comm(&mut self, x: $WasmPolyComm) {
                    self.mul_comm = x;
                }

                #[wasm_bindgen(getter)]
                pub fn emul_comm(&self) -> $WasmPolyComm {
                    self.emul_comm.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_emul_comm(&mut self, x: $WasmPolyComm) {
                    self.emul_comm = x;
                }

                #[wasm_bindgen(getter)]
                pub fn endomul_scalar_comm(&self) -> $WasmPolyComm {
                    self.endomul_scalar_comm.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_endomul_scalar_comm(&mut self, x: $WasmPolyComm) {
                    self.endomul_scalar_comm = x;
                }
            }

            #[derive(Clone, Copy)]
            #[wasm_bindgen]
            pub struct [<Wasm $field_name:camel Shifts>] {
                pub s0: $WasmF,
                pub s1: $WasmF,
                pub s2: $WasmF,
                pub s3: $WasmF,
                pub s4: $WasmF,
                pub s5: $WasmF,
                pub s6: $WasmF,
            }
            type WasmShifts = [<Wasm $field_name:camel Shifts>];

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel Shifts>] {
                #[wasm_bindgen(constructor)]
                pub fn new(
                    s0: $WasmF,
                    s1: $WasmF,
                    s2: $WasmF,
                    s3: $WasmF,
                    s4: $WasmF,
                    s5: $WasmF,
                    s6: $WasmF
                ) -> Self {
                    Self { s0, s1, s2, s3, s4, s5, s6}
                }
            }

            #[wasm_bindgen]
            #[derive(Clone)]
            pub struct [<Wasm $field_name:camel LookupSelectors>] {
                #[wasm_bindgen(skip)]
                pub xor: Option<$WasmPolyComm>,
                #[wasm_bindgen(skip)]
                pub lookup : Option<$WasmPolyComm>,
                #[wasm_bindgen(skip)]
                pub range_check: Option<$WasmPolyComm>,
                #[wasm_bindgen(skip)]
                pub ffmul: Option<$WasmPolyComm>,
            }

            type WasmLookupSelectors = [<Wasm $field_name:camel LookupSelectors>];

            impl From<WasmLookupSelectors> for LookupSelectors<PolyComm<$G>> {
                fn from(x: WasmLookupSelectors) -> Self {
                    Self {
                        xor: x.xor.map(Into::into),
                        lookup: x.lookup.map(Into::into),
                        range_check: x.range_check.map(Into::into),
                        ffmul: x.ffmul.map(Into::into),
                    }
                }
            }

            impl From<&WasmLookupSelectors> for LookupSelectors<PolyComm<$G>> {
                fn from(x: &WasmLookupSelectors) -> Self {
                    Self {
                        xor: x.xor.clone().map(Into::into),
                        lookup: x.lookup.clone().map(Into::into),
                        range_check: x.range_check.clone().map(Into::into),
                        ffmul: x.ffmul.clone().map(Into::into),
                    }
                }
            }

            impl From<&LookupSelectors<PolyComm<$G>>> for WasmLookupSelectors {
                fn from(x: &LookupSelectors<PolyComm<$G>>) -> Self {
                    Self {
                        xor: x.xor.clone().map(Into::into),
                        lookup: x.lookup.clone().map(Into::into),
                        range_check: x.range_check.clone().map(Into::into),
                        ffmul: x.ffmul.clone().map(Into::into),
                    }
                }
            }

            impl From<LookupSelectors<PolyComm<$G>>> for WasmLookupSelectors {
                fn from(x: LookupSelectors<PolyComm<$G>>) -> Self {
                    Self {
                        xor: x.xor.clone().map(Into::into),
                        lookup: x.lookup.clone().map(Into::into),
                        range_check: x.range_check.clone().map(Into::into),
                        ffmul: x.ffmul.clone().map(Into::into),
                    }
                }
            }

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel LookupSelectors>] {
                #[wasm_bindgen(constructor)]
                pub fn new(
                    xor: Option<$WasmPolyComm>,
                    lookup: Option<$WasmPolyComm>,
                    range_check: Option<$WasmPolyComm>,
                    ffmul: Option<$WasmPolyComm>
                ) -> Self {
                    Self {
                        xor,
                        lookup,
                        range_check,
                        ffmul
                    }
                }

                #[wasm_bindgen(getter)]
                pub fn xor(&self) -> Option<$WasmPolyComm> {
                    self.xor.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_xor(&mut self, x: Option<$WasmPolyComm>) {
                    self.xor = x
                }

                #[wasm_bindgen(getter)]
                pub fn lookup(&self) -> Option<$WasmPolyComm> {
                    self.lookup.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_lookup(&mut self, x: Option<$WasmPolyComm>) {
                    self.lookup = x
                }

                #[wasm_bindgen(getter)]
                pub fn ffmul(&self) -> Option<$WasmPolyComm> {
                    self.ffmul.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_ffmul(&mut self, x: Option<$WasmPolyComm>) {
                    self.ffmul = x
                }

                #[wasm_bindgen(getter)]
                pub fn range_check(&self) -> Option<$WasmPolyComm> {
                    self.range_check.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_range_check(&mut self, x: Option<$WasmPolyComm>) {
                    self.range_check = x
                }
            }

            #[wasm_bindgen]
            #[derive(Clone)]
            pub struct [<Wasm $field_name:camel LookupVerifierIndex>] {
                pub joint_lookup_used: bool,

                #[wasm_bindgen(skip)]
                pub lookup_table: WasmVector<$WasmPolyComm>,

                #[wasm_bindgen(skip)]
                pub lookup_selectors: WasmLookupSelectors,

                #[wasm_bindgen(skip)]
                pub table_ids: Option<$WasmPolyComm>,

                #[wasm_bindgen(skip)]
                pub lookup_info: LookupInfo,

                #[wasm_bindgen(skip)]
                pub runtime_tables_selector: Option<$WasmPolyComm>,
            }

            type WasmLookupVerifierIndex = [<Wasm $field_name:camel LookupVerifierIndex>];

            impl From<&LookupVerifierIndex<$G>> for WasmLookupVerifierIndex {
                fn from(x: &LookupVerifierIndex<$G>) -> Self {
                    Self {
                        joint_lookup_used: x.joint_lookup_used.into(),
                        lookup_table: x.lookup_table.clone().iter().map(Into::into).collect(),
                        lookup_selectors: x.lookup_selectors.clone().into(),
                        table_ids: x.table_ids.clone().map(Into::into),
                        lookup_info: x.lookup_info.clone(),
                        runtime_tables_selector: x.runtime_tables_selector.clone().map(Into::into)
                    }
                }
            }

            impl From<LookupVerifierIndex<$G>> for WasmLookupVerifierIndex {
                fn from(x: LookupVerifierIndex<$G>) -> Self {
                    Self {
                        joint_lookup_used: x.joint_lookup_used.into(),
                        lookup_table: x.lookup_table.iter().map(Into::into).collect(),
                        lookup_selectors: x.lookup_selectors.into(),
                        table_ids: x.table_ids.map(Into::into),
                        lookup_info: x.lookup_info,
                        runtime_tables_selector: x.runtime_tables_selector.map(Into::into)
                    }
                }
            }


            impl From<&WasmLookupVerifierIndex> for LookupVerifierIndex<$G> {
                fn from(x: &WasmLookupVerifierIndex) -> Self {
                    Self {
                        joint_lookup_used: x.joint_lookup_used.into(),
                        lookup_table: x.lookup_table.clone().iter().map(Into::into).collect(),
                        lookup_selectors: x.lookup_selectors.clone().into(),
                        table_ids: x.table_ids.clone().map(Into::into),
                        lookup_info: x.lookup_info,
                        runtime_tables_selector: x.runtime_tables_selector.clone().map(Into::into)
                    }
                }
            }

            impl From<WasmLookupVerifierIndex> for LookupVerifierIndex<$G> {
                fn from(x: WasmLookupVerifierIndex) -> Self {
                    Self {
                        joint_lookup_used: x.joint_lookup_used.into(),
                        lookup_table: x.lookup_table.iter().map(Into::into).collect(),
                        lookup_selectors: x.lookup_selectors.into(),
                        table_ids: x.table_ids.map(Into::into),
                        lookup_info: x.lookup_info,
                        runtime_tables_selector: x.runtime_tables_selector.map(Into::into)
                    }
                }
            }

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel LookupVerifierIndex>] {
                #[wasm_bindgen(constructor)]
                pub fn new(
                    joint_lookup_used: bool,
                    lookup_table: WasmVector<$WasmPolyComm>,
                    lookup_selectors: WasmLookupSelectors,
                    table_ids: Option<$WasmPolyComm>,
                    lookup_info: LookupInfo,
                    runtime_tables_selector: Option<$WasmPolyComm>
                ) -> WasmLookupVerifierIndex {
                    WasmLookupVerifierIndex {
                        joint_lookup_used,
                        lookup_table,
                        lookup_selectors,
                        table_ids,
                        lookup_info,
                        runtime_tables_selector
                    }
                }

                #[wasm_bindgen(getter)]
                pub fn lookup_table(&self) -> WasmVector<$WasmPolyComm> {
                    self.lookup_table.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_lookup_table(&mut self, x: WasmVector<$WasmPolyComm>) {
                    self.lookup_table = x
                }

                #[wasm_bindgen(getter)]
                pub fn lookup_selectors(&self) -> WasmLookupSelectors {
                    self.lookup_selectors.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_lookup_selectors(&mut self, x: WasmLookupSelectors) {
                    self.lookup_selectors = x
                }

                #[wasm_bindgen(getter)]
                pub fn table_ids(&self) -> Option<$WasmPolyComm>{
                    self.table_ids.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_table_ids(&mut self, x: Option<$WasmPolyComm>) {
                    self.table_ids = x
                }

                #[wasm_bindgen(getter)]
                pub fn runtime_tables_selector(&self) -> Option<$WasmPolyComm> {
                    self.runtime_tables_selector.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_runtime_tables_selector(&mut self, x: Option<$WasmPolyComm>) {
                    self.runtime_tables_selector = x
                }
            }

            #[wasm_bindgen]
            #[derive(Clone)]
            pub struct [<Wasm $field_name:camel PlonkVerifierIndex>] {
                pub domain: WasmDomain,
                pub max_poly_size: i32,
                pub public_: i32,
                pub prev_challenges: i32,
                #[wasm_bindgen(skip)]
                pub srs: $WasmSrs,
                #[wasm_bindgen(skip)]
                pub evals: WasmPlonkVerificationEvals,
                pub shifts: WasmShifts,
                #[wasm_bindgen(skip)]
                pub lookup_index: Option<WasmLookupVerifierIndex>,
            }
            type WasmPlonkVerifierIndex = [<Wasm $field_name:camel PlonkVerifierIndex>];

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel PlonkVerifierIndex>] {
                #[wasm_bindgen(constructor)]
                pub fn new(
                    domain: &WasmDomain,
                    max_poly_size: i32,
                    public_: i32,
                    prev_challenges: i32,
                    srs: &$WasmSrs,
                    evals: &WasmPlonkVerificationEvals,
                    shifts: &WasmShifts,
                    lookup_index: Option<WasmLookupVerifierIndex>,
                ) -> Self {
                    WasmPlonkVerifierIndex {
                        domain: domain.clone(),
                        max_poly_size,
                        public_,
                        prev_challenges,
                        srs: srs.clone(),
                        evals: evals.clone(),
                        shifts: shifts.clone(),
                        lookup_index: lookup_index.clone(),
                    }
                }

                #[wasm_bindgen(getter)]
                pub fn srs(&self) -> $WasmSrs {
                    self.srs.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_srs(&mut self, x: $WasmSrs) {
                    self.srs = x
                }

                #[wasm_bindgen(getter)]
                pub fn evals(&self) -> WasmPlonkVerificationEvals {
                    self.evals.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_evals(&mut self, x: WasmPlonkVerificationEvals) {
                    self.evals = x
                }

                #[wasm_bindgen(getter)]
                pub fn lookup_index(&self) -> Option<WasmLookupVerifierIndex> {
                    self.lookup_index.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_lookup_index(&mut self, li: Option<WasmLookupVerifierIndex>) {
                    self.lookup_index = li
                }
            }

            pub fn to_wasm<'a>(
                srs: &Arc<SRS<$G>>,
                vi: DlogVerifierIndex<$G>,
            ) -> WasmPlonkVerifierIndex {
                WasmPlonkVerifierIndex {
                    domain: WasmDomain {
                        log_size_of_group: vi.domain.log_size_of_group as i32,
                        group_gen: vi.domain.group_gen.into(),
                    },
                    max_poly_size: vi.max_poly_size as i32,
                    public_: vi.public as i32,
                    prev_challenges: vi.prev_challenges as i32,
                    srs: srs.into(),
                    evals: WasmPlonkVerificationEvals {
                        sigma_comm: IntoIterator::into_iter(vi.sigma_comm).map(From::from).collect(),
                        coefficients_comm: IntoIterator::into_iter(vi.coefficients_comm).map(From::from).collect(),
                        generic_comm: vi.generic_comm.into(),
                        psm_comm: vi.psm_comm.into(),
                        complete_add_comm: vi.complete_add_comm.into(),
                        mul_comm: vi.mul_comm.into(),
                        emul_comm: vi.emul_comm.into(),
                        endomul_scalar_comm: vi.endomul_scalar_comm.into(),
                    },
                    shifts:
                        WasmShifts {
                            s0: vi.shift[0].into(),
                            s1: vi.shift[1].into(),
                            s2: vi.shift[2].into(),
                            s3: vi.shift[3].into(),
                            s4: vi.shift[4].into(),
                            s5: vi.shift[5].into(),
                            s6: vi.shift[6].into(),
                        },
                    lookup_index: vi.lookup_index.map(Into::into),
                }
            }

            /* pub fn to_wasm_copy<'a>(
                srs: &Arc<SRS<GAffine>>,
                vi: &DlogVerifierIndex<GAffine>,
            ) -> WasmPlonkVerifierIndex {
                WasmPlonkVerifierIndex {
                    domain: WasmDomain {
                        log_size_of_group: vi.domain.log_size_of_group as i32,
                        group_gen: vi.domain.group_gen.clone().into(),
                    },
                    max_poly_size: vi.max_poly_size as i32,
                    srs: srs.clone().into(),
                    evals: WasmPlonkVerificationEvals {
                        sigma_comm: vi.sigma_comm.iter().map(From::from).collect(),
                        coefficients_comm: vi.coefficients_comm.iter().map(From::from).collect(),
                        generic_comm: vi.generic_comm.clone().into(),
                        psm_comm: vi.psm_comm.clone().into(),
                        complete_add_comm: vi.complete_add_comm.clone().into(),
                        mul_comm: vi.mul_comm.clone().into(),
                        emul_comm: vi.emul_comm.clone().into(),
                        endomul_scalar_comm: vi.endomul_scalar_comm.clone().into(),
                    },
                    shifts:
                        WasmShifts {
                            s0: vi.shift[0].clone().into(),
                            s1: vi.shift[1].clone().into(),
                            s2: vi.shift[2].clone().into(),
                            s3: vi.shift[3].clone().into(),
                            s4: vi.shift[4].clone().into(),
                            s5: vi.shift[5].clone().into(),
                            s6: vi.shift[6].clone().into(),
                        },
                    linearization: [<Wasm $field_name:camel Linearization>](Box::new(vi.linearization.clone())),
                }
            } */

            pub fn of_wasm(
                max_poly_size: i32,
                public_: i32,
                prev_challenges: i32,
                log_size_of_group: i32,
                srs: &$WasmSrs,
                evals: &WasmPlonkVerificationEvals,
                shifts: &WasmShifts,
            ) -> (DlogVerifierIndex<GAffine>, Arc<SRS<GAffine>>) {
                /*
                let urs_copy = Rc::clone(&*urs);
                let urs_copy_outer = Rc::clone(&*urs);
                let srs = {
                    // We know that the underlying value is still alive, because we never convert any of our
                    // Rc<_>s into weak pointers.
                    SRSValue::Ref(unsafe { &*Rc::into_raw(urs_copy) })
                }; */
                let (endo_q, _endo_r) = poly_commitment::srs::endos::<$GOther>();
                let domain = Domain::<$F>::new(1 << log_size_of_group).unwrap();

                let feature_flags =
                    FeatureFlags {
                        range_check0: false,
                        range_check1: false,
                        foreign_field_add: false,
                        foreign_field_mul: false,
                        rot: false,
                        xor: false,
                        lookup_features:
                        LookupFeatures {
                            patterns: LookupPatterns {
                                xor: false,
                                lookup: false,
                                range_check: false,
                                foreign_field_mul: false, },
                            joint_lookup_used:false,
                            uses_runtime_tables: false,
                        },
                    };

                let (linearization, powers_of_alpha) = expr_linearization(Some(&feature_flags), true);

                let index =
                    DlogVerifierIndex {
                        domain,

                        sigma_comm: array_init(|i| (&evals.sigma_comm[i]).into()),
                        generic_comm: (&evals.generic_comm).into(),
                        coefficients_comm: array_init(|i| (&evals.coefficients_comm[i]).into()),

                        psm_comm: (&evals.psm_comm).into(),

                        complete_add_comm: (&evals.complete_add_comm).into(),
                        mul_comm: (&evals.mul_comm).into(),
                        emul_comm: (&evals.emul_comm).into(),

                        endomul_scalar_comm: (&evals.endomul_scalar_comm).into(),
                        // TODO
                        range_check0_comm: None,
                        range_check1_comm: None,
                        foreign_field_add_comm: None,
                        foreign_field_mul_comm: None,
                        rot_comm: None,
                        xor_comm: None,

                        w: {
                            let res = once_cell::sync::OnceCell::new();
                            res.set(zk_w3(domain)).unwrap();
                            res
                        },
                        endo: endo_q,
                        max_poly_size: max_poly_size as usize,
                        public: public_ as usize,
                        prev_challenges: prev_challenges as usize,
                        zkpm: {
                            let res = once_cell::sync::OnceCell::new();
                            res.set(zk_polynomial(domain)).unwrap();
                            res
                        },
                        shift: [
                            shifts.s0.into(),
                            shifts.s1.into(),
                            shifts.s2.into(),
                            shifts.s3.into(),
                            shifts.s4.into(),
                            shifts.s5.into(),
                            shifts.s6.into()
                        ],
                        srs: {
                            let res = once_cell::sync::OnceCell::new();
                            res.set(srs.0.clone()).unwrap();
                            res
                        },
                        linearization,
                        powers_of_alpha,
                        // TODO
                        lookup_index: None,
                    };
                (index, srs.0.clone())
            }

            impl From<WasmPlonkVerifierIndex> for DlogVerifierIndex<$G> {
                fn from(index: WasmPlonkVerifierIndex) -> Self {
                    of_wasm(
                        index.max_poly_size,
                        index.public_,
                        index.prev_challenges,
                        index.domain.log_size_of_group,
                        &index.srs,
                        &index.evals,
                        &index.shifts,
                    )
                    .0
                }
            }

            pub fn read_raw(
                offset: Option<i32>,
                srs: &$WasmSrs,
                path: String,
            ) -> Result<DlogVerifierIndex<$G>, JsValue> {
                let path = Path::new(&path);
                let (endo_q, _endo_r) = poly_commitment::srs::endos::<GAffineOther>();
                DlogVerifierIndex::<$G>::from_file(
                    Some(srs.0.clone()),
                    path,
                    offset.map(|x| x as u64),
                    endo_q,
                ).map_err(|e| JsValue::from_str(format!("read_raw: {}", e).as_str()))
            }

            #[wasm_bindgen]
            pub fn [<$name:snake _read>](
                offset: Option<i32>,
                srs: &$WasmSrs,
                path: String,
            ) -> Result<WasmPlonkVerifierIndex, JsValue> {
                let vi = read_raw(offset, srs, path)?;
                Ok(to_wasm(srs, vi.into()))
            }

            #[wasm_bindgen]
            pub fn [<$name:snake _write>](
                append: Option<bool>,
                index: WasmPlonkVerifierIndex,
                path: String,
            ) -> Result<(), JsValue> {
                let index: DlogVerifierIndex<$G> = index.into();
                let path = Path::new(&path);
                index.to_file(path, append).map_err(|e| {
                    println!("{}", e);
                    JsValue::from_str("caml_pasta_fp_plonk_verifier_index_raw_read")
                })
            }

            // TODO understand what serialization format we need

            // #[wasm_bindgen]
            // pub fn [<$name:snake _serialize>](
            //     index: WasmPlonkVerifierIndex,
            // ) -> Box<[u8]> {
            //     let index: DlogVerifierIndex<$G> = index.into();
            //     rmp_serde::to_vec(&index).unwrap().into_boxed_slice()
            // }

            // #[wasm_bindgen]
            // pub fn [<$name:snake _deserialize>](
            //     srs: &$WasmSrs,
            //     index: Box<[u8]>,
            // ) -> WasmPlonkVerifierIndex {
            //     let mut vi: DlogVerifierIndex<$G> = rmp_serde::from_slice(&index).unwrap();
            //     vi.linearization = expr_linearization(vi.domain, false, false, None);
            //     return to_wasm(srs, vi.into())
            // }

            #[wasm_bindgen]
            pub fn [<$name:snake _serialize>](
                index: WasmPlonkVerifierIndex,
            ) -> String {
                let index: DlogVerifierIndex<$G> = index.into();
                serde_json::to_string(&index).unwrap()
            }

            #[wasm_bindgen]
            pub fn [<$name:snake _deserialize>](
                srs: &$WasmSrs,
                index: String,
            ) -> WasmPlonkVerifierIndex {
                let vi: DlogVerifierIndex<$G> = serde_json::from_str(&index).unwrap();
                return to_wasm(srs, vi.into())
            }

            #[wasm_bindgen]
            pub fn [<$name:snake _create>](
                index: &$WasmIndex,
            ) -> WasmPlonkVerifierIndex {
                {
                    let ptr: &mut poly_commitment::srs::SRS<GAffine> =
                        unsafe { &mut *(std::sync::Arc::as_ptr(&index.0.as_ref().srs) as *mut _) };
                    ptr.add_lagrange_basis(index.0.as_ref().cs.domain.d1);
                }
                let verifier_index = index.0.as_ref().verifier_index();
                to_wasm(&index.0.as_ref().srs, verifier_index)
            }

            #[wasm_bindgen]
            pub fn [<$name:snake _shifts>](log2_size: i32) -> WasmShifts {
                let domain = Domain::<$F>::new(1 << log2_size).unwrap();
                let shifts = Shifts::new(&domain);
                let s = shifts.shifts();
                WasmShifts {
                    s0: s[0].clone().into(),
                    s1: s[1].clone().into(),
                    s2: s[2].clone().into(),
                    s3: s[3].clone().into(),
                    s4: s[4].clone().into(),
                    s5: s[5].clone().into(),
                    s6: s[6].clone().into(),
                }
            }

            #[wasm_bindgen]
            pub fn [<$name:snake _dummy>]() -> WasmPlonkVerifierIndex {
                fn comm() -> $WasmPolyComm {
                    let g: $WasmG = $G::prime_subgroup_generator().into();
                    $WasmPolyComm {
                        shifted: None,
                        unshifted: vec![g].into(),
                    }
                }
                fn vec_comm(num: usize) -> WasmVector<$WasmPolyComm> {
                    (0..num).map(|_| comm()).collect()
                }

                WasmPlonkVerifierIndex {
                    domain: WasmDomain {
                        log_size_of_group: 1,
                        group_gen: $F::one().into(),
                    },
                    max_poly_size: 0,
                    public_: 0,
                    prev_challenges: 0,
                    srs: $WasmSrs(Arc::new(SRS::create(0))),
                    evals: WasmPlonkVerificationEvals {
                        sigma_comm: vec_comm(PERMUTS),
                        coefficients_comm: vec_comm(COLUMNS),
                        generic_comm: comm(),
                        psm_comm: comm(),
                        complete_add_comm: comm(),
                        mul_comm: comm(),
                        emul_comm: comm(),
                        endomul_scalar_comm: comm(),
                    },
                    shifts:
                        WasmShifts {
                            s0: $F::one().into(),
                            s1: $F::one().into(),
                            s2: $F::one().into(),
                            s3: $F::one().into(),
                            s4: $F::one().into(),
                            s5: $F::one().into(),
                            s6: $F::one().into(),
                        },
                    lookup_index: None,
                }
            }

            #[wasm_bindgen]
            pub fn [<$name:snake _deep_copy>](
                x: &WasmPlonkVerifierIndex,
            ) -> WasmPlonkVerifierIndex {
                x.clone()
            }

        }
    }
}

pub mod fp {
    use super::*;
    use crate::arkworks::{WasmGVesta, WasmPastaFp};
    use crate::pasta_fp_plonk_index::WasmPastaFpPlonkIndex;
    use crate::poly_comm::vesta::WasmFpPolyComm as WasmPolyComm;
    use crate::srs::fp::WasmFpSrs;
    use mina_curves::pasta::{Fp, Pallas as GAffineOther, Vesta as GAffine};

    impl_verification_key!(
        caml_pasta_fp_plonk_verifier_index,
        WasmGVesta,
        GAffine,
        WasmPastaFp,
        Fp,
        WasmPolyComm,
        WasmFpSrs,
        GAffineOther,
        mina_poseidon::pasta::fp_kimchi,
        mina_poseidon::pasta::fq_kimchi,
        WasmPastaFpPlonkIndex,
        Fp
    );
}

pub mod fq {
    use super::*;
    use crate::arkworks::{WasmGPallas, WasmPastaFq};
    use crate::pasta_fq_plonk_index::WasmPastaFqPlonkIndex;
    use crate::poly_comm::pallas::WasmFqPolyComm as WasmPolyComm;
    use crate::srs::fq::WasmFqSrs;
    use mina_curves::pasta::{Fq, Pallas as GAffine, Vesta as GAffineOther};

    impl_verification_key!(
        caml_pasta_fq_plonk_verifier_index,
        WasmGPallas,
        GAffine,
        WasmPastaFq,
        Fq,
        WasmPolyComm,
        WasmFqSrs,
        GAffineOther,
        mina_poseidon::pasta::fq_kimchi,
        mina_poseidon::pasta::fp_kimchi,
        WasmPastaFqPlonkIndex,
        Fq
    );
}
