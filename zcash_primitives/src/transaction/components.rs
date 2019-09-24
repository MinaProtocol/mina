use crate::jubjub::{edwards, Unknown};
use byteorder::{LittleEndian, ReadBytesExt, WriteBytesExt};
use ff::{PrimeField, PrimeFieldRepr};
use pairing::bls12_381::{Bls12, Fr, FrRepr};
use std::io::{self, Read, Write};

use crate::legacy::Script;
use crate::redjubjub::{PublicKey, Signature};
use crate::JUBJUB;

pub mod amount;
pub use self::amount::Amount;

// π_A + π_B + π_C
pub const GROTH_PROOF_SIZE: usize = (48 + 96 + 48);
// π_A + π_A' + π_B + π_B' + π_C + π_C' + π_K + π_H
const PHGR_PROOF_SIZE: usize = (33 + 33 + 65 + 33 + 33 + 33 + 33 + 33);

const ZC_NUM_JS_INPUTS: usize = 2;
const ZC_NUM_JS_OUTPUTS: usize = 2;

#[derive(Debug)]
pub struct OutPoint {
    hash: [u8; 32],
    n: u32,
}

impl OutPoint {
    pub fn read<R: Read>(mut reader: R) -> io::Result<Self> {
        let mut hash = [0; 32];
        reader.read_exact(&mut hash)?;
        let n = reader.read_u32::<LittleEndian>()?;
        Ok(OutPoint { hash, n })
    }

    pub fn write<W: Write>(&self, mut writer: W) -> io::Result<()> {
        writer.write_all(&self.hash)?;
        writer.write_u32::<LittleEndian>(self.n)
    }
}

#[derive(Debug)]
pub struct TxIn {
    pub prevout: OutPoint,
    script_sig: Script,
    pub sequence: u32,
}

impl TxIn {
    pub fn read<R: Read>(mut reader: &mut R) -> io::Result<Self> {
        let prevout = OutPoint::read(&mut reader)?;
        let script_sig = Script::read(&mut reader)?;
        let sequence = reader.read_u32::<LittleEndian>()?;

        Ok(TxIn {
            prevout,
            script_sig,
            sequence,
        })
    }

    pub fn write<W: Write>(&self, mut writer: W) -> io::Result<()> {
        self.prevout.write(&mut writer)?;
        self.script_sig.write(&mut writer)?;
        writer.write_u32::<LittleEndian>(self.sequence)
    }
}

#[derive(Debug)]
pub struct TxOut {
    pub value: Amount,
    pub script_pubkey: Script,
}

impl TxOut {
    pub fn read<R: Read>(mut reader: &mut R) -> io::Result<Self> {
        let value = {
            let mut tmp = [0; 8];
            reader.read_exact(&mut tmp)?;
            Amount::from_nonnegative_i64_le_bytes(tmp)
        }
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidData, "value out of range"))?;
        let script_pubkey = Script::read(&mut reader)?;

        Ok(TxOut {
            value,
            script_pubkey,
        })
    }

    pub fn write<W: Write>(&self, mut writer: W) -> io::Result<()> {
        writer.write_all(&self.value.to_i64_le_bytes())?;
        self.script_pubkey.write(&mut writer)
    }
}

pub struct SpendDescription {
    pub cv: edwards::Point<Bls12, Unknown>,
    pub anchor: Fr,
    pub nullifier: [u8; 32],
    pub rk: PublicKey<Bls12>,
    pub zkproof: [u8; GROTH_PROOF_SIZE],
    pub spend_auth_sig: Option<Signature>,
}

impl std::fmt::Debug for SpendDescription {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> Result<(), std::fmt::Error> {
        write!(
            f,
            "SpendDescription(cv = {:?}, anchor = {:?}, nullifier = {:?}, rk = {:?}, spend_auth_sig = {:?})",
            self.cv, self.anchor, self.nullifier, self.rk, self.spend_auth_sig
        )
    }
}

impl SpendDescription {
    pub fn read<R: Read>(mut reader: &mut R) -> io::Result<Self> {
        // Consensus rules (§4.4):
        // - Canonical encoding is enforced here.
        // - "Not small order" is enforced in SaplingVerificationContext::check_spend()
        //   (located in zcash_proofs::sapling::verifier).
        let cv = edwards::Point::<Bls12, Unknown>::read(&mut reader, &JUBJUB)?;

        // Consensus rule (§7.3): Canonical encoding is enforced here
        let anchor = {
            let mut f = FrRepr::default();
            f.read_le(&mut reader)?;
            Fr::from_repr(f).map_err(|e| io::Error::new(io::ErrorKind::InvalidInput, e))?
        };

        let mut nullifier = [0; 32];
        reader.read_exact(&mut nullifier)?;

        // Consensus rules (§4.4):
        // - Canonical encoding is enforced here.
        // - "Not small order" is enforced in SaplingVerificationContext::check_spend()
        let rk = PublicKey::<Bls12>::read(&mut reader, &JUBJUB)?;

        // Consensus rules (§4.4):
        // - Canonical encoding is enforced by the API of SaplingVerificationContext::check_spend()
        //   due to the need to parse this into a bellman::groth16::Proof.
        // - Proof validity is enforced in SaplingVerificationContext::check_spend()
        let mut zkproof = [0; GROTH_PROOF_SIZE];
        reader.read_exact(&mut zkproof)?;

        // Consensus rules (§4.4):
        // - Canonical encoding is enforced here.
        // - Signature validity is enforced in SaplingVerificationContext::check_spend()
        let spend_auth_sig = Some(Signature::read(&mut reader)?);

        Ok(SpendDescription {
            cv,
            anchor,
            nullifier,
            rk,
            zkproof,
            spend_auth_sig,
        })
    }

