use kimchi::snarky::prelude::*;
use mina_curves::pasta::{Fp, Fq};
use paste::paste;

use crate::arkworks::{CamlFp, CamlFq};

//
// Wrapper types
//

impl_custom!(CamlFpVar, CVar<Fp>, Debug, Clone);
impl_custom!(CamlFqVar, CVar<Fq>, Debug, Clone);

//
// Methods
//

macro_rules! impl_cvar_methods {
    ($name: ident, $CamlFVar: ty, $CamlF: ty) => {
        paste! { impl_functions! {
            pub fn [<$name:snake _var_of_index_unsafe>](idx: usize) -> $CamlFVar {
                $CamlFVar(CVar::Var(idx))
            }

            pub fn [<$name:snake _var_constant>](cst: $CamlF) -> $CamlFVar {
                $CamlFVar(CVar::Constant(cst.0))
            }

            pub fn [<$name:snake _var_to_constant_and_terms>](var: &$CamlFVar) -> (Option<$CamlF>, Vec<($CamlF, usize)>) {
                let (cst, terms) = var.0.to_constant_and_terms();
                (cst.map(|c| $CamlF(c)), terms.into_iter().map(|(c, i)| ($CamlF(c), i)).collect())
            }

            pub fn [<$name:snake _var_add>](var1: &$CamlFVar, var2: &$CamlFVar) -> $CamlFVar {
                $CamlFVar(&var1.0 + &var2.0)
            }

            pub fn [<$name:snake _var_negate>](var: &$CamlFVar) -> $CamlFVar {
                $CamlFVar(-&var.0)
            }

            pub fn [<$name:snake _var_scale>](var: &$CamlFVar, cst: $CamlF) -> $CamlFVar {
                $CamlFVar(var.0.scale(cst.0))
            }

            pub fn [<$name:snake _var_sub>](var1: &$CamlFVar, var2: &$CamlFVar) -> $CamlFVar {
                $CamlFVar(&var1.0 - &var2.0)
            }

            pub fn [<$name:snake _var_linear_combination>](
                terms: Vec<($CamlF, &$CamlFVar)>,
            ) -> $CamlFVar {
                let terms: Vec<_> = terms.into_iter().map(|(a, b)| (a.0, b.0.clone())).collect();
                let res = CVar::linear_combination(            &terms);
                $CamlFVar(res)
            }

            pub fn [<$name:snake _var_sum>](cvars: Vec<&$CamlFVar>) -> $CamlFVar {
                let cvars: Vec<_> = cvars.into_iter().map(|t| &t.0).collect();
                let res = CVar::sum(&cvars);
                $CamlFVar(res)
            }

            pub fn [<$name:snake _var_to_constant>](var: &$CamlFVar) -> Option<$CamlF> {
                match &var.0 {
                    CVar::Constant(c) => Some($CamlF(*c)),
                    _ => None,
                }
            }
        }}
    };
}

impl_cvar_methods!(fp, CamlFpVar, CamlFp);
impl_cvar_methods!(fq, CamlFqVar, CamlFq);
