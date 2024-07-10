use bencher::{benchmark_group, benchmark_main, Bencher};
use sprs::CsVec;

const NNZ: usize = 900;
const N: usize = 9000;

fn cloning(bench: &mut Bencher) {
    let indices = (0..NNZ).collect::<Vec<_>>();
    let values = vec![1_i64; NNZ];

    bench.iter(|| {
        let _indicies = indices.clone();
        let _values = values.clone();
    });
}

fn create_csmat_from_sorted(bench: &mut Bencher) {
    let indices = (0..NNZ).collect::<Vec<_>>();
    let values = vec![1_i64; NNZ];

    bench.iter(|| {
        let indices = indices.clone();
        let values = values.clone();
        let _v = CsVec::new(N, indices, values);
    });
}

fn create_csmat_from_unsorted(bench: &mut Bencher) {
    use rand::{seq::SliceRandom, SeedableRng};
    let indices = (0..NNZ).collect::<Vec<_>>();
    let values = vec![1_i64; NNZ];

    bench.iter(|| {
        let mut indices = indices.clone();
        let mut rng = rand::rngs::SmallRng::seed_from_u64(42);
        indices.shuffle(&mut rng);
        let values = values.clone();
        let _v = CsVec::new_from_unsorted(N, indices, values).unwrap();
    });
}

benchmark_group!(
    benches,
    cloning,
    create_csmat_from_sorted,
    create_csmat_from_unsorted
);
benchmark_main!(benches);
