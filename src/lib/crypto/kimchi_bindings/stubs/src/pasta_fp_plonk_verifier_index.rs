use crate::arkworks::{CamlFp, CamlGVesta};
use crate::pasta_fp_plonk_index::CamlPastaFpPlonkIndexPtr;
use crate::plonk_verifier_index::{
    CamlPlonkDomain, CamlPlonkVerificationEvals, CamlPlonkVerifierIndex,
};
use crate::srs::fp::CamlFpSrs;
use ark_ec::AffineCurve;
use ark_ff::One;
use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use kimchi::{
    circuits::{
        constraints::FeatureFlags,
        lookup::lookups::{LookupFeatures, LookupPatterns},
        polynomials::permutation::Shifts,
        polynomials::permutation::{zk_polynomial, zk_w3},
        wires::{COLUMNS, PERMUTS},
    },
    linearization::expr_linearization,
    verifier_index::{LookupVerifierIndex, VerifierIndex},
};

use mina_curves::pasta::{Fp, Pallas, Vesta};
use poly_commitment::commitment::caml::CamlPolyComm;
use poly_commitment::{commitment::PolyComm, srs::SRS};
use std::convert::TryInto;
use std::path::Path;

pub type CamlPastaFpPlonkVerifierIndex =
    CamlPlonkVerifierIndex<CamlFp, CamlFpSrs, CamlPolyComm<CamlGVesta>>;

impl From<VerifierIndex<Vesta>> for CamlPastaFpPlonkVerifierIndex {
    fn from(vi: VerifierIndex<Vesta>) -> Self {
        let runtime_tables_comm = vi.lookup_index.as_ref().map_or(None, |v| {
            v.runtime_tables_selector.as_ref().map(|v| v.into())
        });

        let lookup_gate_comm = vi
            .lookup_index
            .as_ref()
            .map(|v| v.lookup_selectors.as_ref().map(Into::into))
            .map_or(None, |v| v.lookup);

        Self {
            domain: CamlPlonkDomain {
                log_size_of_group: vi.domain.log_size_of_group as isize,
                group_gen: CamlFp(vi.domain.group_gen),
            },
            max_poly_size: vi.max_poly_size as isize,
            public: vi.public as isize,
            prev_challenges: vi.prev_challenges as isize,
            srs: CamlFpSrs(vi.srs.get().expect("have an srs").clone()),
            evals: CamlPlonkVerificationEvals {
                sigma_comm: vi.sigma_comm.to_vec().iter().map(Into::into).collect(),
                coefficients_comm: vi
                    .coefficients_comm
                    .to_vec()
                    .iter()
                    .map(Into::into)
                    .collect(),
                generic_comm: vi.generic_comm.into(),
                psm_comm: vi.psm_comm.into(),
                complete_add_comm: vi.complete_add_comm.into(),
                mul_comm: vi.mul_comm.into(),
                emul_comm: vi.emul_comm.into(),
                endomul_scalar_comm: vi.endomul_scalar_comm.into(),
                xor_comm: vi.xor_comm.map(|v| v.into()),
                range_check0_comm: vi.range_check0_comm.map(|v| v.into()),
                range_check1_comm: vi.range_check1_comm.map(|v| v.into()),
                foreign_field_add_comm: vi.foreign_field_add_comm.map(|v| v.into()),
                foreign_field_mul_comm: vi.foreign_field_mul_comm.map(|v| v.into()),
                rot_comm: vi.rot_comm.map(|v| v.into()),
                lookup_gate_comm: lookup_gate_comm,
                runtime_tables_comm,
            },
            shifts: vi.shift.to_vec().iter().map(Into::into).collect(),
            lookup_index: vi.lookup_index.map(Into::into),
        }
    }
}

