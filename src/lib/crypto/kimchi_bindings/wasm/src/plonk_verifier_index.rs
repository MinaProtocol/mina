use kimchi_circuits::expr::{Linearization, PolishToken, Variable, Column};
use kimchi_circuits::gate::{GateType, CurrOrNext};
use paste::paste;
use crate::wasm_vector::WasmVector;
use wasm_bindgen::prelude::*;
use std::convert::TryInto;
use std::sync::Arc;
use commitment_dlog::srs::SRS;
use kimchi::index::{expr_linearization, VerifierIndex as DlogVerifierIndex};
use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use ark_ec::AffineCurve;
use ark_ff::One;
use array_init::array_init;
use kimchi_circuits::{
    nolookup::constraints::{zk_polynomial, zk_w3, Shifts},
    wires::{PERMUTS, COLUMNS},
};
use std::path::Path;

#[wasm_bindgen]
#[derive(Clone, Copy)]
pub enum WasmColumnTag {
    Witness,
    Z,
    LookupSorted,
    LookupAggreg,
    LookupTable,
    LookupKindIndex,
    Index,
    Coefficient,
}

#[wasm_bindgen]
#[derive(Clone, Copy)]
pub struct WasmColumn {
    tag: WasmColumnTag,
    gate_type: GateType,
    i: i32,
}

impl From<Column> for WasmColumn {
    fn from(c: Column) -> Self {
        let tag_i = |tag, i: usize|
            Self {
                tag,
                gate_type: GateType::Zero,
                i: i.try_into().expect("usize -> isize")
            };
        let tag = |tag| tag_i(tag, 0);

        match c {
            Column::Witness(x) => tag_i(WasmColumnTag::Witness, x),
            Column::Z => tag(WasmColumnTag::Z),
            Column::LookupSorted(x) => tag_i(WasmColumnTag::LookupSorted, x),
            Column::LookupAggreg => tag(WasmColumnTag::LookupAggreg),
            Column::LookupTable => tag(WasmColumnTag::LookupTable),
            Column::LookupKindIndex(x) => tag_i(WasmColumnTag::LookupKindIndex, x),
            Column::Index(x) =>
                Self {
                    tag: WasmColumnTag::Index,
                    gate_type: x,
                    i: 0
                },
            Column::Coefficient(x) => tag_i(WasmColumnTag::Coefficient, x),
        }
    }
}

impl From<&Column> for WasmColumn {
    fn from(c: &Column) -> Self {
        let tag_i = |tag, i: &usize|
            Self {
                tag,
                gate_type: GateType::Zero,
                i: (*i).try_into().expect("usize -> isize")
            };
        let tag = |tag| tag_i(tag, &0);

        match c {
            Column::Witness(x) => tag_i(WasmColumnTag::Witness, x),
            Column::Z => tag(WasmColumnTag::Z),
            Column::LookupSorted(x) => tag_i(WasmColumnTag::LookupSorted, x),
            Column::LookupAggreg => tag(WasmColumnTag::LookupAggreg),
            Column::LookupTable => tag(WasmColumnTag::LookupTable),
            Column::LookupKindIndex(x) => tag_i(WasmColumnTag::LookupKindIndex, x),
            Column::Index(x) =>
                Self {
                    tag: WasmColumnTag::Index,
                    gate_type: *x,
                    i: 0
                },
            Column::Coefficient(x) => tag_i(WasmColumnTag::Coefficient, x),
        }
    }
}

impl From<WasmColumn> for Column {
    fn from(c: WasmColumn) -> Column {
        match c.tag {
            WasmColumnTag::Witness =>
                Column::Witness(c.i.try_into().expect("usize -> isize")),
            WasmColumnTag::Z => Column::Z,
            WasmColumnTag::LookupSorted => {
                Column::LookupSorted(c.i.try_into().expect("usize -> isize"))
            }
            WasmColumnTag::LookupAggreg => Column::LookupAggreg,
            WasmColumnTag::LookupTable => Column::LookupTable,
            WasmColumnTag::LookupKindIndex => {
                Column::LookupKindIndex(c.i.try_into().expect("usize -> isize"))
            }
            WasmColumnTag::Index => Column::Index(c.gate_type),
            WasmColumnTag::Coefficient => {
                Column::Coefficient(c.i.try_into().expect("usize -> isize"))
            }
        }
    }
}

#[wasm_bindgen]
#[derive(Clone, Copy)]
pub struct WasmVariable {
    pub col: WasmColumn,
    pub row: CurrOrNext,
}

impl From<Variable> for WasmVariable {
    fn from(c: Variable) -> WasmVariable {
        WasmVariable {
            col: c.col.into(),
            row: c.row,
        }
    }
}

impl From<&Variable> for WasmVariable {
    fn from(c: &Variable) -> WasmVariable {
        WasmVariable {
            col: c.col.into(),
            row: c.row,
        }
    }
}

