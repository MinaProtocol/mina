use crate::{
    bw6::BW6Parameters,
    short_weierstrass_jacobian::{GroupAffine, GroupProjective},
    AffineCurve,
};
use ark_ff::bytes::ToBytes;
use ark_std::io::{Result as IoResult, Write};
use num_traits::Zero;

pub type G1Affine<P> = GroupAffine<<P as BW6Parameters>::G1Parameters>;
pub type G1Projective<P> = GroupProjective<<P as BW6Parameters>::G1Parameters>;

#[derive(Derivative)]
#[derivative(
    Clone(bound = "P: BW6Parameters"),
    Debug(bound = "P: BW6Parameters"),
    PartialEq(bound = "P: BW6Parameters"),
    Eq(bound = "P: BW6Parameters")
)]
pub struct G1Prepared<P: BW6Parameters>(pub G1Affine<P>);

impl<P: BW6Parameters> From<G1Affine<P>> for G1Prepared<P> {
    fn from(other: G1Affine<P>) -> Self {
        G1Prepared(other)
    }
}

impl<P: BW6Parameters> G1Prepared<P> {
    pub fn is_zero(&self) -> bool {
        self.0.is_zero()
    }
}

impl<P: BW6Parameters> Default for G1Prepared<P> {
    fn default() -> Self {
        G1Prepared(G1Affine::<P>::prime_subgroup_generator())
    }
}

impl<P: BW6Parameters> ToBytes for G1Prepared<P> {
    fn write<W: Write>(&self, writer: W) -> IoResult<()> {
        self.0.write(writer)
    }
}
