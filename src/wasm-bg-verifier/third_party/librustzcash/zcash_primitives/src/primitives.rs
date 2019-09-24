use ff::{Field, PrimeField, PrimeFieldRepr};

use crate::constants;

use crate::group_hash::group_hash;

use crate::pedersen_hash::{pedersen_hash, Personalization};

use byteorder::{LittleEndian, WriteBytesExt};

use crate::jubjub::{edwards, FixedGenerators, JubjubEngine, JubjubParams, PrimeOrder};

use blake2s_simd::Params as Blake2sParams;

#[derive(Clone)]
pub struct ValueCommitment<E: JubjubEngine> {
    pub value: u64,
    pub randomness: E::Fs,
}

impl<E: JubjubEngine> ValueCommitment<E> {
    pub fn cm(&self, params: &E::Params) -> edwards::Point<E, PrimeOrder> {
        params
            .generator(FixedGenerators::ValueCommitmentValue)
            .mul(self.value, params)
            .add(
                &params
                    .generator(FixedGenerators::ValueCommitmentRandomness)
                    .mul(self.randomness, params),
                params,
            )
    }
}

#[derive(Clone)]
pub struct ProofGenerationKey<E: JubjubEngine> {
    pub ak: edwards::Point<E, PrimeOrder>,
    pub nsk: E::Fs,
}

impl<E: JubjubEngine> ProofGenerationKey<E> {
    pub fn to_viewing_key(&self, params: &E::Params) -> ViewingKey<E> {
        ViewingKey {
            ak: self.ak.clone(),
            nk: params
                .generator(FixedGenerators::ProofGenerationKey)
                .mul(self.nsk, params),
        }
    }
}

#[derive(Debug)]
pub struct ViewingKey<E: JubjubEngine> {
    pub ak: edwards::Point<E, PrimeOrder>,
    pub nk: edwards::Point<E, PrimeOrder>,
}

impl<E: JubjubEngine> ViewingKey<E> {
    pub fn rk(&self, ar: E::Fs, params: &E::Params) -> edwards::Point<E, PrimeOrder> {
        self.ak.add(
            &params
                .generator(FixedGenerators::SpendingKeyGenerator)
                .mul(ar, params),
            params,
        )
    }

    pub fn ivk(&self) -> E::Fs {
        let mut preimage = [0; 64];

        self.ak.write(&mut preimage[0..32]).unwrap();
        self.nk.write(&mut preimage[32..64]).unwrap();

        let mut h = [0; 32];
        h.copy_from_slice(
            Blake2sParams::new()
                .hash_length(32)
                .personal(constants::CRH_IVK_PERSONALIZATION)
                .hash(&preimage)
                .as_bytes(),
        );

        // Drop the most significant five bits, so it can be interpreted as a scalar.
        h[31] &= 0b0000_0111;

        let mut e = <E::Fs as PrimeField>::Repr::default();
        e.read_le(&h[..]).unwrap();

        E::Fs::from_repr(e).expect("should be a valid scalar")
    }

    pub fn to_payment_address(
        &self,
        diversifier: Diversifier,
        params: &E::Params,
    ) -> Option<PaymentAddress<E>> {
        diversifier.g_d(params).and_then(|g_d| {
            let pk_d = g_d.mul(self.ivk(), params);

            PaymentAddress::from_parts(diversifier, pk_d)
        })
    }
}

#[derive(Copy, Clone, Debug, PartialEq)]
pub struct Diversifier(pub [u8; 11]);

impl Diversifier {
    pub fn g_d<E: JubjubEngine>(
        &self,
        params: &E::Params,
    ) -> Option<edwards::Point<E, PrimeOrder>> {
        group_hash::<E>(
            &self.0,
            constants::KEY_DIVERSIFICATION_PERSONALIZATION,
            params,
        )
    }
}

/// A Sapling payment address.
///
/// # Invariants
///
/// `pk_d` is guaranteed to be prime-order (i.e. in the prime-order subgroup of Jubjub,
/// and not the identity).
#[derive(Clone, Debug)]
pub struct PaymentAddress<E: JubjubEngine> {
    pk_d: edwards::Point<E, PrimeOrder>,
    diversifier: Diversifier,
}

impl<E: JubjubEngine> PartialEq for PaymentAddress<E> {
    fn eq(&self, other: &Self) -> bool {
        self.pk_d == other.pk_d && self.diversifier == other.diversifier
    }
}

impl<E: JubjubEngine> PaymentAddress<E> {
    /// Constructs a PaymentAddress from a diversifier and a Jubjub point.
    ///
    /// Returns None if `pk_d` is the identity.
    pub fn from_parts(
        diversifier: Diversifier,
        pk_d: edwards::Point<E, PrimeOrder>,
    ) -> Option<Self> {
        if pk_d == edwards::Point::zero() {
            None
        } else {
            Some(PaymentAddress { pk_d, diversifier })
        }
    }

    /// Constructs a PaymentAddress from a diversifier and a Jubjub point.
    ///
    /// Only for test code, as this explicitly bypasses the invariant.
    #[cfg(test)]
    pub(crate) fn from_parts_unchecked(
        diversifier: Diversifier,
        pk_d: edwards::Point<E, PrimeOrder>,
    ) -> Self {
        PaymentAddress { pk_d, diversifier }
    }

