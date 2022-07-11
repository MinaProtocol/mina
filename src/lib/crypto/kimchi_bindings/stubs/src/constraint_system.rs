use kimchi::snarky::constraint_system::SnarkyConstraintSystem;
use mina_curves::pasta::{Fq, Fp};

use crate::gate_vector::{fq::CamlPastaFqPlonkGateVector, fp::CamlPastaFpPlonkGateVector};

//
// CamlConstraintSystemFq
//

#[derive(ocaml_gen::CustomType)]
pub struct CamlConstraintSystemFq(SnarkyConstraintSystem<Fq, CamlPastaFqPlonkGateVector>);

impl CamlConstraintSystemFq {
    extern "C" fn caml_pointer_finalize(v: ocaml::Raw) {
        unsafe {
            let v: ocaml::Pointer<CamlConstraintSystemFq> = v.as_pointer();
            v.drop_in_place();
        }
    }
}

ocaml::custom!(CamlConstraintSystemFq {
    finalize: CamlConstraintSystemFq::caml_pointer_finalize,
});

//
// CamlConstraintSystemFp
//

#[derive(ocaml_gen::CustomType)]
pub struct CamlConstraintSystemFp(SnarkyConstraintSystem<Fp, CamlPastaFpPlonkGateVector>);

impl CamlConstraintSystemFp {
    extern "C" fn caml_pointer_finalize(v: ocaml::Raw) {
        unsafe {
            let v: ocaml::Pointer<CamlConstraintSystemFp> = v.as_pointer();
            v.drop_in_place();
        }
    }
}

ocaml::custom!(CamlConstraintSystemFp {
    finalize: CamlConstraintSystemFp::caml_pointer_finalize,
});