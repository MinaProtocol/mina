//! Test to demonstrate the possibility of having sparse matrices per block
use num_traits::Zero;

#[derive(Clone, Default, Debug, PartialEq)]
struct Mat {
    data: [[i32; 2]; 2],
}

impl Mat {
    fn new(data: [[i32; 2]; 2]) -> Self {
        Self { data }
    }
}

impl Zero for Mat {
    fn zero() -> Self {
        Self {
            data: [[0_i32; 2]; 2],
        }
    }
    fn is_zero(&self) -> bool {
        self == &Self::zero()
    }
}

impl std::ops::Add for Mat {
    type Output = Self;
    fn add(self, other: Self) -> Self {
        let mut out = Self::Output::zero();
        for i in 0..2 {
            for j in 0..2 {
                out.data[i][j] = self.data[i][j] + other.data[i][j]
            }
        }
        out
    }
}

impl std::ops::Mul for &Mat {
    type Output = Mat;
    fn mul(self, other: Self) -> Self::Output {
        let mut out = Self::Output::zero();
        for i in 0..2 {
            for j in 0..2 {
                for k in 0..2 {
                    out.data[i][j] += self.data[i][k] * other.data[k][j];
                }
            }
        }
        out
    }
}

impl sprs::MulAcc for Mat {
    fn mul_acc(&mut self, a: &Self, b: &Self) {
        for i in 0..2 {
            for j in 0..2 {
                for k in 0..2 {
                    self.data[i][j] += a.data[i][k] * b.data[k][j];
                }
            }
        }
    }
}

#[test]
/// Performs a multiplication of a sparse block-compressed matrix
///
/// Doing this through sparse multiplication gives 2 calls to mul_acc
/// instead of the 8 expected from a dense matrix multiplication
fn block_matrix_multiply() {
    let mat1 = Mat::new([[1, 2], [3, 4]]);
    let mat2 = Mat::new([[0, -3], [-2, -7]]);
    assert_eq!(&mat1 * &mat1, Mat::new([[7, 10], [15, 22]]));

    //  0  0  1  2
    //  0  0  3  4
    //  1  2  0 -3
    //  3  4 -2 -7
    let smat1 = sprs::CsMat::new(
        (2, 2),
        vec![0, 1, 3],
        vec![1, 0, 1],
        vec![mat1.clone(), mat1, mat2],
    );

    let mat1 = Mat::new([[2, 0], [7, -4]]);
    let mat2 = Mat::new([[0, -99], [9, -7]]);

    //  2  0  0  -99
    //  7 -4  9   -7
    //  0  0  0    0
    //  0  0  0    0
    let smat2 =
        sprs::CsMat::new((2, 2), vec![0, 2, 2], vec![0, 1], vec![mat1, mat2]);

    //  0   0  0    0
    //  0   0  0    0
    // 16  -8 18 -113
    // 34 -16 36 -325
    let smat3 = &smat1 * &smat2;
    assert_eq!(smat3.indptr().raw_storage(), &[0, 0, 2]);
    assert_eq!(smat3.indices(), &[0, 1]);
    let data = smat3.data();
    assert_eq!(data.len(), 2);
    assert_eq!(data[0], Mat::new([[16, -8], [34, -16]]));
    assert_eq!(data[1], Mat::new([[18, -113], [36, -325]]));
}
