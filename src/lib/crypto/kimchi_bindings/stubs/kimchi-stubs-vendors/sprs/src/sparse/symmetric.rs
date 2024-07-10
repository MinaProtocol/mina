/// Functions dealing with symmetric sparse matrices
use std::ops::Deref;

use crate::indexing::SpIndex;
use crate::sparse::prelude::*;

pub fn is_symmetric<N, I, Iptr, IpStorage, IStorage, DStorage>(
    mat: &CsMatBase<N, I, IpStorage, IStorage, DStorage, Iptr>,
) -> bool
where
    N: PartialEq,
    I: SpIndex,
    Iptr: SpIndex,
    IpStorage: Deref<Target = [Iptr]>,
    IStorage: Deref<Target = [I]>,
    DStorage: Deref<Target = [N]>,
{
    if mat.rows() != mat.cols() {
        return false;
    }
    for (outer_ind, vec) in mat.outer_iterator().enumerate() {
        for (inner_ind, value) in vec.iter() {
            match mat.get_outer_inner(inner_ind, outer_ind) {
                None => return false,
                Some(transposed_val) => {
                    if transposed_val != value {
                        return false;
                    }
                }
            }
        }
    }
    true
}

#[cfg(test)]
mod test {
    use super::is_symmetric;
    use crate::sparse::CsMatView;

    #[test]
    fn is_symmetric_simple() {
        let indptr: &[usize] = &[0, 2, 5, 6, 7, 13, 14, 17, 20, 24, 28];
        let indices: &[usize] = &[
            0, 8, 1, 4, 9, 2, 3, 1, 4, 6, 7, 8, 9, 5, 4, 6, 9, 4, 7, 8, 0, 4,
            7, 8, 1, 4, 6, 9,
        ];
        let data: &[f64] = &[
            1.7, 0.13, 1., 0.02, 0.01, 1.5, 1.1, 0.02, 2.6, 0.16, 0.09, 0.52,
            0.53, 1.2, 0.16, 1.3, 0.56, 0.09, 1.6, 0.11, 0.13, 0.52, 0.11, 1.4,
            0.01, 0.53, 0.56, 3.1,
        ];

        let a = CsMatView::new((10, 10), indptr, indices, data);

        assert!(is_symmetric(&a));
    }

    // TODO: symmetry test on A^T*A products
}
