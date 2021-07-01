use crate::arkworks::{CamlFp, CamlFq, CamlScalarChallengeFp, CamlScalarChallengeFq};
use mina_curves::pasta::{Fp, Fq};
use plonk_circuits::scalars::RandomOracles;

//
// Fq
//

#[derive(Clone, ocaml::ToValue, ocaml::FromValue)]
pub struct CamlRandomOraclesFq {
    pub beta: CamlFq,
    pub gamma: CamlFq,
    pub alpha_chal: CamlScalarChallengeFq,
    pub alpha: CamlFq,
    pub zeta: CamlFq,
    pub v: CamlFq,
    pub u: CamlFq,
    pub zeta_chal: CamlScalarChallengeFq,
    pub v_chal: CamlScalarChallengeFq,
    pub u_chal: CamlScalarChallengeFq,
}

// Handy implementations

impl From<RandomOracles<Fq>> for CamlRandomOraclesFq {
    fn from(x: RandomOracles<Fq>) -> Self {
        CamlRandomOraclesFq {
            beta: x.beta.into(),
            gamma: x.gamma.into(),
            alpha_chal: x.alpha_chal.into(),
            alpha: x.alpha.into(),
            zeta: x.zeta.into(),
            v: x.v.into(),
            u: x.u.into(),
            zeta_chal: x.zeta_chal.into(),
            v_chal: x.v_chal.into(),
            u_chal: x.u_chal.into(),
        }
    }
}

impl From<&RandomOracles<Fq>> for CamlRandomOraclesFq {
    fn from(x: &RandomOracles<Fq>) -> Self {
        CamlRandomOraclesFq {
            beta: x.beta.into(),
            gamma: x.gamma.into(),
            alpha_chal: x.alpha_chal.into(),
            alpha: x.alpha.into(),
            zeta: x.zeta.into(),
            v: x.v.into(),
            u: x.u.into(),
            zeta_chal: x.zeta_chal.into(),
            v_chal: x.v_chal.into(),
            u_chal: x.u_chal.into(),
        }
    }
}

impl Into<RandomOracles<Fq>> for CamlRandomOraclesFq {
    fn into(self) -> RandomOracles<Fq> {
        RandomOracles {
            beta: self.beta.into(),
            gamma: self.gamma.into(),
            alpha_chal: self.alpha_chal.into(),
            alpha: self.alpha.into(),
            zeta: self.zeta.into(),
            v: self.v.into(),
            u: self.u.into(),
            zeta_chal: self.zeta_chal.into(),
            v_chal: self.v_chal.into(),
            u_chal: self.u_chal.into(),
        }
    }
}

impl Into<RandomOracles<Fq>> for &CamlRandomOraclesFq {
    fn into(self) -> RandomOracles<Fq> {
        RandomOracles {
            beta: self.beta.into(),
            gamma: self.gamma.into(),
            alpha_chal: self.alpha_chal.into(),
            alpha: self.alpha.into(),
            zeta: self.zeta.into(),
            v: self.v.into(),
            u: self.u.into(),
            zeta_chal: self.zeta_chal.into(),
            v_chal: self.v_chal.into(),
            u_chal: self.u_chal.into(),
        }
    }
}

//
// Fp
//

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlRandomOraclesFp {
    pub beta: CamlFp,
    pub gamma: CamlFp,
    pub alpha_chal: CamlScalarChallengeFp,
    pub alpha: CamlFp,
    pub zeta: CamlFp,
    pub v: CamlFp,
    pub u: CamlFp,
    pub zeta_chal: CamlScalarChallengeFp,
    pub v_chal: CamlScalarChallengeFp,
    pub u_chal: CamlScalarChallengeFp,
}

// Handy implementations

impl From<RandomOracles<Fp>> for CamlRandomOraclesFp {
    fn from(x: RandomOracles<Fp>) -> Self {
        CamlRandomOraclesFp {
            beta: x.beta.into(),
            gamma: x.gamma.into(),
            alpha_chal: x.alpha_chal.into(),
            alpha: x.alpha.into(),
            zeta: x.zeta.into(),
            v: x.v.into(),
            u: x.u.into(),
            zeta_chal: x.zeta_chal.into(),
            v_chal: x.v_chal.into(),
            u_chal: x.u_chal.into(),
        }
    }
}

impl From<&RandomOracles<Fp>> for CamlRandomOraclesFp {
    fn from(x: &RandomOracles<Fp>) -> Self {
        CamlRandomOraclesFp {
            beta: x.beta.into(),
            gamma: x.gamma.into(),
            alpha_chal: x.alpha_chal.into(),
            alpha: x.alpha.into(),
            zeta: x.zeta.into(),
            v: x.v.into(),
            u: x.u.into(),
            zeta_chal: x.zeta_chal.into(),
            v_chal: x.v_chal.into(),
            u_chal: x.u_chal.into(),
        }
    }
}

impl Into<RandomOracles<Fp>> for CamlRandomOraclesFp {
    fn into(self) -> RandomOracles<Fp> {
        RandomOracles {
            beta: self.beta.into(),
            gamma: self.gamma.into(),
            alpha_chal: self.alpha_chal.into(),
            alpha: self.alpha.into(),
            zeta: self.zeta.into(),
            v: self.v.into(),
            u: self.u.into(),
            zeta_chal: self.zeta_chal.into(),
            v_chal: self.v_chal.into(),
            u_chal: self.u_chal.into(),
        }
    }
}

impl Into<RandomOracles<Fp>> for &CamlRandomOraclesFp {
    fn into(self) -> RandomOracles<Fp> {
        RandomOracles {
            beta: self.beta.into(),
            gamma: self.gamma.into(),
            alpha_chal: self.alpha_chal.into(),
            alpha: self.alpha.into(),
            zeta: self.zeta.into(),
            v: self.v.into(),
            u: self.u.into(),
            zeta_chal: self.zeta_chal.into(),
            v_chal: self.v_chal.into(),
            u_chal: self.u_chal.into(),
        }
    }
}
