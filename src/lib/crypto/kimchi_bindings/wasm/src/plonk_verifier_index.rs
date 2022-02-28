use crate::wasm_vector::WasmVector;
use ark_ec::AffineCurve;
use ark_ff::One;
use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use array_init::array_init;
use commitment_dlog::srs::SRS;
use kimchi::circuits::expr::{Column, PolishToken, Variable};
use kimchi::circuits::gate::{CurrOrNext, GateType};
use kimchi::circuits::{
    constraints::{zk_polynomial, zk_w3, Shifts},
    wires::{COLUMNS, PERMUTS},
};
use kimchi::index::{expr_linearization, VerifierIndex as DlogVerifierIndex};
use paste::paste;
use std::convert::TryInto;
use std::path::Path;
use std::sync::Arc;
use wasm_bindgen::prelude::*;

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
    pub tag: WasmColumnTag,
    pub gate_type: GateType,
    pub i: i32,
}

impl WasmColumn {
    fn zero() -> Self {
        Self {
            tag: WasmColumnTag::Witness,
            gate_type: GateType::Zero,
            i: 0,
        }
    }
}

impl From<Column> for WasmColumn {
    fn from(c: Column) -> Self {
        let tag_i = |tag, i: usize| Self {
            tag,
            gate_type: GateType::Zero,
            i: i.try_into().expect("usize -> isize"),
        };
        let tag = |tag| tag_i(tag, 0);

        match c {
            Column::Witness(x) => tag_i(WasmColumnTag::Witness, x),
            Column::Z => tag(WasmColumnTag::Z),
            Column::LookupSorted(x) => tag_i(WasmColumnTag::LookupSorted, x),
            Column::LookupAggreg => tag(WasmColumnTag::LookupAggreg),
            Column::LookupTable => tag(WasmColumnTag::LookupTable),
            Column::LookupKindIndex(x) => tag_i(WasmColumnTag::LookupKindIndex, x),
            Column::Index(x) => Self {
                tag: WasmColumnTag::Index,
                gate_type: x,
                i: 0,
            },
            Column::Coefficient(x) => tag_i(WasmColumnTag::Coefficient, x),
        }
    }
}

impl From<&Column> for WasmColumn {
    fn from(c: &Column) -> Self {
        let tag_i = |tag, i: &usize| Self {
            tag,
            gate_type: GateType::Zero,
            i: (*i).try_into().expect("usize -> isize"),
        };
        let tag = |tag| tag_i(tag, &0);

        match c {
            Column::Witness(x) => tag_i(WasmColumnTag::Witness, x),
            Column::Z => tag(WasmColumnTag::Z),
            Column::LookupSorted(x) => tag_i(WasmColumnTag::LookupSorted, x),
            Column::LookupAggreg => tag(WasmColumnTag::LookupAggreg),
            Column::LookupTable => tag(WasmColumnTag::LookupTable),
            Column::LookupKindIndex(x) => tag_i(WasmColumnTag::LookupKindIndex, x),
            Column::Index(x) => Self {
                tag: WasmColumnTag::Index,
                gate_type: *x,
                i: 0,
            },
            Column::Coefficient(x) => tag_i(WasmColumnTag::Coefficient, x),
        }
    }
}

