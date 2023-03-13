//
// Annoying conversion function that will eventually disappear
//

use itertools::Itertools;
use kimchi::{
    snarky::constraint_system::{
        BasicInput, EcAddCompleteInput, EcEndoscaleInput, EndoscaleRound, EndoscaleScalarRound,
        KimchiConstraint, ScaleRound,
    },
    FieldVar,
};
use mina_curves::pasta::Fp;

use crate::arkworks::CamlFp;

use super::CamlFpVar;

pub fn convert_constraint_fp(
    constraint: &KimchiConstraint<CamlFpVar, CamlFp>,
) -> KimchiConstraint<FieldVar<Fp>, Fp> {
    use KimchiConstraint::*;
    match constraint {
        Basic(x) => Basic(basic_conv(x)),
        Poseidon(x) => Poseidon(
            x.into_iter()
                .map(|x| x.into_iter().map(Into::into).collect_vec())
                .collect_vec(),
        ),
        Poseidon2(_) => unreachable!(),
        EcAddComplete(x) => EcAddComplete(ec_add_complete_conv(x)),
        EcScale(x) => EcScale(x.into_iter().map(|x| ec_scale_round(x)).collect()),
        EcEndoscale(x) => EcEndoscale(ec_endoscale_conv(x)),
        EcEndoscalar(x) => {
            EcEndoscalar(x.into_iter().map(|x| ec_endoscale_scalar_conv(x)).collect())
        }
    }
}

pub fn basic_conv(x: &BasicInput<CamlFpVar, CamlFp>) -> BasicInput<FieldVar<Fp>, Fp> {
    let BasicInput {
        l: (l0, l1),
        r: (r0, r1),
        o: (o0, o1),
        m,
        c,
    } = x;

    BasicInput {
        l: (l0.into(), l1.into()),
        r: (r0.into(), r1.into()),
        o: (o0.into(), o1.into()),
        m: m.into(),
        c: c.into(),
    }
}

pub fn ec_add_complete_conv(x: &EcAddCompleteInput<CamlFpVar>) -> EcAddCompleteInput<FieldVar<Fp>> {
    let EcAddCompleteInput {
        p1: (p1_x, p1_y),
        p2: (p2_x, p2_y),
        p3: (p3_x, p3_y),
        inf,
        same_x,
        slope,
        inf_z,
        x21_inv,
    } = x;

    EcAddCompleteInput {
        p1: (p1_x.into(), p1_y.into()),
        p2: (p2_x.into(), p2_y.into()),
        p3: (p3_x.into(), p3_y.into()),
        inf: inf.into(),
        same_x: same_x.into(),
        slope: slope.into(),
        inf_z: inf_z.into(),
        x21_inv: x21_inv.into(),
    }
}

pub fn ec_scale_round(x: &ScaleRound<CamlFpVar>) -> ScaleRound<FieldVar<Fp>> {
    let ScaleRound {
        accs,
        bits,
        ss,
        base: (base0, base1),
        n_prev,
        n_next,
    } = x;
    ScaleRound {
        accs: accs
            .into_iter()
            .map(|(x, y)| (x.into(), y.into()))
            .collect(),
        bits: bits.into_iter().map(Into::into).collect(),
        ss: ss.into_iter().map(Into::into).collect(),
        base: (base0.into(), base1.into()),
        n_prev: n_prev.into(),
        n_next: n_next.into(),
    }
}

pub fn ec_endoscale_round(x: &EndoscaleRound<CamlFpVar>) -> EndoscaleRound<FieldVar<Fp>> {
    let EndoscaleRound {
        xt,
        yt,
        xp,
        yp,
        n_acc,
        xr,
        yr,
        s1,
        s3,
        b1,
        b2,
        b3,
        b4,
    } = x;

    EndoscaleRound {
        xt: xt.into(),
        yt: yt.into(),
        xp: xp.into(),
        yp: yp.into(),
        n_acc: n_acc.into(),
        xr: xr.into(),
        yr: yr.into(),
        s1: s1.into(),
        s3: s3.into(),
        b1: b1.into(),
        b2: b2.into(),
        b3: b3.into(),
        b4: b4.into(),
    }
}

pub fn ec_endoscale_conv(x: &EcEndoscaleInput<CamlFpVar>) -> EcEndoscaleInput<FieldVar<Fp>> {
    let EcEndoscaleInput {
        state,
        xs,
        ys,
        n_acc,
    } = x;

    EcEndoscaleInput {
        state: state.into_iter().map(|x| ec_endoscale_round(x)).collect(),
        xs: xs.into(),
        ys: ys.into(),
        n_acc: n_acc.into(),
    }
}

pub fn ec_endoscale_scalar_conv(
    x: &EndoscaleScalarRound<CamlFpVar>,
) -> EndoscaleScalarRound<FieldVar<Fp>> {
    let EndoscaleScalarRound {
        n0,
        n8,
        a0,
        b0,
        a8,
        b8,
        x0,
        x1,
        x2,
        x3,
        x4,
        x5,
        x6,
        x7,
    } = x;

    EndoscaleScalarRound {
        n0: n0.into(),
        n8: n8.into(),
        a0: a0.into(),
        b0: b0.into(),
        a8: a8.into(),
        b8: b8.into(),
        x0: x0.into(),
        x1: x1.into(),
        x2: x2.into(),
        x3: x3.into(),
        x4: x4.into(),
        x5: x5.into(),
        x6: x6.into(),
        x7: x7.into(),
    }
}