// TODO: This should really be a TryFrom or TryInto
impl From<CamlPastaFpPlonkVerifierIndex> for VerifierIndex<Vesta> {
    fn from(index: CamlPastaFpPlonkVerifierIndex) -> Self {
        let evals = index.evals;
        let shifts = index.shifts;

        let (endo_q, _endo_r) = poly_commitment::srs::endos::<Pallas>();
        let domain = Domain::<Fp>::new(1 << index.domain.log_size_of_group).expect("wrong size");

        let coefficients_comm: Vec<PolyComm<Vesta>> =
            evals.coefficients_comm.iter().map(Into::into).collect();
        let coefficients_comm: [_; COLUMNS] = coefficients_comm.try_into().expect("wrong size");
        let sigma_comm: Vec<PolyComm<Vesta>> = evals.sigma_comm.iter().map(Into::into).collect();
        let sigma_comm: [_; PERMUTS] = sigma_comm
            .try_into()
            .expect("vector of sigma comm is of wrong size");

        let shifts: Vec<Fp> = shifts.iter().map(Into::into).collect();
        let shift: [Fp; PERMUTS] = shifts.try_into().expect("wrong size");

        let lookup_index: std::option::Option<LookupVerifierIndex<Vesta>> =
            index.lookup_index.map(Into::into);

        // FIXME: Is the flag computation correct ?
        // Should both xor fields be synced ?
        let feature_flags = FeatureFlags {
            range_check0: false,
            range_check1: false,
            foreign_field_add: false,
            foreign_field_mul: false,
            rot: false,
            xor: false,
            lookup_features: match &lookup_index {
                None => LookupFeatures {
                    patterns: LookupPatterns {
                        xor: false,
                        lookup: false,
                        range_check: false,
                        foreign_field_mul: false,
                    },
                    joint_lookup_used: false,
                    uses_runtime_tables: false,
                },
                Some(idx) => idx.lookup_info.features,
            },
        };

        // TODO dummy_lookup_value ?
        let (linearization, powers_of_alpha) = expr_linearization(Some(&feature_flags), true);

        let srs = {
            let res = once_cell::sync::OnceCell::new();
            res.set(index.srs.0).unwrap();
            res
        };

        let psm_comm = evals.psm_comm.into();
        let complete_add_comm = evals.complete_add_comm.into();
        let mul_comm = evals.mul_comm.into();
        let emul_comm = evals.emul_comm.into();
        let endomul_scalar_comm = evals.endomul_scalar_comm.into();
        let generic_comm = evals.generic_comm.into();

        let xor_comm = evals.xor_comm.map(Into::into);
        let range_check0_comm = evals.range_check0_comm.map(Into::into);
        let range_check1_comm = evals.range_check1_comm.map(Into::into);
        let foreign_field_add_comm = evals.foreign_field_add_comm.map(Into::into);
        let foreign_field_mul_comm = evals.foreign_field_mul_comm.map(Into::into);
        let rot_comm = evals.rot_comm.map(Into::into);

        let w = {
            let res = once_cell::sync::OnceCell::new();
            let zkw3 = zk_w3(domain);
            res.set(zkw3).unwrap();
            res
        };

        let zkpm = {
            let res = once_cell::sync::OnceCell::new();
            res.set(zk_polynomial(domain)).unwrap();
            res
        };

        VerifierIndex::<Vesta> {
            domain,
            max_poly_size: index.max_poly_size as usize,
            public: index.public as usize,
            prev_challenges: index.prev_challenges as usize,
            powers_of_alpha,
            srs,

            sigma_comm,
            coefficients_comm,
            generic_comm,
            psm_comm,

            complete_add_comm,
            mul_comm,
            emul_comm,
            endomul_scalar_comm,

            xor_comm,
            range_check0_comm,
            range_check1_comm,
            foreign_field_add_comm,
            foreign_field_mul_comm,
            rot_comm,

            shift,
            zkpm,
            w,
            endo: endo_q,

            lookup_index,
            linearization,
        }
    }
}

pub fn read_raw(
    offset: Option<ocaml::Int>,
    srs: CamlFpSrs,
    path: String,
) -> Result<VerifierIndex<Vesta>, ocaml::Error> {
    let path = Path::new(&path);
    let (endo_q, _endo_r) = poly_commitment::srs::endos::<Pallas>();
    VerifierIndex::<Vesta>::from_file(Some(srs.0), path, offset.map(|x| x as u64), endo_q).map_err(
        |_e| {
            ocaml::Error::invalid_argument("caml_pasta_fp_plonk_verifier_index_raw_read")
                .err()
                .unwrap()
        },
    )
}

