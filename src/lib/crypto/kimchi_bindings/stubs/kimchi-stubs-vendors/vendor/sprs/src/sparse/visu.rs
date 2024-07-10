use std::fmt;

use ndarray::Array2;

use crate::indexing::SpIndex;
use crate::sparse::CsMatViewI;

pub fn print_nnz_pattern<N, I, Iptr>(mat: CsMatViewI<N, I, Iptr>)
where
    N: Clone + Default,
    I: SpIndex,
    Iptr: SpIndex,
{
    print!("{}", nnz_pattern_formatter(mat));
}

pub struct NnzPatternFormatter<'a, N, I: SpIndex, Iptr: SpIndex> {
    mat: CsMatViewI<'a, N, I, Iptr>,
}

impl<'a, N, I, Iptr> fmt::Display for NnzPatternFormatter<'a, N, I, Iptr>
where
    N: Clone + Default,
    I: SpIndex,
    Iptr: SpIndex,
{
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut write_csr = |mat: &CsMatViewI<N, I, Iptr>| {
            for row_vec in mat.outer_iterator() {
                let mut cur_col = 0;
                write!(f, "|")?;
                for (col_ind, _) in row_vec.iter() {
                    while cur_col < col_ind {
                        write!(f, " ")?;
                        cur_col += 1;
                    }
                    write!(f, "x")?;
                    cur_col = col_ind + 1;
                }
                while cur_col < mat.cols() {
                    write!(f, " ")?;
                    cur_col += 1;
                }
                writeln!(f, "|")?;
            }
            Ok(())
        };
        if self.mat.is_csr() {
            write_csr(&self.mat)
        } else {
            let mat_csr = self.mat.to_other_storage();
            write_csr(&mat_csr.view())
        }
    }
}

pub fn nnz_pattern_formatter<N, I, Iptr>(
    mat: CsMatViewI<N, I, Iptr>,
) -> NnzPatternFormatter<N, I, Iptr>
where
    I: SpIndex,
    Iptr: SpIndex,
{
    NnzPatternFormatter { mat }
}

/// Create an array holding a black and white image representing the
/// non-zero pattern of the sparse matrix.
///
/// Since this is aimed at display, zeros will be mapped to 0xFF white pixels
/// while non-zeros will be mapped to 0x00 black pixels.
pub fn nnz_image<N, I, Iptr>(mat: CsMatViewI<N, I, Iptr>) -> Array2<u8>
where
    I: SpIndex,
    Iptr: SpIndex,
{
    let (rows, cols) = (mat.rows(), mat.cols());
    let mut res = Array2::from_elem((rows, cols), 255);
    for (outer, outer_vec) in mat.outer_iterator().enumerate() {
        for (inner, _) in outer_vec.iter() {
            let (i, j) = if mat.is_csr() {
                (outer, inner)
            } else {
                (inner, outer)
            };
            res[[i, j]] = 0;
        }
    }
    res
}

#[cfg(test)]
mod test {
    use super::{nnz_image, nnz_pattern_formatter};
    use crate::sparse::CsMat;
    use ndarray::arr2;

    #[test]
    fn test_nnz_pattern_formatter() {
        let mat = CsMat::new_csc(
            (3, 3),
            vec![0, 1, 3, 4],
            vec![1, 0, 2, 2],
            vec![1.; 4],
        );
        let expected_str = "| x |\n\
                            |x  |\n\
                            | xx|\n";
        let pattern_str = format!("{}", nnz_pattern_formatter(mat.view()));
        assert_eq!(expected_str, pattern_str);
    }

    #[test]
    fn test_nnz_image() {
        let mat = CsMat::new_csc(
            (3, 3),
            vec![0, 1, 3, 4],
            vec![1, 0, 2, 2],
            vec![1.; 4],
        );
        let expected_arr = arr2(&[[255, 0, 255], [0, 255, 255], [255, 0, 0]]);
        let nnz_arr = nnz_image(mat.view());
        assert_eq!(expected_arr, nnz_arr);
    }
}
