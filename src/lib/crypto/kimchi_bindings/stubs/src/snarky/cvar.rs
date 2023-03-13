use kimchi::snarky::prelude::*;
use mina_curves::pasta::{Fp, Fq};
use paste::paste;

use crate::arkworks::{CamlFp, CamlFq};

//
// Wrapper types
//

impl_custom_clone!(CamlFpVar, FieldVar<Fp>, Debug);

impl From<&CamlFpVar> for FieldVar<Fp> {
    fn from(var: &CamlFpVar) -> Self {
        var.0.clone()
    }
}

impl From<&FieldVar<Fp>> for CamlFpVar {
    fn from(var: &FieldVar<Fp>) -> Self {
        CamlFpVar(var.clone())
    }
}

impl From<FieldVar<Fp>> for CamlFpVar {
    fn from(var: FieldVar<Fp>) -> Self {
        CamlFpVar(var)
    }
}

impl_custom_clone!(CamlFqVar, FieldVar<Fq>, Debug);

impl From<&CamlFqVar> for FieldVar<Fq> {
    fn from(var: &CamlFqVar) -> Self {
        var.0.clone()
    }
}

impl From<&FieldVar<Fq>> for CamlFqVar {
    fn from(var: &FieldVar<Fq>) -> Self {
        CamlFqVar(var.clone())
    }
}

impl From<FieldVar<Fq>> for CamlFqVar {
    fn from(var: FieldVar<Fq>) -> Self {
        CamlFqVar(var)
    }
}

//
// Methods
//

macro_rules! impl_cvar_methods {
    ($name: ident, $CamlFVar: ty, $CamlF: ty) => {
        paste! { impl_functions! {
            pub fn [<$name:snake _var_of_index_unsafe>](idx: usize) -> $CamlFVar {
                $CamlFVar(FieldVar::Var(idx))
            }

            pub fn [<$name:snake _var_constant>](cst: $CamlF) -> $CamlFVar {
                $CamlFVar(FieldVar::Constant(cst.0))
            }

            pub fn [<$name:snake _var_add>](var1: $CamlFVar, var2: $CamlFVar) -> $CamlFVar {
                $CamlFVar(&var1.0 + &var2.0)
            }

            pub fn [<$name:snake _var_negate>](var: $CamlFVar) -> $CamlFVar {
                $CamlFVar(-&var.0)
            }

            pub fn [<$name:snake _var_scale>](var: $CamlFVar, cst: $CamlF) -> $CamlFVar {
                $CamlFVar(var.0.scale(cst.0))
            }

            pub fn [<$name:snake _var_sub>](var1: $CamlFVar, var2: $CamlFVar) -> $CamlFVar {
                $CamlFVar(&var1.0 - &var2.0)
            }

            pub fn [<$name:snake _var_to_constant>](var: $CamlFVar) -> Option<$CamlF> {
                match &var.0 {
                    FieldVar::Constant(c) => Some($CamlF(*c)),
                    _ => None,
                }
            }
        }}
    };
}

impl_cvar_methods!(fp, CamlFpVar, CamlFp);
impl_cvar_methods!(fq, CamlFqVar, CamlFq);