//
// OCaml methods
//
#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_read(
    offset: Option<ocaml::Int>,
    srs: CamlFpSrs,
    path: String,
) -> Result<CamlPastaFpPlonkVerifierIndex, ocaml::Error> {
    let vi = read_raw(offset, srs, path)?;
    Ok(vi.into())
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_write(
    append: Option<bool>,
    index: CamlPastaFpPlonkVerifierIndex,
    path: String,
) -> Result<(), ocaml::Error> {
    let index: VerifierIndex<Vesta> = index.into();
    let path = Path::new(&path);
    index.to_file(path, append).map_err(|_e| {
        ocaml::Error::invalid_argument("caml_pasta_fp_plonk_verifier_index_raw_read")
            .err()
            .unwrap()
    })
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_create(
    index: CamlPastaFpPlonkIndexPtr,
) -> CamlPastaFpPlonkVerifierIndex {
    {
        let ptr: &mut poly_commitment::srs::SRS<Vesta> =
            unsafe { &mut *(std::sync::Arc::as_ptr(&index.as_ref().0.srs) as *mut _) };
        ptr.add_lagrange_basis(index.as_ref().0.cs.domain.d1);
    }
    let verifier_index = index.as_ref().0.verifier_index();
    verifier_index.into()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_shifts(log2_size: ocaml::Int) -> Vec<CamlFp> {
    let domain = Domain::<Fp>::new(1 << log2_size).unwrap();
    let shifts = Shifts::new(&domain);
    shifts.shifts().iter().map(Into::into).collect()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_dummy() -> CamlPastaFpPlonkVerifierIndex {
    fn comm() -> CamlPolyComm<CamlGVesta> {
        let g: CamlGVesta = Vesta::prime_subgroup_generator().into();
        CamlPolyComm {
            shifted: Some(g),
            unshifted: vec![g, g, g],
        }
    }
    fn vec_comm(num: usize) -> Vec<CamlPolyComm<CamlGVesta>> {
        (0..num).map(|_| comm()).collect()
    }

    CamlPlonkVerifierIndex {
        domain: CamlPlonkDomain {
            log_size_of_group: 1,
            group_gen: Fp::one().into(),
        },
        max_poly_size: 0,
        public: 0,
        prev_challenges: 0,
        srs: CamlFpSrs::new(SRS::create(0)),
        evals: CamlPlonkVerificationEvals {
            sigma_comm: vec_comm(PERMUTS),
            coefficients_comm: vec_comm(COLUMNS),
            generic_comm: comm(),
            psm_comm: comm(),
            complete_add_comm: comm(),
            mul_comm: comm(),
            emul_comm: comm(),
            endomul_scalar_comm: comm(),
            xor_comm: None,
            range_check0_comm: None,
            range_check1_comm: None,
            foreign_field_add_comm: None,
            foreign_field_mul_comm: None,
            rot_comm: None,
            lookup_gate_comm: None,
            runtime_tables_comm: None,
        },
        shifts: (0..PERMUTS).map(|_| Fp::one().into()).collect(),
        lookup_index: None,
    }
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_deep_copy(
    x: CamlPastaFpPlonkVerifierIndex,
) -> CamlPastaFpPlonkVerifierIndex {
    x
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::plonk_verifier_index::{
        CamlPlonkDomain, CamlPlonkVerificationEvals, CamlPlonkVerifierIndex,
    };
    use crate::srs::fp::CamlFpSrs;
    use kimchi::circuits::expr::Linearization;

    fn comm() -> CamlPolyComm<CamlGVesta> {
        let g: CamlGVesta = Vesta::prime_subgroup_generator().into();
        CamlPolyComm {
            shifted: Some(g),
            unshifted: vec![g, g, g],
        }
    }

    fn vec_comm(num: usize) -> Vec<CamlPolyComm<CamlGVesta>> {
        (0..num).map(|_| comm()).collect()
    }

    // Helper function to generate a string representation of a value that
    // derives the Debug trait.  This can be used to get a poor man's
    // PartialEq/Eq-like trait for assertions when nothing else can be done
    fn debug_string<G: std::fmt::Debug>(vi: G) -> String {
        use std::fmt::Write;
        let mut buf = String::new();
        buf.write_fmt(format_args!("{:?}", vi))
            .expect("a Debug implementation returned an error unexpectedly");
        buf.shrink_to_fit();
        buf
    }

    // Generate a verifier index value.
    fn gen_caml_verifier_index() -> CamlPastaFpPlonkVerifierIndex {
        CamlPlonkVerifierIndex {
            domain: CamlPlonkDomain {
                log_size_of_group: 2,
                group_gen: Fp::one().into(),
            },
            max_poly_size: 0,
            public: 0,
            prev_challenges: 0,
            srs: CamlFpSrs::new(SRS::create(0)),
            evals: CamlPlonkVerificationEvals {
                sigma_comm: vec_comm(PERMUTS),
                coefficients_comm: vec_comm(COLUMNS),
                generic_comm: comm(),
                psm_comm: comm(),
                complete_add_comm: comm(),
                mul_comm: comm(),
                emul_comm: comm(),
                endomul_scalar_comm: comm(),
                xor_comm: Some(comm()),
                range_check0_comm: Some(comm()),
                range_check1_comm: Some(comm()),
                foreign_field_add_comm: Some(comm()),
                foreign_field_mul_comm: Some(comm()),
                rot_comm: Some(comm()),
                lookup_gate_comm: Some(comm()),
                runtime_tables_comm: Some(comm()),
            },
            shifts: (0..PERMUTS).map(|_| Fp::one().into()).collect(),
            lookup_index: None,
        }
    }

    #[test]
    fn back_and_forth() -> () {
        let dummy: CamlPastaFpPlonkVerifierIndex = gen_caml_verifier_index();

        let vi = VerifierIndex::<Vesta>::from(dummy);
        let caml_vi = CamlPastaFpPlonkVerifierIndex::from(vi.clone());
        let vi2 = VerifierIndex::<Vesta>::from(caml_vi);

        // Use pattern-matching to signal that the type has changed through fields warnings
        let VerifierIndex {
            domain,
            max_poly_size,
            srs,
            public,
            prev_challenges,
            xor_comm,
            sigma_comm,
            coefficients_comm,
            generic_comm,
            psm_comm,
            complete_add_comm,
            mul_comm,
            emul_comm,
            endomul_scalar_comm,
            range_check0_comm,
            range_check1_comm,
            foreign_field_mul_comm,
            foreign_field_add_comm,
            rot_comm,
            shift,
            zkpm,
            w,
            endo,
            powers_of_alpha,
            lookup_index,
            linearization:
                Linearization {
                    constant_term,
                    index_terms,
                },
        } = vi;

        //////////////////////////////////////////////////////////////////////////////
        // The full equality assertion is divided up into assertions on fields.     //
        // This helps in localizing errors when they fail.                          //
        // The main issue is that one could easily forget a record field.           //
        // Pay attention to that here.                                              //
        //                                                                          //
        // Would be great to add a assert_eq!(vi, vi2) in the end to catch this but //
        // this might fail due to ordering issue in serialized vectors. See the     //
        // last equality assertion below                                            //
        //////////////////////////////////////////////////////////////////////////////

        assert_eq!(domain, vi2.domain);
        assert_eq!(max_poly_size, vi2.max_poly_size);
        assert_eq!(debug_string(srs), debug_string(vi2.srs));
        assert_eq!(public, vi2.public);
        assert_eq!(prev_challenges, vi2.prev_challenges);

        assert_eq!(xor_comm, vi2.xor_comm);
        assert_eq!(sigma_comm, vi2.sigma_comm);
        assert_eq!(coefficients_comm, vi2.coefficients_comm);
        assert_eq!(generic_comm, vi2.generic_comm);
        assert_eq!(psm_comm, vi2.psm_comm);
        assert_eq!(complete_add_comm, vi2.complete_add_comm);
        assert_eq!(mul_comm, vi2.mul_comm);
        assert_eq!(emul_comm, vi2.emul_comm);
        assert_eq!(endomul_scalar_comm, vi2.endomul_scalar_comm);
        assert_eq!(range_check0_comm, vi2.range_check0_comm);
        assert_eq!(range_check1_comm, vi2.range_check1_comm);
        assert_eq!(foreign_field_mul_comm, vi2.foreign_field_mul_comm);
        assert_eq!(foreign_field_add_comm, vi2.foreign_field_add_comm);
        assert_eq!(rot_comm, vi2.rot_comm);
        assert_eq!(shift, vi2.shift);
        assert_eq!(zkpm, vi2.zkpm);
        assert_eq!(w, vi2.w);
        assert_eq!(endo, vi2.endo);
        assert_eq!(powers_of_alpha, vi2.powers_of_alpha);
        assert_eq!(debug_string(lookup_index), debug_string(vi2.lookup_index));

        assert_eq!(constant_term, vi2.linearization.constant_term);

        // Serialization back and forth seems to change the order in
        // vector. Sort it before applying equality comparison.
        let mut it1 = index_terms.to_vec();
        let mut it2 = vi2.linearization.index_terms.to_vec();
        assert_eq!(it1.sort(), it2.sort());
    }
}