impl From<WasmVariable> for Variable {
    fn from(c: WasmVariable) -> Variable {
        Variable {
            col: c.col.into(),
            row: c.row,
        }
    }
}


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
            pub enum WasmPolishTokenTag {
                Alpha,
                Beta,
                Gamma,
                JointCombiner,
                EndoCoefficient,
                Mds,
                Literal,
                Cell,
                Dup,
                Pow,
                Add,
                Mul,
                Sub,
                VanishesOnLast4Rows,
                UnnormalizedLagrangeBasis,
                Store,
                Load,
            }

            /*
            #[wasm_bindgen]
            #[derive(Clone, Copy)]
            pub struct WasmPolishToken {
                tag: WasmPolishTokenTag,
                i0: i32,
                i1: i32,
                f: $WasmF,
                v: WasmVariable,
            }

            #[wasm_bindgen]
            #[derive(Clone)]
            pub struct WasmIndexTerm {
                column: WasmColumn,
                coefficient: WasmVector<WasmPolishToken>,
            }

            #[wasm_bindgen]
            #[derive(Clone)]
            pub struct [<Wasm $field_name:camel Linearization>] {
                pub constant_term: WasmVector<WasmPolishToken>,
                pub index_terms: WasmVector<WasmIndexTerm>,
            }
            */

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
                #[wasm_bindgen(skip)]
                pub chacha_comm: WasmVector<$WasmPolyComm>,
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
                        chacha_comm: (vec![]).into(),
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

                #[wasm_bindgen(getter)]
                pub fn chacha_comm(&self) -> WasmVector<$WasmPolyComm> {
                    self.chacha_comm.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_chacha_comm(&mut self, x: WasmVector<$WasmPolyComm>) {
                    self.chacha_comm = x;
                }
            }

            #[wasm_bindgen]
            #[derive(Clone, Copy)]
            pub struct [<Wasm $field_name:camel Shifts>] {
                s0: $WasmF,
                s1: $WasmF,
                s2: $WasmF,
                s3: $WasmF,
                s4: $WasmF,
                s5: $WasmF,
                s6: $WasmF,
            }
            type WasmShifts = [<Wasm $field_name:camel Shifts>];

            #[wasm_bindgen]
            #[derive(Clone)]
            pub struct [<Wasm $field_name:camel Linearization>](
                #[wasm_bindgen(skip)]
                pub Box<Linearization<Vec<PolishToken<$F>>>>);
            type WasmLinearization = [<Wasm $field_name:camel Linearization>];

            #[wasm_bindgen]
            #[derive(Clone)]
            pub struct [<Wasm $field_name:camel PlonkVerifierIndex>] {
                pub domain: WasmDomain,
                pub max_poly_size: i32,
                pub max_quot_size: i32,
                #[wasm_bindgen(skip)]
                pub srs: $WasmSrs,
                #[wasm_bindgen(skip)]
                pub evals: WasmPlonkVerificationEvals,
                #[wasm_bindgen(skip)]
                pub shifts: WasmShifts,
                #[wasm_bindgen(skip)]
                pub linearization: WasmLinearization,
            }
            type WasmPlonkVerifierIndex = [<Wasm $field_name:camel PlonkVerifierIndex>];

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel PlonkVerifierIndex>] {
                #[wasm_bindgen(constructor)]
                pub fn new(
                    domain: &WasmDomain,
                    max_poly_size: i32,
                    max_quot_size: i32,
                    srs: &$WasmSrs,
                    evals: &WasmPlonkVerificationEvals,
                    shifts: &WasmShifts,
                    linearization: &WasmLinearization, 
                ) -> Self {
                    WasmPlonkVerifierIndex {
                        domain: domain.clone(),
                        max_poly_size,
                        max_quot_size,
                        srs: srs.clone(),
                        evals: evals.clone(),
                        shifts: shifts.clone(),
                        linearization: linearization.clone(),
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
                    max_quot_size: vi.max_quot_size as i32,
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
                        chacha_comm: 
                            match vi.chacha_comm {
                                None => vec![].into(),
                                Some(cs) => vec![(&cs[0]).into(), (&cs[1]).into(), (&cs[2]).into(), (&cs[3]).into()].into()
                            }
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
                    linearization: [<Wasm $field_name:camel Linearization>](Box::new(vi.linearization)),
                }
            }

            pub fn to_wasm_copy<'a>(
                srs: &Arc<SRS<GAffine>>,
                vi: &DlogVerifierIndex<GAffine>,
            ) -> WasmPlonkVerifierIndex {
                WasmPlonkVerifierIndex {
                    domain: WasmDomain {
                        log_size_of_group: vi.domain.log_size_of_group as i32,
                        group_gen: vi.domain.group_gen.clone().into(),
                    },
                    max_poly_size: vi.max_poly_size as i32,
                    max_quot_size: vi.max_quot_size as i32,
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
                        chacha_comm: 
                            match &vi.chacha_comm {
                                None => vec![].into(),
                                Some(cs) => vec![cs[0].clone().into(), cs[1].clone().into(), cs[2].clone().into(), cs[3].clone().into()].into()
                            }
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
            }

            pub fn of_wasm(
                max_poly_size: i32,
                max_quot_size: i32,
                log_size_of_group: i32,
                srs: &$WasmSrs,
                evals: &WasmPlonkVerificationEvals,
                shifts: &WasmShifts,
                linearization: &WasmLinearization,
            ) -> (DlogVerifierIndex<GAffine>, Arc<SRS<GAffine>>) {
                /*
                let urs_copy = Rc::clone(&*urs);
                let urs_copy_outer = Rc::clone(&*urs);
                let srs = {
                    // We know that the underlying value is still alive, because we never convert any of our
                    // Rc<_>s into weak pointers.
                    SRSValue::Ref(unsafe { &*Rc::into_raw(urs_copy) })
                }; */
                let (endo_q, _endo_r) = commitment_dlog::srs::endos::<$GOther>();
                let domain = Domain::<$F>::new(1 << log_size_of_group).unwrap();

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
                        chacha_comm: None,
                        lookup_selectors: vec![],
                        lookup_tables: vec![],
                        w: zk_w3(domain),
                        fr_sponge_params: $FrSpongeParams::params(),
                        fq_sponge_params: $FqSpongeParams::params(),
                        endo: endo_q,
                        max_poly_size: max_poly_size as usize,
                        max_quot_size: max_quot_size as usize,
                        zkpm: zk_polynomial(domain),
                        shift: [
                            shifts.s0.into(),
                            shifts.s1.into(),
                            shifts.s2.into(),
                            shifts.s3.into(),
                            shifts.s4.into(),
                            shifts.s5.into(),
                            shifts.s6.into()
                        ],
                        linearization: linearization.0.as_ref().clone(),
                        // TODO
                        lookup_used: None,
                        srs: srs.0.clone(),
                    };
                (index, srs.0.clone())
            }

            impl From<WasmPlonkVerifierIndex> for DlogVerifierIndex<$G> {
                fn from(index: WasmPlonkVerifierIndex) -> Self {
                    of_wasm(
                        index.max_poly_size,
                        index.max_quot_size,
                        index.domain.log_size_of_group,
                        &index.srs,
                        &index.evals,
                        &index.shifts,
                        &index.linearization,
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
                let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffineOther>();
                let fq_sponge_params = $FqSpongeParams::params();
                let fr_sponge_params = $FrSpongeParams::params();
                DlogVerifierIndex::<$G>::from_file(
                    srs.0.clone(),
                    path,
                    offset.map(|x| x as u64),
                    endo_q,
                    fq_sponge_params,
                    fr_sponge_params,
                ).map_err(|e| JsValue::from_str(format!("read_raw: {}", e).as_str()))
            }

            #[wasm_bindgen]
            pub fn [<$name:snake _read>](
                offset: Option<i32>,
                srs: &$WasmSrs,
                path: String,
            ) -> Result<WasmPlonkVerifierIndex, JsValue> {
                let mut vi = read_raw(offset, srs, path)?;
                vi.linearization = expr_linearization(vi.domain, false, false, None);
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

            #[wasm_bindgen]
            pub fn [<$name:snake _create>](
                index: &$WasmIndex,
            ) -> WasmPlonkVerifierIndex {
                {
                    let ptr: &mut commitment_dlog::srs::SRS<GAffine> =
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
                    max_quot_size: 0,
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
                        chacha_comm: vec![].into(),
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
                    linearization: 
                        [<Wasm $field_name:camel Linearization>](Box::new(Linearization::<Vec<PolishToken<$F>>>::default())),
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
    use crate::arkworks::{WasmPastaFp, WasmGVesta};
    use mina_curves::pasta::{fp::Fp, vesta::Affine as GAffine, pallas::Affine as GAffineOther};
    use crate::poly_comm::vesta::WasmFpPolyComm as WasmPolyComm;
    use crate::srs::fp::WasmFpSrs;
    use crate::pasta_fp_plonk_index::WasmPastaFpPlonkIndex;

    impl_verification_key!(
        caml_pasta_fp_plonk_verifier_index,
        WasmGVesta,
        GAffine,
        WasmPastaFp,
        Fp,
        WasmPolyComm,
        WasmFpSrs,
        GAffineOther,
        oracle::pasta::fp_3,
        oracle::pasta::fq_3,
        WasmPastaFpPlonkIndex,
        Fp
        );
}

pub mod fq {
    use super::*;
    use crate::arkworks::{WasmPastaFq, WasmGPallas};
    use mina_curves::pasta::{fq::Fq, pallas::Affine as GAffine, vesta::Affine as GAffineOther};
    use crate::poly_comm::pallas::WasmFqPolyComm as WasmPolyComm;
    use crate::srs::fq::WasmFqSrs;
    use crate::pasta_fq_plonk_index::WasmPastaFqPlonkIndex;

    impl_verification_key!(
        caml_pasta_fq_plonk_verifier_index,
        WasmGPallas,
        GAffine,
        WasmPastaFq,
        Fq,
        WasmPolyComm,
        WasmFqSrs,
        GAffineOther,
        oracle::pasta::fq_3,
        oracle::pasta::fp_3,
        WasmPastaFqPlonkIndex,
        Fq
        );
}
