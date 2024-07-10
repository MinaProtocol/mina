///! This file demonstrates basic usage of the sprs library,
///! where a heat diffusion problem with Dirichlet boundary condition
///! is solved for equilibrium. For simplicity we omit any relevant
///! physical constant.
///!
///! This problem can be modelled as solving a linear system
///! L * x = rhs
///! where L is a laplacian matrix on a 2 dimensional grid, and rhs is
///! zero everywhere except for values corresponding to borders, where
///! a constant heat value is imposed.
///! Since the L matrix is diagonally dominant, we can use a Gauss-Seidel
///! iterative scheme to solve the system.
///!
///! This shows how a laplacian matrix can be constructed by directly
///! constructing the compressed structure, and how the resulting linear
///! system can be solved using an iterative method.

type VecView<'a, T> = ndarray::ArrayView<'a, T, ndarray::Ix1>;
type VecViewMut<'a, T> = ndarray::ArrayViewMut<'a, T, ndarray::Ix1>;
type OwnedVec<T> = ndarray::Array<T, ndarray::Ix1>;

/// Determine whether the grid location at `(row, col)` is a border
/// of the grid defined by `shape`.
fn is_border(row: usize, col: usize, shape: (usize, usize)) -> bool {
    let (rows, cols) = shape;
    let top_row = row == 0;
    let bottom_row = row + 1 == rows;
    let border_row = top_row || bottom_row;

    let left_col = col == 0;
    let right_col = col + 1 == cols;
    let border_col = left_col || right_col;

    border_row || border_col
}

/// Compute the discrete laplacian operator on a grid, assuming the
/// step size is 1.
/// We assume this operator operates on the C-order flattened version of
/// the grid.
///
/// This example shows how a relatively straightforward sparse matrix
/// can be constructed with a minimal number of allocations by directly
/// building up its sparse structure.
fn grid_laplacian(shape: (usize, usize)) -> sprs::CsMat<f64> {
    let (rows, cols) = shape;
    let nb_vert = rows * cols;
    let mut indptr = Vec::with_capacity(nb_vert + 1);
    let nnz = 5 * nb_vert + 5;
    let mut indices = Vec::with_capacity(nnz);
    let mut data = Vec::with_capacity(nnz);
    let mut cumsum = 0;

    for i in 0..rows {
        for j in 0..cols {
            indptr.push(cumsum);

            let mut add_elt = |i, j, x| {
                indices.push(i * rows + j);
                data.push(x);
                cumsum += 1;
            };

            if is_border(i, j, shape) {
                // establish Dirichlet boundary conditions
                add_elt(i, j, 1.);
            } else {
                add_elt(i - 1, j, 1.);
                add_elt(i, j - 1, 1.);
                add_elt(i, j, -4.);
                add_elt(i, j + 1, 1.);
                add_elt(i + 1, j, 1.);
            }
        }
    }

    indptr.push(cumsum);

    sprs::CsMat::new((nb_vert, nb_vert), indptr, indices, data)
}

/// Set a dirichlet boundary condition
fn set_boundary_condition<F>(
    mut rhs: VecViewMut<f64>,
    grid_shape: (usize, usize),
    f: F,
) where
    F: Fn(usize, usize) -> f64,
{
    let (rows, cols) = grid_shape;
    for i in 0..rows {
        for j in 0..cols {
            if is_border(i, j, grid_shape) {
                let index = i * rows + j;
                rhs[[index]] = f(i, j);
            }
        }
    }
}

/// Gauss-Seidel method to solve the system
/// see https://en.wikipedia.org/wiki/Gauss%E2%80%93Seidel_method#Algorithm
fn gauss_seidel(
    mat: sprs::CsMatView<f64>,
    mut x: VecViewMut<f64>,
    rhs: VecView<f64>,
    max_iter: usize,
    eps: f64,
) -> Result<(usize, f64), f64> {
    assert!(mat.rows() == mat.cols());
    assert!(mat.rows() == x.shape()[0]);
    let mut error = (&mat * &x - rhs).sum().sqrt();
    for it in 0..max_iter {
        for (row_ind, vec) in mat.outer_iterator().enumerate() {
            let mut sigma = 0.;
            let mut diag = None;
            for (col_ind, &val) in vec.iter() {
                if row_ind != col_ind {
                    sigma += val * x[[col_ind]];
                } else {
                    diag = Some(val);
                }
            }
            // Gauss-Seidel requires a non-zero diagonal, which
            // is satisfied for a laplacian matrix
            let diag = diag.unwrap();
            let cur_rhs = rhs[[row_ind]];
            x[[row_ind]] = (cur_rhs - sigma) / diag;
        }

        error = (&mat * &x - rhs).sum().sqrt();
        // error corresponds to the state before iteration, but
        // that shouldn't be a problem
        if error < eps {
            return Ok((it, error));
        }
    }
    Err(error)
}

fn main() {
    let (rows, cols) = (10, 10);
    let lap = grid_laplacian((rows, cols));
    println!(
        "grid laplacian nnz structure:\n{}",
        sprs::visu::nnz_pattern_formatter(lap.view()),
    );
    let mut rhs = OwnedVec::zeros(rows * cols);
    set_boundary_condition(rhs.view_mut(), (rows, cols), |row, col| {
        (row + col) as f64
    });

    let mut x = OwnedVec::zeros(rows * cols);

    match gauss_seidel(lap.view(), x.view_mut(), rhs.view(), 300, 1e-8) {
        Ok((iters, error)) => {
            println!(
                "Solved system in {} iterations with residual error {}",
                iters, error
            );
            let grid = x.view().into_shape((rows, cols)).unwrap();
            for i in 0..rows {
                for j in 0..cols {
                    print!("{} ", grid[[i, j]]);
                }
                println!("");
            }
        }
        Err(error) => {
            println!("Solving the system failed to converge fast enough");
            println!("Residual error was {}", error);
        }
    }
}
