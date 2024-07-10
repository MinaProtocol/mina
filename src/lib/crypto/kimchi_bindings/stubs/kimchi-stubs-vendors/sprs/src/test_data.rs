//! Some matrices used in tests

use crate::sparse::CsMat;
use ndarray::{arr2, Array, Ix2, ShapeBuilder};

pub fn mat1() -> CsMat<f64> {
    let indptr = vec![0, 2, 4, 5, 6, 7];
    let indices = vec![2, 3, 3, 4, 2, 1, 3];
    let data = vec![3., 4., 2., 5., 5., 8., 7.];
    CsMat::new((5, 5), indptr, indices, data)
}

pub fn mat1_csc() -> CsMat<f64> {
    let indptr = vec![0, 0, 1, 3, 6, 7];
    let indices = vec![3, 0, 2, 0, 1, 4, 1];
    let data = vec![8., 3., 5., 4., 2., 7., 5.];
    CsMat::new_csc((5, 5), indptr, indices, data)
}

pub fn mat2() -> CsMat<f64> {
    let indptr = vec![0, 4, 6, 6, 8, 10];
    let indices = vec![0, 1, 2, 4, 0, 3, 2, 3, 1, 2];
    let data = vec![6., 7., 3., 3., 8., 9., 2., 4., 4., 4.];
    CsMat::new((5, 5), indptr, indices, data)
}

pub fn mat3() -> CsMat<f64> {
    let indptr = vec![0, 2, 4, 5, 6, 7];
    let indices = vec![2, 3, 2, 3, 2, 1, 3];
    let data = vec![3., 4., 2., 5., 5., 8., 7.];
    CsMat::new((5, 4), indptr, indices, data)
}

pub fn mat4() -> CsMat<f64> {
    let indptr = vec![0, 4, 6, 6, 8, 10];
    let indices = vec![0, 1, 2, 4, 0, 3, 2, 3, 1, 2];
    let data = vec![6., 7., 3., 3., 8., 9., 2., 4., 4., 4.];
    CsMat::new_csc((5, 5), indptr, indices, data)
}

pub fn mat5() -> CsMat<f64> {
    let indptr = vec![0, 5, 11, 14, 20, 22];
    let indices = vec![
        1, 2, 6, 7, 13, 3, 4, 6, 8, 13, 14, 7, 11, 13, 3, 8, 9, 10, 11, 14, 4,
        12,
    ];
    let data = vec![
        4.8, 2., 3.7, 5.9, 6., 1.6, 0.3, 9.2, 9.9, 4.8, 6.1, 4.4, 6., 0.1, 7.2,
        1., 1.4, 6.4, 2.8, 3.4, 5.5, 3.5,
    ];
    CsMat::new((5, 15), indptr, indices, data)
}

/// Returns the scalar product of mat1 and mat2
pub fn mat1_times_2() -> CsMat<f64> {
    let indptr = vec![0, 2, 4, 5, 6, 7];
    let indices = vec![2, 3, 3, 4, 2, 1, 3];
    let data = vec![6., 8., 4., 10., 10., 16., 14.];
    CsMat::new((5, 5), indptr, indices, data)
}

// Matrix product of mat1 with itself
pub fn mat1_self_matprod() -> CsMat<f64> {
    let indptr = vec![0, 2, 4, 5, 7, 8];
    let indices = vec![1, 2, 1, 3, 2, 3, 4, 1];
    let data = vec![32., 15., 16., 35., 25., 16., 40., 56.];
    CsMat::new((5, 5), indptr, indices, data)
}

pub fn mat1_matprod_mat2() -> CsMat<f64> {
    let indptr = vec![0, 2, 5, 5, 7, 9];
    let indices = vec![2, 3, 1, 2, 3, 0, 3, 2, 3];
    let data = vec![8., 16., 20., 24., 8., 64., 72., 14., 28.];
    CsMat::new((5, 5), indptr, indices, data)
}

pub fn mat1_csc_matprod_mat4() -> CsMat<f64> {
    let indptr = vec![0, 4, 7, 7, 11, 14];
    let indices = vec![0, 1, 2, 3, 0, 1, 4, 0, 1, 2, 4, 0, 2, 3];
    let data = vec![
        9., 15., 15., 56., 36., 18., 63., 22., 8., 10., 28., 12., 20., 32.,
    ];
    CsMat::new_csc((5, 5), indptr, indices, data)
}

pub fn mat_dense1() -> Array<f64, Ix2> {
    let m = arr2(&[
        [0., 1., 2., 3., 4.],
        [5., 6., 5., 4., 3.],
        [4., 5., 4., 3., 2.],
        [3., 4., 3., 2., 1.],
        [1., 2., 1., 1., 0.],
    ]);
    m.to_owned()
}

pub fn mat_dense1_colmaj() -> Array<f64, Ix2> {
    let v = vec![
        0., 5., 4., 3., 1., 1., 6., 5., 4., 2., 2., 5., 4., 3., 1., 3., 4., 3.,
        2., 1., 4., 3., 2., 1., 0.,
    ];
    Array::from_shape_vec((5, 5).f(), v).unwrap()
}

pub fn mat_dense2() -> Array<f64, Ix2> {
    let m = arr2(&[
        [8.2, 1.8, 0.9, 2.6, 6.7, 7.6, 8.3],
        [8.7, 9.4, 2.6, 6.4, 3.5, 1.2, 4.7],
        [5.3, 9., 8.7, 9.8, 4.6, 2.5, 4.6],
        [4.7, 6.2, 3.7, 5.6, 4.7, 8.3, 3.],
        [3.5, 6.4, 2.3, 7.3, 4.2, 3.3, 8.9],
        [3.6, 6.2, 7.3, 3.1, 1.5, 4.1, 0.8],
        [8.8, 8.7, 1.6, 6.1, 5.6, 0.1, 8.5],
        [4.8, 4.1, 8.1, 0., 0.4, 3., 5.1],
        [6.6, 3.4, 1.7, 3.9, 2.2, 5.5, 6.8],
        [4.8, 3.7, 9.2, 7.4, 3.5, 1.5, 5.8],
        [4.3, 6.9, 6.5, 5.7, 7.6, 9.5, 5.8],
        [5.7, 6.9, 8.5, 0.1, 5.8, 9.6, 4.9],
        [6.9, 5.4, 0., 1.2, 4.8, 1.5, 7.9],
        [2.8, 5.1, 0.6, 3., 8.4, 8.6, 1.],
        [8.1, 1.9, 6.3, 0.2, 0.3, 5.9, 0.],
    ]);
    m.to_owned()
}
