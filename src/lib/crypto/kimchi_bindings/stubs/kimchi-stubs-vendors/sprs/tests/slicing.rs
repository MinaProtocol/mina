//! Test slicing from outside the crate to ensure the sealed trait
//! for ranges is effective

#[test]
fn slice_outer() {
    use sprs::CsMat;
    let size = 11;
    let csr: CsMat<f64> = CsMat::eye(size);
    let sliced = csr.slice_outer(2..7);
    let mut iter = sliced.into_iter();
    assert_eq!(iter.next().unwrap(), (&1., (0, 2)));
    assert_eq!(iter.next().unwrap(), (&1., (1, 3)));
    assert_eq!(iter.next().unwrap(), (&1., (2, 4)));
    assert_eq!(iter.next().unwrap(), (&1., (3, 5)));
    assert_eq!(iter.next().unwrap(), (&1., (4, 6)));
    assert!(iter.next().is_none());
}

#[test]
fn slice_outer_mut() {
    use sprs::CsMat;
    let size = 11;
    let mut csr: CsMat<f64> = CsMat::eye(size);
    let mut sliced = csr.slice_outer_mut(2..7);
    sliced.scale(2.);
    let mut iter = sliced.into_iter();
    assert_eq!(iter.next().unwrap(), (&2., (0, 2)));
    assert_eq!(iter.next().unwrap(), (&2., (1, 3)));
    assert_eq!(iter.next().unwrap(), (&2., (2, 4)));
    assert_eq!(iter.next().unwrap(), (&2., (3, 5)));
    assert_eq!(iter.next().unwrap(), (&2., (4, 6)));
    assert!(iter.next().is_none());

    let mut iter = csr.into_iter();
    assert_eq!(iter.next().unwrap(), (&1., (0, 0)));
    assert_eq!(iter.next().unwrap(), (&1., (1, 1)));
    assert_eq!(iter.next().unwrap(), (&2., (2, 2)));
    assert_eq!(iter.next().unwrap(), (&2., (3, 3)));
    assert_eq!(iter.next().unwrap(), (&2., (4, 4)));
    assert_eq!(iter.next().unwrap(), (&2., (5, 5)));
    assert_eq!(iter.next().unwrap(), (&2., (6, 6)));
    assert_eq!(iter.next().unwrap(), (&1., (7, 7)));
    assert_eq!(iter.next().unwrap(), (&1., (8, 8)));
    assert_eq!(iter.next().unwrap(), (&1., (9, 9)));
    assert_eq!(iter.next().unwrap(), (&1., (10, 10)));
    assert!(iter.next().is_none());
}

#[test]
fn slice_outer_other_ranges() {
    use sprs::CsMat;
    let size = 11;
    let csr: CsMat<f64> = CsMat::eye(size);
    let sliced = csr.slice_outer(..5);
    let mut iter = sliced.into_iter();
    assert_eq!(iter.next().unwrap(), (&1., (0, 0)));
    assert_eq!(iter.next().unwrap(), (&1., (1, 1)));
    assert_eq!(iter.next().unwrap(), (&1., (2, 2)));
    assert_eq!(iter.next().unwrap(), (&1., (3, 3)));
    assert_eq!(iter.next().unwrap(), (&1., (4, 4)));
    assert!(iter.next().is_none());

    let sliced = csr.slice_outer(9..);
    let mut iter = sliced.into_iter();
    assert_eq!(iter.next().unwrap(), (&1., (0, 9)));
    assert_eq!(iter.next().unwrap(), (&1., (1, 10)));
    assert!(iter.next().is_none());

    let sliced = csr.slice_outer(..);
    assert_eq!(sliced, csr.view());
}
