use crate::{
    mnt4::MNT4Parameters,
    short_weierstrass_jacobian::{GroupAffine, GroupProjective},
    AffineCurve,
};
use ark_ff::{bytes::ToBytes, Fp2};
use ark_std::io::{Result as IoResult, Write};

pub type G1Affine<P> = GroupAffine<<P as MNT4Parameters>::G1Parameters>;
pub type G1Projective<P> = GroupProjective<<P as MNT4Parameters>::G1Parameters>;

#[derive(Derivative)]
#[derivative(
    Copy(bound = "P: MNT4Parameters"),
    Clone(bound = "P: MNT4Parameters"),
    Debug(bound = "P: MNT4Parameters"),
    PartialEq(bound = "P: MNT4Parameters"),
    Eq(bound = "P: MNT4Parameters")
)]
pub struct G1Prepared<P: MNT4Parameters> {
    pub x: P::Fp,
    pub y: P::Fp,
    pub x_twist: Fp2<P::Fp2Params>,
    pub y_twist: Fp2<P::Fp2Params>,
}

impl<P: MNT4Parameters> From<G1Affine<P>> for G1Prepared<P> {
    fn from(g1: G1Affine<P>) -> Self {
        let mut x_twist = P::TWIST;
        x_twist.mul_assign_by_fp(&g1.x);

        let mut y_twist = P::TWIST;
        y_twist.mul_assign_by_fp(&g1.y);

        Self {
            x: g1.x,
            y: g1.y,
            x_twist,
            y_twist,
        }
    }
}

impl<P: MNT4Parameters> Default for G1Prepared<P> {
    fn default() -> Self {
        Self::from(G1Affine::<P>::prime_subgroup_generator())
    }
}

impl<P: MNT4Parameters> ToBytes for G1Prepared<P> {
    fn write<W: Write>(&self, mut writer: W) -> IoResult<()> {
        self.x.write(&mut writer)?;
        self.y.write(&mut writer)?;
        self.x_twist.write(&mut writer)?;
        self.y_twist.write(&mut writer)
    }
}