impl From<WasmColumn> for Column {
    fn from(c: WasmColumn) -> Column {
        match c.tag {
            WasmColumnTag::Witness => Column::Witness(c.i.try_into().expect("usize -> isize")),
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

impl WasmVariable {
    fn zero() -> Self {
        Self {
            col: WasmColumn::zero(),
            row: CurrOrNext::Curr,
        }
    }
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

            /* #[wasm_bindgen]
            #[derive(Clone)]
            pub struct [<Wasm $field_name:camel Linearization>](
                #[wasm_bindgen(skip)]
                pub Box<Linearization<Vec<PolishToken<$F>>>>);
            type WasmLinearization = [<Wasm $field_name:camel Linearization>]; */



            #[derive(Clone, Copy)]
            #[wasm_bindgen]
            pub struct [<Wasm $field_name:camel PolishToken>] {
                pub tag: WasmPolishTokenTag,
                pub i0: i32,
                pub i1: i32,
                pub f: $WasmF,
                pub v: WasmVariable,
            }
            type WasmPolishToken = [<Wasm $field_name:camel PolishToken>];

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel PolishToken>] {
                #[wasm_bindgen(constructor)]
                pub fn new(tag: WasmPolishTokenTag, i0: i32, i1: i32, f: $WasmF, v: WasmVariable) -> Self {
                    Self {tag, i0, i1, f, v}
                }
            }

            fn token(tag: WasmPolishTokenTag) -> WasmPolishToken {
                WasmPolishToken { tag, i0: 0, i1: 0, f: ($F::from(0 as i64)).into(), v: WasmVariable::zero() }
            }
            fn token_with_i32(tag: WasmPolishTokenTag, i0: usize) -> WasmPolishToken {
                WasmPolishToken { tag, i0: (i0 as i32), i1: 0, f: ($F::from(0 as i64)).into(), v: WasmVariable::zero() }
            }
            fn token_with_2xi32(tag: WasmPolishTokenTag, i0: usize, i1: usize) -> WasmPolishToken {
                WasmPolishToken { tag, i0: (i0 as i32), i1: (i1 as i32), f: ($F::from(0 as i64)).into(), v: WasmVariable::zero() }
            }
            fn token_with_variable(tag: WasmPolishTokenTag, variable: Variable) -> WasmPolishToken {
                WasmPolishToken { tag, i0: 0, i1: 0, f: ($F::from(0 as i64)).into(), v: variable.into() }
            }
            fn token_with_field(tag: WasmPolishTokenTag, field: $F) -> WasmPolishToken {
                WasmPolishToken { tag, i0: 0, i1: 0, f: field.into(), v: WasmVariable::zero() }
            }

            impl From<PolishToken<$F>> for WasmPolishToken {
                fn from(x: PolishToken<$F>) -> WasmPolishToken {
                    match x {
                        PolishToken::Alpha => token(WasmPolishTokenTag::Alpha),
                        PolishToken::Beta => token(WasmPolishTokenTag::Beta),
                        PolishToken::Gamma => token(WasmPolishTokenTag::Gamma),
                        PolishToken::JointCombiner => token(WasmPolishTokenTag::JointCombiner),
                        PolishToken::EndoCoefficient => token(WasmPolishTokenTag::EndoCoefficient),
                        PolishToken::Mds {row, col} => token_with_2xi32(WasmPolishTokenTag::Mds, row, col),
                        PolishToken::Literal(f) => token_with_field(WasmPolishTokenTag::Literal, f),
                        PolishToken::Cell(variable) => token_with_variable(WasmPolishTokenTag::Cell, variable),
                        PolishToken::Dup => token(WasmPolishTokenTag::Dup),
                        PolishToken::Pow(size) => token_with_i32(WasmPolishTokenTag::Pow, size),
                        PolishToken::Add => token(WasmPolishTokenTag::Add),
                        PolishToken::Mul => token(WasmPolishTokenTag::Mul),
                        PolishToken::Sub => token(WasmPolishTokenTag::Sub),
                        PolishToken::VanishesOnLast4Rows => token(WasmPolishTokenTag::VanishesOnLast4Rows),
                        PolishToken::UnnormalizedLagrangeBasis(size) => token_with_i32(WasmPolishTokenTag::UnnormalizedLagrangeBasis, size),
                        PolishToken::Store => token(WasmPolishTokenTag::Store),
                        PolishToken::Load(size) => token_with_i32(WasmPolishTokenTag::Load, size),
                    }
                }
            }
            impl From<WasmPolishToken> for PolishToken<$F> {
                fn from(x: WasmPolishToken) -> PolishToken<$F> {
                    match x.tag {
                        WasmPolishTokenTag::Alpha => PolishToken::Alpha,
                        WasmPolishTokenTag::Beta => PolishToken::Beta,
                        WasmPolishTokenTag::Gamma => PolishToken::Gamma,
                        WasmPolishTokenTag::JointCombiner => PolishToken::JointCombiner,
                        WasmPolishTokenTag::EndoCoefficient => PolishToken::EndoCoefficient,
                        WasmPolishTokenTag::Mds => PolishToken::Mds {row: x.i0 as usize, col: x.i1 as usize},
                        WasmPolishTokenTag::Literal => PolishToken::Literal(x.f.into()),
                        WasmPolishTokenTag::Cell => PolishToken::Cell(x.v.into()),
                        WasmPolishTokenTag::Dup => PolishToken::Dup,
                        WasmPolishTokenTag::Pow => PolishToken::Pow(x.i0 as usize),
                        WasmPolishTokenTag::Add => PolishToken::Add,
                        WasmPolishTokenTag::Mul => PolishToken::Mul,
                        WasmPolishTokenTag::Sub => PolishToken::Sub,
                        WasmPolishTokenTag::VanishesOnLast4Rows => PolishToken::VanishesOnLast4Rows,
                        WasmPolishTokenTag::UnnormalizedLagrangeBasis => PolishToken::UnnormalizedLagrangeBasis(x.i0 as usize),
                        WasmPolishTokenTag::Store => PolishToken::Store,
                        WasmPolishTokenTag::Load => PolishToken::Load(x.i0 as usize)
                    }
                }
            }

            #[wasm_bindgen]
            #[derive(Clone)]
            pub struct [<Wasm $field_name:camel IndexTerm>] {
                pub column: WasmColumn,
                #[wasm_bindgen(skip)]
                pub coefficient: WasmVector<WasmPolishToken>,
            }
            type WasmIndexTerm = [<Wasm $field_name:camel IndexTerm>];

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel IndexTerm>] {
                #[wasm_bindgen(getter)]
                pub fn coefficient(&self) -> WasmVector<WasmPolishToken> {
                    self.coefficient.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_coefficient(&mut self, x: WasmVector<WasmPolishToken>) {
                    self.coefficient = x;
                }
            }

            impl From<(Column, Vec<PolishToken<$F>>)> for WasmIndexTerm {
                fn from(x: (Column, Vec<PolishToken<$F>>)) -> WasmIndexTerm {
                    WasmIndexTerm {
                        column: x.0.into(),
                        coefficient: IntoIterator::into_iter(x.1).map(From::from).collect()
                    }
                }
            }
            impl From<WasmIndexTerm> for (Column, Vec<PolishToken<$F>>) {
                fn from(x: WasmIndexTerm) -> (Column, Vec<PolishToken<$F>>) {
                    (x.column.into(), x.coefficient.into_iter().map(From::from).collect())
                }
            }

            #[wasm_bindgen]
            #[derive(Clone)]
            pub struct [<Wasm $field_name:camel Linearization>] {
                #[wasm_bindgen(skip)]
                pub constant_term: WasmVector<WasmPolishToken>,
                #[wasm_bindgen(skip)]
                pub index_terms: WasmVector<WasmIndexTerm>,
            }
            type WasmLinearization = [<Wasm $field_name:camel Linearization>];

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel Linearization>] {
                #[wasm_bindgen(constructor)]
                pub fn new(
                    constant_term: WasmVector<WasmPolishToken>,
                    index_terms: WasmVector<WasmIndexTerm>,
                ) -> Self {
                    WasmLinearization {
                        constant_term: constant_term.clone(),
                        index_terms: index_terms.clone(),
                    }
                }

                #[wasm_bindgen(getter)]
                pub fn constant_term(&self) -> WasmVector<WasmPolishToken> {
                    self.constant_term.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_constant_term(&mut self, x: WasmVector<WasmPolishToken>) {
                    self.constant_term = x;
                }

                #[wasm_bindgen(getter)]
                pub fn index_terms(&self) -> WasmVector<WasmIndexTerm> {
                    self.index_terms.clone()
                }

                #[wasm_bindgen(setter)]
                pub fn set_index_terms(&mut self, x: WasmVector<WasmIndexTerm>) {
                    self.index_terms = x;
                }

                pub fn dummy() -> Self {
                    Self { constant_term: vec![].into(), index_terms: vec![].into() }
                }
            }

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
                pub shifts: WasmShifts,
                // TODO: add lookup index field
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
                ) -> Self {
                    WasmPlonkVerifierIndex {
                        domain: domain.clone(),
                        max_poly_size,
                        max_quot_size,
                        srs: srs.clone(),
                        evals: evals.clone(),
                        shifts: shifts.clone(),
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
            } */

            pub fn of_wasm(
                max_poly_size: i32,
                max_quot_size: i32,
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
                let (endo_q, _endo_r) = commitment_dlog::srs::endos::<$GOther>();
                let domain = Domain::<$F>::new(1 << log_size_of_group).unwrap();

                let (linearization, powers_of_alpha) = expr_linearization(domain, false, &None);

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
                        srs: srs.0.clone(),
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
                        index.max_quot_size,
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
    use mina_curves::pasta::{fp::Fp, pallas::Affine as GAffineOther, vesta::Affine as GAffine};

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
    use crate::arkworks::{WasmGPallas, WasmPastaFq};
    use crate::pasta_fq_plonk_index::WasmPastaFqPlonkIndex;
    use crate::poly_comm::pallas::WasmFqPolyComm as WasmPolyComm;
    use crate::srs::fq::WasmFqSrs;
    use mina_curves::pasta::{fq::Fq, pallas::Affine as GAffine, vesta::Affine as GAffineOther};

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
