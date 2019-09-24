//! Sapling key components.
//!
//! Implements section 4.2.2 of the Zcash Protocol Specification.

use crate::{
    jubjub::{edwards, FixedGenerators, JubjubEngine, JubjubParams, ToUniform, Unknown},
    primitives::{ProofGenerationKey, ViewingKey},
};
use blake2b_simd::{Hash as Blake2bHash, Params as Blake2bParams};
use ff::{PrimeField, PrimeFieldRepr};
use std::io::{self, Read, Write};

pub const PRF_EXPAND_PERSONALIZATION: &[u8; 16] = b"Zcash_ExpandSeed";

/// PRF^expand(sk, t) := BLAKE2b-512("Zcash_ExpandSeed", sk || t)
pub fn prf_expand(sk: &[u8], t: &[u8]) -> Blake2bHash {
    prf_expand_vec(sk, &[t])
}

pub fn prf_expand_vec(sk: &[u8], ts: &[&[u8]]) -> Blake2bHash {
    let mut h = Blake2bParams::new()
        .hash_length(64)
        .personal(PRF_EXPAND_PERSONALIZATION)
        .to_state();
    h.update(sk);
    for t in ts {
        h.update(t);
    }
    h.finalize()
}

/// An outgoing viewing key
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct OutgoingViewingKey(pub [u8; 32]);

/// A Sapling expanded spending key
#[derive(Clone)]
pub struct ExpandedSpendingKey<E: JubjubEngine> {
    pub ask: E::Fs,
    pub nsk: E::Fs,
    pub ovk: OutgoingViewingKey,
}

/// A Sapling full viewing key
#[derive(Debug)]
pub struct FullViewingKey<E: JubjubEngine> {
    pub vk: ViewingKey<E>,
    pub ovk: OutgoingViewingKey,
}

impl<E: JubjubEngine> ExpandedSpendingKey<E> {
    pub fn from_spending_key(sk: &[u8]) -> Self {
        let ask = E::Fs::to_uniform(prf_expand(sk, &[0x00]).as_bytes());
        let nsk = E::Fs::to_uniform(prf_expand(sk, &[0x01]).as_bytes());
        let mut ovk = OutgoingViewingKey([0u8; 32]);
        ovk.0
            .copy_from_slice(&prf_expand(sk, &[0x02]).as_bytes()[..32]);
        ExpandedSpendingKey { ask, nsk, ovk }
    }

    pub fn proof_generation_key(&self, params: &E::Params) -> ProofGenerationKey<E> {
        ProofGenerationKey {
            ak: params
                .generator(FixedGenerators::SpendingKeyGenerator)
                .mul(self.ask, params),
            nsk: self.nsk,
        }
    }

    pub fn read<R: Read>(mut reader: R) -> io::Result<Self> {
        let mut ask_repr = <E::Fs as PrimeField>::Repr::default();
        ask_repr.read_le(&mut reader)?;
        let ask = E::Fs::from_repr(ask_repr)
            .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;

        let mut nsk_repr = <E::Fs as PrimeField>::Repr::default();
        nsk_repr.read_le(&mut reader)?;
        let nsk = E::Fs::from_repr(nsk_repr)
            .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;

        let mut ovk = [0; 32];
        reader.read_exact(&mut ovk)?;

        Ok(ExpandedSpendingKey {
            ask,
            nsk,
            ovk: OutgoingViewingKey(ovk),
        })
    }

    pub fn write<W: Write>(&self, mut writer: W) -> io::Result<()> {
        self.ask.into_repr().write_le(&mut writer)?;
        self.nsk.into_repr().write_le(&mut writer)?;
        writer.write_all(&self.ovk.0)?;

        Ok(())
    }

    pub fn to_bytes(&self) -> [u8; 96] {
        let mut result = [0u8; 96];
        self.write(&mut result[..])
            .expect("should be able to serialize an ExpandedSpendingKey");
        result
    }
}

impl<E: JubjubEngine> Clone for FullViewingKey<E> {
    fn clone(&self) -> Self {
        FullViewingKey {
            vk: ViewingKey {
                ak: self.vk.ak.clone(),
                nk: self.vk.nk.clone(),
            },
            ovk: self.ovk,
        }
    }
}

impl<E: JubjubEngine> FullViewingKey<E> {
    pub fn from_expanded_spending_key(expsk: &ExpandedSpendingKey<E>, params: &E::Params) -> Self {
        FullViewingKey {
            vk: ViewingKey {
                ak: params
                    .generator(FixedGenerators::SpendingKeyGenerator)
                    .mul(expsk.ask, params),
                nk: params
                    .generator(FixedGenerators::ProofGenerationKey)
                    .mul(expsk.nsk, params),
            },
            ovk: expsk.ovk,
        }
    }

    pub fn read<R: Read>(mut reader: R, params: &E::Params) -> io::Result<Self> {
        let ak = edwards::Point::<E, Unknown>::read(&mut reader, params)?;
        let ak = match ak.as_prime_order(params) {
            Some(p) => p,
            None => {
                return Err(io::Error::new(
                    io::ErrorKind::InvalidData,
                    "ak not in prime-order subgroup",
                ));
            }
        };
        if ak == edwards::Point::zero() {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "ak not of prime order",
            ));
        }

        let nk = edwards::Point::<E, Unknown>::read(&mut reader, params)?;
        let nk = match nk.as_prime_order(params) {
            Some(p) => p,
            None => {
                return Err(io::Error::new(
                    io::ErrorKind::InvalidData,
                    "nk not in prime-order subgroup",
                ));
            }
        };

        let mut ovk = [0; 32];
        reader.read_exact(&mut ovk)?;

        Ok(FullViewingKey {
            vk: ViewingKey { ak, nk },
            ovk: OutgoingViewingKey(ovk),
        })
    }

    pub fn write<W: Write>(&self, mut writer: W) -> io::Result<()> {
        self.vk.ak.write(&mut writer)?;
        self.vk.nk.write(&mut writer)?;
        writer.write_all(&self.ovk.0)?;

        Ok(())
    }

    pub fn to_bytes(&self) -> [u8; 96] {
        let mut result = [0u8; 96];
        self.write(&mut result[..])
            .expect("should be able to serialize a FullViewingKey");
        result
    }
}

#[cfg(test)]
mod tests {
    use crate::jubjub::{edwards, FixedGenerators, JubjubParams, PrimeOrder};
    use pairing::bls12_381::Bls12;
    use std::error::Error;

    use super::FullViewingKey;
    use crate::JUBJUB;

    #[test]
    fn ak_must_be_prime_order() {
        let mut buf = [0; 96];
        let identity = edwards::Point::<Bls12, PrimeOrder>::zero();

        // Set both ak and nk to the identity.
        identity.write(&mut buf[0..32]).unwrap();
        identity.write(&mut buf[32..64]).unwrap();

        // ak is not allowed to be the identity.
        assert_eq!(
            FullViewingKey::<Bls12>::read(&buf[..], &JUBJUB)
                .unwrap_err()
                .description(),
            "ak not of prime order"
        );

        // Set ak to a basepoint.
        let basepoint = JUBJUB.generator(FixedGenerators::SpendingKeyGenerator);
        basepoint.write(&mut buf[0..32]).unwrap();

        // nk is allowed to be the identity.
        assert!(FullViewingKey::<Bls12>::read(&buf[..], &JUBJUB).is_ok());
    }
}
