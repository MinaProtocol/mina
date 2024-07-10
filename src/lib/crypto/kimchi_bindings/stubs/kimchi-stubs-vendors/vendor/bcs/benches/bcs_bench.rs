// Copyright (c) The Diem Core Contributors
// SPDX-License-Identifier: Apache-2.0

use bcs::to_bytes;
use criterion::{criterion_group, criterion_main, Criterion};
use std::collections::{BTreeMap, HashMap};

pub fn bcs_benchmark(c: &mut Criterion) {
    let mut btree_map = BTreeMap::new();
    let mut hash_map = HashMap::new();
    for i in 0u32..2000u32 {
        btree_map.insert(i, i);
        hash_map.insert(i, i);
    }
    c.bench_function("serialize btree map", |b| {
        b.iter(|| {
            to_bytes(&btree_map).unwrap();
        })
    });
    c.bench_function("serialize hash map", |b| {
        b.iter(|| {
            to_bytes(&hash_map).unwrap();
        })
    });
}

criterion_group!(benches, bcs_benchmark);
criterion_main!(benches);