    pub fn write<W: Write>(&self, mut writer: W) -> io::Result<()> {
        self.cv.write(&mut writer)?;
        self.anchor.into_repr().write_le(&mut writer)?;
        writer.write_all(&self.nullifier)?;
        self.rk.write(&mut writer)?;
        writer.write_all(&self.zkproof)?;
        match self.spend_auth_sig {
            Some(sig) => sig.write(&mut writer),
            None => Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "Missing spend auth signature",
            )),
        }
    }
}

pub struct OutputDescription {
    pub cv: edwards::Point<Bls12, Unknown>,
    pub cmu: Fr,
    pub ephemeral_key: edwards::Point<Bls12, Unknown>,
    pub enc_ciphertext: [u8; 580],
    pub out_ciphertext: [u8; 80],
    pub zkproof: [u8; GROTH_PROOF_SIZE],
}

impl std::fmt::Debug for OutputDescription {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> Result<(), std::fmt::Error> {
        write!(
            f,
            "OutputDescription(cv = {:?}, cmu = {:?}, ephemeral_key = {:?})",
            self.cv, self.cmu, self.ephemeral_key
        )
    }
}

impl OutputDescription {
    pub fn read<R: Read>(mut reader: &mut R) -> io::Result<Self> {
        // Consensus rules (§4.5):
        // - Canonical encoding is enforced here.
        // - "Not small order" is enforced in SaplingVerificationContext::check_output()
        //   (located in zcash_proofs::sapling::verifier).
        let cv = edwards::Point::<Bls12, Unknown>::read(&mut reader, &JUBJUB)?;

        // Consensus rule (§7.4): Canonical encoding is enforced here
        let cmu = {
            let mut f = FrRepr::default();
            f.read_le(&mut reader)?;
            Fr::from_repr(f).map_err(|e| io::Error::new(io::ErrorKind::InvalidInput, e))?
        };

        // Consensus rules (§4.5):
        // - Canonical encoding is enforced here.
        // - "Not small order" is enforced in SaplingVerificationContext::check_output()
        let ephemeral_key = edwards::Point::<Bls12, Unknown>::read(&mut reader, &JUBJUB)?;

        let mut enc_ciphertext = [0; 580];
        let mut out_ciphertext = [0; 80];
        reader.read_exact(&mut enc_ciphertext)?;
        reader.read_exact(&mut out_ciphertext)?;

        // Consensus rules (§4.5):
        // - Canonical encoding is enforced by the API of SaplingVerificationContext::check_output()
        //   due to the need to parse this into a bellman::groth16::Proof.
        // - Proof validity is enforced in SaplingVerificationContext::check_output()
        let mut zkproof = [0; GROTH_PROOF_SIZE];
        reader.read_exact(&mut zkproof)?;

        Ok(OutputDescription {
            cv,
            cmu,
            ephemeral_key,
            enc_ciphertext,
            out_ciphertext,
            zkproof,
        })
    }

    pub fn write<W: Write>(&self, mut writer: W) -> io::Result<()> {
        self.cv.write(&mut writer)?;
        self.cmu.into_repr().write_le(&mut writer)?;
        self.ephemeral_key.write(&mut writer)?;
        writer.write_all(&self.enc_ciphertext)?;
        writer.write_all(&self.out_ciphertext)?;
        writer.write_all(&self.zkproof)
    }
}

enum SproutProof {
    Groth([u8; GROTH_PROOF_SIZE]),
    PHGR([u8; PHGR_PROOF_SIZE]),
}

impl std::fmt::Debug for SproutProof {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> Result<(), std::fmt::Error> {
        match self {
            SproutProof::Groth(_) => write!(f, "SproutProof::Groth"),
            SproutProof::PHGR(_) => write!(f, "SproutProof::PHGR"),
        }
    }
}

pub struct JSDescription {
    vpub_old: Amount,
    vpub_new: Amount,
    anchor: [u8; 32],
    nullifiers: [[u8; 32]; ZC_NUM_JS_INPUTS],
    commitments: [[u8; 32]; ZC_NUM_JS_OUTPUTS],
    ephemeral_key: [u8; 32],
    random_seed: [u8; 32],
    macs: [[u8; 32]; ZC_NUM_JS_INPUTS],
    proof: SproutProof,
    ciphertexts: [[u8; 601]; ZC_NUM_JS_OUTPUTS],
}

