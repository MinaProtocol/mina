use bencher::{benchmark_group, benchmark_main, Bencher};
use ndarray::{Array, Array2, ShapeBuilder};
use sprs::{CsMat, CsVec};

fn sparse_dense_dotprod_default(bench: &mut Bencher) {
    let w = Array::range(0., 10., 0.00001);
    let x = CsVec::new(1000000, vec![0, 200000, 800000], vec![1., 2., 3.]);
    bench.iter(|| {
        x.dot(&w);
    });
}

fn sparse_dense_dotprod_specialized(bench: &mut Bencher) {
    let w = Array::range(0., 10., 0.00001);
    let x = CsVec::new(1000000, vec![0, 200000, 800000], vec![1., 2., 3.]);
    bench.iter(|| {
        x.dot_dense(w.view());
    });
}

fn sparse_dense_vec_matprod_default(bench: &mut Bencher) {
    let w = Array::range(0., 10., 0.00001);
    let a = CsMat::new(
        (3, 1000000),
        vec![0, 2, 4, 5],
        vec![0, 1, 0, 2, 2],
        vec![1., 2., 3., 4., 5.],
    );
    bench.iter(|| {
        let _ = &a * &w;
    });
}

fn sparse_dense_vec_matprod_specialized(bench: &mut Bencher) {
    let w = Array::range(0., 10., 0.00001);
    let a = CsMat::new(
        (3, 1000000),
        vec![0, 2, 4, 5],
        vec![0, 1, 0, 2, 2],
        vec![1., 2., 3., 4., 5.],
    );
    let rows = a.rows();
    let cols = w.shape()[0];
    let w_reshape = w.view().into_shape((1, cols)).unwrap();
    let w_t = w_reshape.t();
    let mut res = Array2::<f64>::zeros((rows, 1).f());
    bench.iter(|| {
        sprs::prod::csr_mulacc_dense_colmaj(
            a.view(),
            w_t.view(),
            res.view_mut(),
        );
    });
}

benchmark_group!(
    benches,
    sparse_dense_dotprod_default,
    sparse_dense_dotprod_specialized,
    sparse_dense_vec_matprod_specialized,
    sparse_dense_vec_matprod_default
);
benchmark_main!(benches);