    /// Parses a PaymentAddress from bytes.
    pub fn from_bytes(bytes: &[u8; 43], params: &E::Params) -> Option<Self> {
        let diversifier = {
            let mut tmp = [0; 11];
            tmp.copy_from_slice(&bytes[0..11]);
            Diversifier(tmp)
        };
        // Check that the diversifier is valid
        if diversifier.g_d::<E>(params).is_none() {
            return None;
        }

        edwards::Point::<E, _>::read(&bytes[11..43], params)
            .ok()?
            .as_prime_order(params)
            .and_then(|pk_d| PaymentAddress::from_parts(diversifier, pk_d))
    }

    /// Returns the byte encoding of this `PaymentAddress`.
    pub fn to_bytes(&self) -> [u8; 43] {
        let mut bytes = [0; 43];
        bytes[0..11].copy_from_slice(&self.diversifier.0);
        self.pk_d.write(&mut bytes[11..]).unwrap();
        bytes
    }

    /// Returns the [`Diversifier`] for this `PaymentAddress`.
    pub fn diversifier(&self) -> &Diversifier {
        &self.diversifier
    }

    /// Returns `pk_d` for this `PaymentAddress`.
    pub fn pk_d(&self) -> &edwards::Point<E, PrimeOrder> {
        &self.pk_d
    }

    pub fn g_d(&self, params: &E::Params) -> Option<edwards::Point<E, PrimeOrder>> {
        self.diversifier.g_d(params)
    }

    pub fn create_note(
        &self,
        value: u64,
        randomness: E::Fs,
        params: &E::Params,
    ) -> Option<Note<E>> {
        self.g_d(params).map(|g_d| Note {
            value,
            r: randomness,
            g_d,
            pk_d: self.pk_d.clone(),
        })
    }
}

#[derive(Clone, Debug)]
pub struct Note<E: JubjubEngine> {
    /// The value of the note
    pub value: u64,
    /// The diversified base of the address, GH(d)
    pub g_d: edwards::Point<E, PrimeOrder>,
    /// The public key of the address, g_d^ivk
    pub pk_d: edwards::Point<E, PrimeOrder>,
    /// The commitment randomness
    pub r: E::Fs,
}

impl<E: JubjubEngine> PartialEq for Note<E> {
    fn eq(&self, other: &Self) -> bool {
        self.value == other.value
            && self.g_d == other.g_d
            && self.pk_d == other.pk_d
            && self.r == other.r
    }
}

impl<E: JubjubEngine> Note<E> {
    pub fn uncommitted() -> E::Fr {
        // The smallest u-coordinate that is not on the curve
        // is one.
        // TODO: This should be relocated to JubjubEngine as
        // it's specific to the curve we're using, not all
        // twisted edwards curves.
        E::Fr::one()
    }

    /// Computes the note commitment, returning the full point.
    fn cm_full_point(&self, params: &E::Params) -> edwards::Point<E, PrimeOrder> {
        // Calculate the note contents, as bytes
        let mut note_contents = vec![];

        // Writing the value in little endian
        (&mut note_contents)
            .write_u64::<LittleEndian>(self.value)
            .unwrap();

        // Write g_d
        self.g_d.write(&mut note_contents).unwrap();

        // Write pk_d
        self.pk_d.write(&mut note_contents).unwrap();

        assert_eq!(note_contents.len(), 32 + 32 + 8);

        // Compute the Pedersen hash of the note contents
        let hash_of_contents = pedersen_hash(
            Personalization::NoteCommitment,
            note_contents
                .into_iter()
                .flat_map(|byte| (0..8).map(move |i| ((byte >> i) & 1) == 1)),
            params,
        );

        // Compute final commitment
        params
            .generator(FixedGenerators::NoteCommitmentRandomness)
            .mul(self.r, params)
            .add(&hash_of_contents, params)
    }

    /// Computes the nullifier given the viewing key and
    /// note position
    pub fn nf(&self, viewing_key: &ViewingKey<E>, position: u64, params: &E::Params) -> Vec<u8> {
        // Compute rho = cm + position.G
        let rho = self.cm_full_point(params).add(
            &params
                .generator(FixedGenerators::NullifierPosition)
                .mul(position, params),
            params,
        );

        // Compute nf = BLAKE2s(nk | rho)
        let mut nf_preimage = [0u8; 64];
        viewing_key.nk.write(&mut nf_preimage[0..32]).unwrap();
        rho.write(&mut nf_preimage[32..64]).unwrap();
        Blake2sParams::new()
            .hash_length(32)
            .personal(constants::PRF_NF_PERSONALIZATION)
            .hash(&nf_preimage)
            .as_bytes()
            .to_vec()
    }

    /// Computes the note commitment
    pub fn cm(&self, params: &E::Params) -> E::Fr {
        // The commitment is in the prime order subgroup, so mapping the
        // commitment to the x-coordinate is an injective encoding.
        self.cm_full_point(params).to_xy().0
    }
}