impl std::fmt::Debug for JSDescription {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> Result<(), std::fmt::Error> {
        write!(
            f,
            "JSDescription(
                vpub_old = {:?}, vpub_new = {:?},
                anchor = {:?},
                nullifiers = {:?},
                commitments = {:?},
                ephemeral_key = {:?},
                random_seed = {:?},
                macs = {:?})",
            self.vpub_old,
            self.vpub_new,
            self.anchor,
            self.nullifiers,
            self.commitments,
            self.ephemeral_key,
            self.random_seed,
            self.macs
        )
    }
}

impl JSDescription {
    pub fn read<R: Read>(mut reader: R, use_groth: bool) -> io::Result<Self> {
        // Consensus rule (§4.3): Canonical encoding is enforced here
        let vpub_old = {
            let mut tmp = [0; 8];
            reader.read_exact(&mut tmp)?;
            Amount::from_u64_le_bytes(tmp)
        }
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidData, "vpub_old out of range"))?;

        // Consensus rule (§4.3): Canonical encoding is enforced here
        let vpub_new = {
            let mut tmp = [0; 8];
            reader.read_exact(&mut tmp)?;
            Amount::from_u64_le_bytes(tmp)
        }
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidData, "vpub_new out of range"))?;

        // Consensus rule (§4.3): One of vpub_old and vpub_new being zero is
        // enforced by CheckTransactionWithoutProofVerification() in zcashd.

        let mut anchor = [0; 32];
        reader.read_exact(&mut anchor)?;

        let mut nullifiers = [[0; 32]; ZC_NUM_JS_INPUTS];
        nullifiers
            .iter_mut()
            .map(|nf| reader.read_exact(nf))
            .collect::<io::Result<()>>()?;

        let mut commitments = [[0; 32]; ZC_NUM_JS_OUTPUTS];
        commitments
            .iter_mut()
            .map(|cm| reader.read_exact(cm))
            .collect::<io::Result<()>>()?;

        // Consensus rule (§4.3): Canonical encoding is enforced by
        // ZCNoteDecryption::decrypt() in zcashd
        let mut ephemeral_key = [0; 32];
        reader.read_exact(&mut ephemeral_key)?;

        let mut random_seed = [0; 32];
        reader.read_exact(&mut random_seed)?;

        let mut macs = [[0; 32]; ZC_NUM_JS_INPUTS];
        macs.iter_mut()
            .map(|mac| reader.read_exact(mac))
            .collect::<io::Result<()>>()?;

        let proof = if use_groth {
            // Consensus rules (§4.3):
            // - Canonical encoding is enforced in librustzcash_sprout_verify()
            // - Proof validity is enforced in librustzcash_sprout_verify()
            let mut proof = [0; GROTH_PROOF_SIZE];
            reader.read_exact(&mut proof)?;
            SproutProof::Groth(proof)
        } else {
            // Consensus rules (§4.3):
            // - Canonical encoding is enforced by PHGRProof in zcashd
            // - Proof validity is enforced by JSDescription::Verify() in zcashd
            let mut proof = [0; PHGR_PROOF_SIZE];
            reader.read_exact(&mut proof)?;
            SproutProof::PHGR(proof)
        };

        let mut ciphertexts = [[0; 601]; ZC_NUM_JS_OUTPUTS];
        ciphertexts
            .iter_mut()
            .map(|ct| reader.read_exact(ct))
            .collect::<io::Result<()>>()?;

        Ok(JSDescription {
            vpub_old,
            vpub_new,
            anchor,
            nullifiers,
            commitments,
            ephemeral_key,
            random_seed,
            macs,
            proof,
            ciphertexts,
        })
    }

    pub fn write<W: Write>(&self, mut writer: W) -> io::Result<()> {
        writer.write_all(&self.vpub_old.to_i64_le_bytes())?;
        writer.write_all(&self.vpub_new.to_i64_le_bytes())?;
        writer.write_all(&self.anchor)?;
        writer.write_all(&self.nullifiers[0])?;
        writer.write_all(&self.nullifiers[1])?;
        writer.write_all(&self.commitments[0])?;
        writer.write_all(&self.commitments[1])?;
        writer.write_all(&self.ephemeral_key)?;
        writer.write_all(&self.random_seed)?;
        writer.write_all(&self.macs[0])?;
        writer.write_all(&self.macs[1])?;

        match &self.proof {
            SproutProof::Groth(p) => writer.write_all(p)?,
            SproutProof::PHGR(p) => writer.write_all(p)?,
        }

        writer.write_all(&self.ciphertexts[0])?;
        writer.write_all(&self.ciphertexts[1])
    }
}
