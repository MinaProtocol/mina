#![feature(test)]

extern crate pairing;
extern crate rand_core;
extern crate rand_os;
extern crate test;
extern crate zcash_primitives;

use pairing::bls12_381::Bls12;
use rand_core::RngCore;
use rand_os::OsRng;
use zcash_primitives::jubjub::JubjubBls12;
use zcash_primitives::pedersen_hash::{pedersen_hash, Personalization};

#[bench]
fn bench_pedersen_hash(b: &mut test::Bencher) {
    let params = JubjubBls12::new();
    let rng = &mut OsRng;
    let bits = (0..510)
        .map(|_| (rng.next_u32() % 2) != 0)
        .collect::<Vec<_>>();
    let personalization = Personalization::MerkleTree(31);

    b.iter(|| pedersen_hash::<Bls12, _>(personalization, bits.clone(), &params));
}
