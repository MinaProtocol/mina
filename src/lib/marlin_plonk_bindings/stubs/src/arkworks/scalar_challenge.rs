use crate::arkworks::{CamlFp, CamlFq};
use mina_curves::pasta::{Fp, Fq};
use oracle::sponge::ScalarChallenge;

//
// Fp
//

#[derive(Clone, Copy, ocaml::ToValue, ocaml::FromValue)]
pub struct CamlScalarChallengeFp(CamlFp);

impl From<ScalarChallenge<Fp>> for CamlScalarChallengeFp {
    fn from(x: ScalarChallenge<Fp>) -> Self {
        CamlScalarChallengeFp(x.0.into())
    }
}

impl From<&ScalarChallenge<Fp>> for CamlScalarChallengeFp {
    fn from(x: &ScalarChallenge<Fp>) -> Self {
        CamlScalarChallengeFp(x.0.into())
    }
}

impl Into<ScalarChallenge<Fp>> for CamlScalarChallengeFp {
    fn into(self) -> ScalarChallenge<Fp> {
        ScalarChallenge(self.0.into())
    }
}

impl Into<ScalarChallenge<Fp>> for &CamlScalarChallengeFp {
    fn into(self) -> ScalarChallenge<Fp> {
        ScalarChallenge(self.0.into())
    }
}

//
// Fq
//

#[derive(Clone, Copy, ocaml::ToValue, ocaml::FromValue)]
pub struct CamlScalarChallengeFq(CamlFq);

impl From<ScalarChallenge<Fq>> for CamlScalarChallengeFq {
    fn from(x: ScalarChallenge<Fq>) -> Self {
        CamlScalarChallengeFq(x.0.into())
    }
}

impl From<&ScalarChallenge<Fq>> for CamlScalarChallengeFq {
    fn from(x: &ScalarChallenge<Fq>) -> Self {
        CamlScalarChallengeFq(x.0.into())
    }
}

impl Into<ScalarChallenge<Fq>> for CamlScalarChallengeFq {
    fn into(self) -> ScalarChallenge<Fq> {
        ScalarChallenge(self.0.into())
    }
}

impl Into<ScalarChallenge<Fq>> for &CamlScalarChallengeFq {
    fn into(self) -> ScalarChallenge<Fq> {
        ScalarChallenge(self.0.into())
    }
}
