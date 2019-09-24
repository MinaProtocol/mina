use bellman::groth16::{prepare_verifying_key, Parameters, PreparedVerifyingKey, VerifyingKey};
use pairing::bls12_381::Bls12;
use std::fs::File;
use std::io::{self, BufReader};
use std::path::Path;

pub mod circuit;
mod hashreader;
pub mod sapling;

#[cfg(feature = "local-prover")]
pub mod prover;

pub fn load_parameters(
    spend_path: &Path,
    spend_hash: &str,
    output_path: &Path,
    output_hash: &str,
    sprout_path: Option<&Path>,
    sprout_hash: Option<&str>,
) -> (
    Parameters<Bls12>,
    PreparedVerifyingKey<Bls12>,
    Parameters<Bls12>,
    PreparedVerifyingKey<Bls12>,
    Option<PreparedVerifyingKey<Bls12>>,
) {
    // Load from each of the paths
    let spend_fs = File::open(spend_path).expect("couldn't load Sapling spend parameters file");
    let output_fs = File::open(output_path).expect("couldn't load Sapling output parameters file");
    let sprout_fs =
        sprout_path.map(|p| File::open(p).expect("couldn't load Sprout groth16 parameters file"));

    let mut spend_fs = hashreader::HashReader::new(BufReader::with_capacity(1024 * 1024, spend_fs));
    let mut output_fs =
        hashreader::HashReader::new(BufReader::with_capacity(1024 * 1024, output_fs));
    let mut sprout_fs =
        sprout_fs.map(|fs| hashreader::HashReader::new(BufReader::with_capacity(1024 * 1024, fs)));

    // Deserialize params
    let spend_params = Parameters::<Bls12>::read(&mut spend_fs, false)
        .expect("couldn't deserialize Sapling spend parameters file");
    let output_params = Parameters::<Bls12>::read(&mut output_fs, false)
        .expect("couldn't deserialize Sapling spend parameters file");

    // We only deserialize the verifying key for the Sprout parameters, which
    // appears at the beginning of the parameter file. The rest is loaded
    // during proving time.
    let sprout_vk = sprout_fs.as_mut().map(|mut fs| {
        VerifyingKey::<Bls12>::read(&mut fs)
            .expect("couldn't deserialize Sprout Groth16 verifying key")
    });

    // There is extra stuff (the transcript) at the end of the parameter file which is
    // used to verify the parameter validity, but we're not interested in that. We do
    // want to read it, though, so that the BLAKE2b computed afterward is consistent
    // with `b2sum` on the files.
    let mut sink = io::sink();
    io::copy(&mut spend_fs, &mut sink)
        .expect("couldn't finish reading Sapling spend parameter file");
    io::copy(&mut output_fs, &mut sink)
        .expect("couldn't finish reading Sapling output parameter file");
    if let Some(mut sprout_fs) = sprout_fs.as_mut() {
        io::copy(&mut sprout_fs, &mut sink)
            .expect("couldn't finish reading Sprout groth16 parameter file");
    }

    if spend_fs.into_hash() != spend_hash {
        panic!("Sapling spend parameter file is not correct, please clean your `~/.zcash-params/` and re-run `fetch-params`.");
    }

    if output_fs.into_hash() != output_hash {
        panic!("Sapling output parameter file is not correct, please clean your `~/.zcash-params/` and re-run `fetch-params`.");
    }

    if sprout_fs.map(|fs| fs.into_hash()) != sprout_hash.map(|h| h.to_owned()) {
        panic!("Sprout groth16 parameter file is not correct, please clean your `~/.zcash-params/` and re-run `fetch-params`.");
    }

    // Prepare verifying keys
    let spend_vk = prepare_verifying_key(&spend_params.vk);
    let output_vk = prepare_verifying_key(&output_params.vk);
    let sprout_vk = sprout_vk.map(|vk| prepare_verifying_key(&vk));

    (spend_params, spend_vk, output_params, output_vk, sprout_vk)
}
