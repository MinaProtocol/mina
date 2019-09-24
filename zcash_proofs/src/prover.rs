//! Abstractions over the proving system and parameters for ease of use.

use bellman::groth16::{Parameters, PreparedVerifyingKey};
use directories::BaseDirs;
use pairing::bls12_381::{Bls12, Fr};
use std::path::Path;
use zcash_primitives::{
    jubjub::{edwards, fs::Fs, Unknown},
    primitives::{Diversifier, PaymentAddress, ProofGenerationKey},
};
use zcash_primitives::{
    merkle_tree::CommitmentTreeWitness,
    prover::TxProver,
    redjubjub::{PublicKey, Signature},
    sapling::Node,
    transaction::components::{Amount, GROTH_PROOF_SIZE},
    JUBJUB,
};

use crate::{load_parameters, sapling::SaplingProvingContext};

const SAPLING_SPEND_HASH: &str = "8270785a1a0d0bc77196f000ee6d221c9c9894f55307bd9357c3f0105d31ca63991ab91324160d8f53e2bbd3c2633a6eb8bdf5205d822e7f3f73edac51b2b70c";
const SAPLING_OUTPUT_HASH: &str = "657e3d38dbb5cb5e7dd2970e8b03d69b4787dd907285b5a7f0790dcc8072f60bf593b32cc2d1c030e00ff5ae64bf84c5c3beb84ddc841d48264b4a171744d028";

/// An implementation of [`TxProver`] using Sapling Spend and Output parameters from
/// locally-accessible paths.
pub struct LocalTxProver {
    spend_params: Parameters<Bls12>,
    spend_vk: PreparedVerifyingKey<Bls12>,
    output_params: Parameters<Bls12>,
}

impl LocalTxProver {
    /// Creates a `LocalTxProver` using parameters from the given local paths.
    ///
    /// # Examples
    ///
    /// ```should_panic
    /// use std::path::Path;
    /// use zcash_proofs::prover::LocalTxProver;
    ///
    /// let tx_prover = LocalTxProver::new(
    ///     Path::new("/path/to/sapling-spend.params"),
    ///     Path::new("/path/to/sapling-output.params"),
    /// );
    /// ```
    ///
    /// # Panics
    ///
    /// This function will panic if the paths do not point to valid parameter files with
    /// the expected hashes.
    pub fn new(spend_path: &Path, output_path: &Path) -> Self {
        let (spend_params, spend_vk, output_params, _, _) = load_parameters(
            spend_path,
            SAPLING_SPEND_HASH,
            output_path,
            SAPLING_OUTPUT_HASH,
            None,
            None,
        );
        LocalTxProver {
            spend_params,
            spend_vk,
            output_params,
        }
    }

    /// Attempts to create a `LocalTxProver` using parameters from the default local
    /// location.
    ///
    /// Returns `None` if any of the parameters cannot be found in the default local
    /// location.
    ///
    /// # Examples
    ///
    /// ```
    /// use zcash_proofs::prover::LocalTxProver;
    ///
    /// match LocalTxProver::with_default_location() {
    ///     Some(tx_prover) => (),
    ///     None => println!("Please run zcash-fetch-params or fetch-params.sh to download the parameters."),
    /// }
    /// ```
    ///
    /// # Panics
    ///
    /// This function will panic if the parameters in the default local location do not
    /// have the expected hashes.
    pub fn with_default_location() -> Option<Self> {
        let base_dirs = BaseDirs::new()?;
        let unix_params_dir = base_dirs.home_dir().join(".zcash-params");
        let win_osx_params_dir = base_dirs.data_dir().join("ZcashParams");
        let (spend_path, output_path) = if unix_params_dir.exists() {
            (
                unix_params_dir.join("sapling-spend.params"),
                unix_params_dir.join("sapling-output.params"),
            )
        } else if win_osx_params_dir.exists() {
            (
                win_osx_params_dir.join("sapling-spend.params"),
                win_osx_params_dir.join("sapling-output.params"),
            )
        } else {
            return None;
        };
        if !(spend_path.exists() && output_path.exists()) {
            return None;
        }

        Some(LocalTxProver::new(&spend_path, &output_path))
    }
}

impl TxProver for LocalTxProver {
    type SaplingProvingContext = SaplingProvingContext;

    fn new_sapling_proving_context(&self) -> Self::SaplingProvingContext {
        SaplingProvingContext::new()
    }

    fn spend_proof(
        &self,
        ctx: &mut Self::SaplingProvingContext,
        proof_generation_key: ProofGenerationKey<Bls12>,
        diversifier: Diversifier,
        rcm: Fs,
        ar: Fs,
        value: u64,
        anchor: Fr,
        witness: CommitmentTreeWitness<Node>,
    ) -> Result<
        (
            [u8; GROTH_PROOF_SIZE],
            edwards::Point<Bls12, Unknown>,
            PublicKey<Bls12>,
        ),
        (),
    > {
        let (proof, cv, rk) = ctx.spend_proof(
            proof_generation_key,
            diversifier,
            rcm,
            ar,
            value,
            anchor,
            witness,
            &self.spend_params,
            &self.spend_vk,
            &JUBJUB,
        )?;

        let mut zkproof = [0u8; GROTH_PROOF_SIZE];
        proof
            .write(&mut zkproof[..])
            .expect("should be able to serialize a proof");

        Ok((zkproof, cv, rk))
    }

    fn output_proof(
        &self,
        ctx: &mut Self::SaplingProvingContext,
        esk: Fs,
        payment_address: PaymentAddress<Bls12>,
        rcm: Fs,
        value: u64,
    ) -> ([u8; GROTH_PROOF_SIZE], edwards::Point<Bls12, Unknown>) {
        let (proof, cv) = ctx.output_proof(
            esk,
            payment_address,
            rcm,
            value,
            &self.output_params,
            &JUBJUB,
        );

        let mut zkproof = [0u8; GROTH_PROOF_SIZE];
        proof
            .write(&mut zkproof[..])
            .expect("should be able to serialize a proof");

        (zkproof, cv)
    }

    fn binding_sig(
        &self,
        ctx: &mut Self::SaplingProvingContext,
        value_balance: Amount,
        sighash: &[u8; 32],
    ) -> Result<Signature, ()> {
        ctx.binding_sig(value_balance, sighash, &JUBJUB)
    }
}
